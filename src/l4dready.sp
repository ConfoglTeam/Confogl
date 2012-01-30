#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

/*
* PROGRAMMING CREDITS:
* Could not do this without Fyren at all, it was his original code chunk 
* 	that got me started (especially turning off directors and freezing players).
* 	Thanks to him for answering all of my silly coding questions too.
* 
* TESTING CREDITS:
* 
* Biggest #1 thanks goes out to Fission for always being there since the beginning
* even when this plugin was barely working.
*/

#define READY_DEBUG 0
#define READY_DEBUG_LOG 0

#define READY_VERSION "0.17.10"
#define READY_SCAVENGE_WARMUP 1
#define READY_LIVE_COUNTDOWN 5
#define READY_UNREADY_HINT_PERIOD 10.0
#define READY_LIST_PANEL_LIFETIME 10
#define READY_RESTART_ROUND_DELAY 0.0
#define READY_RESTART_MAP_DELAY 5.0
#define READY_RESTART_SCAVENGE_TIMER 0.1

#define L4D_MAXCLIENTS (MaxClients)
#define L4D_MAXCLIENTS_PLUS1 (MaxClients+1)
#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1

#define CONVAR_FLAGS_PLUGIN FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY

#define L4D_SCAVENGE_GAMECLOCK_HALT (-1.0)

#define L4D_TEAM_A 0
#define L4D_TEAM_B 1
#define L4D_TEAM_NAME(%1) (%1 == 2 ? "Survivors" : (%1 == 3 ? "Infected" : (%1 == 1 ? "Spectators" : "Unknown")))

#define SCORE_DELAY_PLACEMENT 0.1
#define SCORE_DELAY_TEAM_SWITCH 0.1
#define SCORE_DELAY_SWITCH_MAP 1.0
#define SCORE_DELAY_EMPTY_SERVER 5.0
#define SCORE_DELAY_SCORE_SWAPPED 0.1

#define GAMECONFIG_FILE "left4downtown.l4d2"
#define L4D_UNPAUSE_DELAY 5

enum PersistentTeam
{
	PersistentTeam_Invalid,
	PersistentTeam_A,
	PersistentTeam_B
}
enum L4D2Team
{
	L4D2Team_Unknown	= 0,
	L4D2Team_Survivors	= 2,
	L4D2Team_Infected	= 3,
	L4D2Team_Spectators	= 1
}
new bool:readyMode; //currently waiting for players to ready up?

new goingLive; //0 = not going live, 1 or higher = seconds until match starts

new insideCampaignRestart; //0=normal play, 1 or 2=programatically restarting round
new bool:isCampaignBeingRestarted;
new bool:beforeMapStart = true;

new forcedStart;
new readyStatus[MAXPLAYERS + 1];

new Handle:menuPanel 					= INVALID_HANDLE;

new Handle:liveTimer 					= INVALID_HANDLE;
new bool:unreadyTimerExists				= false;

new Handle:cvarEnforceReady 			= INVALID_HANDLE;
new Handle:cvarReadyCompetition 		= INVALID_HANDLE;
new Handle:cvarReadyMinimum 			= INVALID_HANDLE;
new Handle:cvarReadyHalves 				= INVALID_HANDLE;
new Handle:cvarReadyServerCfg 			= INVALID_HANDLE;
new Handle:cvarReadySearchKeyDisable 	= INVALID_HANDLE;
new Handle:cvarSearchKey				= INVALID_HANDLE;
new Handle:cvarGameMode 				= INVALID_HANDLE;
new Handle:cvarScavengeSetup 			= INVALID_HANDLE;
new Handle:cvarGod 						= INVALID_HANDLE;
new Handle:cvarCFGName 					= INVALID_HANDLE;
new Handle:cvarPausesAllowed 			= INVALID_HANDLE;
new Handle:cvarPauseDuration 			= INVALID_HANDLE;
new Handle:cvarConnectEnabled 			= INVALID_HANDLE;
new Handle:cvarBlockSpecGlobalChat 		= INVALID_HANDLE;
new Handle:cvarDisableReadySpawns		= INVALID_HANDLE;

new Handle:fwdOnReadyRoundRestarted 	= INVALID_HANDLE;
new Handle:fwdOnRoundIsLive			= INVALID_HANDLE;

new Handle:teamPlacementTrie 			= INVALID_HANDLE;
new Handle:casterTrie 					= INVALID_HANDLE;

new hookedPlayerHurt; //if we hooked player_hurt event?

new pauseBetweenHalves; //should we ready up before starting the 2nd round or go live right away
new bool:isSecondRound; //second round or later (esp. in scavenge)

static teamScores[PersistentTeam];
static bool:defaultTeams = true;
new bool:isNewCampaign = true; //Has the game been paused yet on this map?

new bool:isMapRestartPending;

new bool:inWarmUp; //Scavenge warm up during ready up.

new iInitialSetupTime = 45; //Setup time as determined by convar scavenge_round_setup_time
new iInitialGhostTimeMin;
new iInitialGhostTimeMax;

new lastTeamPause; //Stores which team paused the game.
new bool:canUnpause; //Whether or not either team can unpause
new bool:isPaused;
new bool:isUnpausing;
new iInitialAllTalk;
new bool:bReadyOffCalled = true;
new Handle:timerMinimumPause = INVALID_HANDLE;

/* Team placement */
new Handle:fSHS = INVALID_HANDLE; //SetHumanSpectator
new Handle:fTOB = INVALID_HANDLE; //TakeOverBot
new teamPlacementArray[256];  //after client connects, try to place him to this team
new teamPlacementAttempts[256]; //how many times we attempt and fail to place a person


public Plugin:myinfo =
{
	name = "L4D2 Ready Up",
	author = "Downtown1 and Frustian, continued by AtomicStryker",
	description = "Force Players to Ready Up Before Beginning Match",
	version = READY_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=84086"
};

public OnPluginStart()
{
	if(!IsTargetL4D2())
	{
		ThrowError("Plugin does not support any games besides L4D2");
	}
	
	LoadTranslations("common.phrases");
	
	//case-insensitive handling of ready,unready,notready
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Teamsay);

	RegConsoleCmd("sm_ready", readyUp);
	RegConsoleCmd("sm_unready", readyDown);
	RegConsoleCmd("sm_notready", readyDown); //alias for people who are bad at reading instructions
	RegConsoleCmd("sm_reready", Command_Reready);
	RegConsoleCmd("sm_cast", regCaster);
	
	RegConsoleCmd("sm_pause", readyPause);
	RegConsoleCmd("sm_unpause", readyUnpause);
	RegConsoleCmd("unpause", Command_Unpause);
	
	RegConsoleCmd("spectate", Command_Spectate);
	RegConsoleCmd("callvote", Command_CallVote);
	RegConsoleCmd("vote", Command_CallVote);
	
	RegAdminCmd("sm_restartmap", CommandRestartMap, ADMFLAG_CHANGEMAP, "sm_restartmap - changelevels to the current map");
	
	RegAdminCmd("sm_abort", compAbort, ADMFLAG_BAN, "sm_abort");
	RegAdminCmd("sm_forcestart", compStart, ADMFLAG_BAN, "sm_forcestart");
	
	HookEvent("round_start", eventRSLiveCallback);
	HookEvent("round_end", eventRoundEndCallback);
	
	HookEvent("player_bot_replace", eventPlayerBotReplaceCallback);
	HookEvent("bot_player_replace", eventBotPlayerReplaceCallback);
	
	HookEvent("player_spawn", eventSpawnReadyCallback);	
	HookEvent("player_team", Event_PlayerTeam);
	
	fwdOnReadyRoundRestarted = CreateGlobalForward("OnReadyRoundRestarted", ET_Event);
	fwdOnRoundIsLive = CreateGlobalForward("OnRoundIsLive", ET_Event);
	
	CreateConVar("l4d_ready_version", READY_VERSION, "Version of the ready up plugin.", CONVAR_FLAGS_PLUGIN|FCVAR_DONTRECORD);
	cvarEnforceReady = CreateConVar("l4d_ready_enabled", "0", "Make players ready up by default before a match begins", CONVAR_FLAGS_PLUGIN);
	cvarReadyCompetition = CreateConVar("l4d_ready_competition", "0", "Disable all plugins but a few competition-allowed ones", CONVAR_FLAGS_PLUGIN);
	cvarReadyHalves = CreateConVar("l4d_ready_both_halves", "0", "Make players ready up both during the first and second rounds of a map", CONVAR_FLAGS_PLUGIN);
	cvarReadyMinimum = CreateConVar("l4d_ready_minimum_players", "8", "Minimum # of players before we can ready up", CONVAR_FLAGS_PLUGIN);
	cvarReadyServerCfg = CreateConVar("l4d_ready_server_cfg", "", "Config to execute when the map is changed (to exec after server.cfg).", CONVAR_FLAGS_PLUGIN);
	cvarReadySearchKeyDisable = CreateConVar("l4d_ready_search_key_disable", "1", "Automatically disable plugin if sv_search_key is blank", CONVAR_FLAGS_PLUGIN);
	cvarCFGName = CreateConVar("l4d_ready_cfg_name", "", "CFG Name to display on the RUP Menu", CONVAR_FLAGS_PLUGIN);
	cvarPausesAllowed = CreateConVar("l4d_ready_pause_allowed", "3", "Number of times each team can pause per campaign", CONVAR_FLAGS_PLUGIN);
	cvarPauseDuration = CreateConVar("l4d_ready_pause_duration", "90.0", "Minimum duration of pause in seconds before either team can unpause", CONVAR_FLAGS_PLUGIN);
	cvarConnectEnabled = CreateConVar("l4d_ready_connect_enabled", "1", "Show Announcements When Players Join", CONVAR_FLAGS_PLUGIN);
	cvarBlockSpecGlobalChat = CreateConVar("l4d_block_spectator_globalchat", "0", "Prevent non-caster Spectators from global chatting, it gets redirected to teamchat", CONVAR_FLAGS_PLUGIN);
	cvarDisableReadySpawns = CreateConVar("l4d_ready_disable_spawns", "0", "Prevent SI from having ghost-mode spawns during readyup.", CONVAR_FLAGS_PLUGIN);
	
	cvarSearchKey = FindConVar("sv_search_key");
	cvarGameMode = FindConVar("mp_gamemode");
	cvarScavengeSetup = FindConVar("scavenge_round_setup_time");
	cvarGod = FindConVar("god");
	
	teamPlacementTrie = CreateTrie();
	casterTrie = CreateTrie();
	
	HookConVarChange(cvarEnforceReady, ConVarChange_ReadyEnabled);
	HookConVarChange(cvarReadyCompetition, ConVarChange_ReadyCompetition);
	HookConVarChange(cvarSearchKey, ConVarChange_SearchKey);
	
	// Team swapping SDK calls
	new Handle:gConf = LoadGameConfigFile(GAMECONFIG_FILE);
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	fSHS = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	fTOB = EndPrepSDKCall();
}

native bool:BaseComm_IsGagged(client);

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("BaseComm_IsGagged");
	CreateNative("L4DReady_IsGamePaused", nativeIsGamePaused);
	return APLRes_Success;
}

public OnAllPluginsLoaded()
{	
	new bool:l4dscores = FindConVar("l4d_team_manager_ver") != INVALID_HANDLE;
	
	if(!l4dscores)
	{
		// l4d scores plugin is NOT loaded
		// supply these commands which would otherwise be done by the team manager
		
		RegAdminCmd("sm_swap", Command_Swap, ADMFLAG_BAN, "sm_swap <player1> [player2] ... [playerN] - swap all listed players to opposite teams");
		RegAdminCmd("sm_swap", Command_Swap, ADMFLAG_BAN, "sm_swap <player1> [player2] ... [playerN] - swap all listed players to opposite teams");
		RegAdminCmd("sm_swapto", Command_SwapTo, ADMFLAG_BAN, "sm_swapto <player1> [player2] ... [playerN] <teamnum> - swap all listed players to <teamnum> (1,2, or 3)");
		RegAdminCmd("sm_swapteams", Command_SwapTeams, ADMFLAG_BAN, "sm_swapteams2 - swap the players between both teams");
	}
}

new bool:insidePluginEnd = false;
public OnPluginEnd()
{
	insidePluginEnd = true;
	readyOff();	
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (readyMode)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVORS && !(GetEntityMoveType(client) == MOVETYPE_NONE || GetEntityMoveType(client) == MOVETYPE_NOCLIP))
		{
			ToggleFreezePlayer(client, true);
		}
	}
}

public OnMapEnd()
{
	beforeMapStart = true;
	isSecondRound = false;	
	if (!bReadyOffCalled)
	{
		SetConVarInt(cvarScavengeSetup, iInitialSetupTime);
		SetConVarFlags(cvarGod,GetConVarFlags(cvarGod) & ~FCVAR_NOTIFY);
		SetConVarInt(cvarGod, 0);
		SetConVarFlags(cvarGod,GetConVarFlags(cvarGod) | FCVAR_NOTIFY);
		
		SetConVarInt(FindConVar("sv_alltalk"), iInitialAllTalk);
		SetConVarInt(FindConVar("z_ghost_delay_max"), iInitialGhostTimeMax);
		SetConVarInt(FindConVar("z_ghost_delay_min"), iInitialGhostTimeMin);
		bReadyOffCalled = true;
	}
	if (isPaused)
	{
		SetConVarInt(FindConVar("sv_alltalk"), iInitialAllTalk);
	}
	DebugPrintToAll("Event: Map ended.");
}

public OnMapStart()
{
	DebugPrintToAll("Event map started.");
	beforeMapStart = false;
	//isNewCampaign = true;
	/*
	* execute the cfg specified in l4d_ready_server_cfg
	*/
	if (teamScores[PersistentTeam_A] > teamScores[PersistentTeam_B])
	{
		defaultTeams = true;
	}
	else if (teamScores[PersistentTeam_A] < teamScores[PersistentTeam_B])
	{
		defaultTeams = false;
	}
	if(GetConVarInt(cvarEnforceReady))
	{
		decl String:cfgFile[128];
		GetConVarString(cvarReadyServerCfg, cfgFile, sizeof(cfgFile));
		
		if(strlen(cfgFile) == 0)
		{
			return;
		}
		
		decl String:cfgPath[1024];
		BuildPath(Path_SM, cfgPath, 1024, "../../cfg/%s", cfgFile);
		
		if(FileExists(cfgPath))
		{
			DebugPrintToAll("Executing server config %s", cfgPath);
			
			ServerCommand("exec %s", cfgFile);
		}
		else
		{
			LogError("[SM] Could not execute server config %s, file not found", cfgPath);
			PrintToServer("[SM] Could not execute server config %s, file not found", cfgFile);	
			PrintToChatAll("[SM] Could not execute server config %s, file not found", cfgFile);	
		}
	}
}

public bool:OnClientConnect(client, String:rejectmsg[], size)
{
	if (readyMode) 
	{
		checkStatus();
	}
	
	return true;
}

public OnClientDisconnect()
{
	if (readyMode) checkStatus();
}

public OnClientAuthorized(client,const String:SteamID[])
{
	if (GetConVarInt(cvarEnforceReady) && GetConVarInt(cvarConnectEnabled) && !IsFakeClient(client))
	{
		decl String:Name[128];
		GetClientName(client, Name, sizeof(Name));
		PrintToChatAll("[SM] %s (%s) has connected", Name, SteamID);
	}
}

checkStatus()
{
	new humans, ready, team;
	decl String:authid[96];
	
	//count number of non-bot players in-game
	for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			team = GetClientTeam(i);
			GetClientAuthString(i, authid, sizeof(authid));
		
			if (team != L4D_TEAM_SPECTATE
			|| (team == L4D_TEAM_SPECTATE && IsClientCaster(i)))
			{
				humans++;
				if (readyStatus[i]) ready++;
			}
		}
	}
	if(!humans || humans < GetConVarInt(cvarReadyMinimum))
		return;
	
	if ((goingLive && (humans == ready))
	|| forcedStart)
		return;
	
	else if (goingLive && (humans != ready))
	{
		goingLive = 0;
		PrintHintTextToAll("Aborted going live due to player unreadying.");
		KillTimer(liveTimer);
	}
	else if (!goingLive && (humans == ready))
	{
		if(!insideCampaignRestart)
		{
			goingLive = READY_LIVE_COUNTDOWN; //TODO get from variable
			liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else if (!goingLive && (humans != ready)) PrintHintTextToAll("%d of %d players are ready.", ready, humans);
	else PrintToChatAll("checkStatus bad state (tell Downtown1)");
}

//reset the scavenge setup timer so it stays in setup indefinitely
public Action:Timer_ResetScavengeSetup(Handle:timer)
{
	if(!readyMode)
	{
		DebugPrintToAll("Scavenge setup timer halted , leaving ready mode");
		return Plugin_Stop;
	}
	
	L4D_ScavengeBeginRoundSetupTime();

	return Plugin_Continue;
}

//repeatedly count down until the match goes live
public Action:timerLiveCountCallback(Handle:timer)
{
	//will go live soon
	if (goingLive)
	{
		if (forcedStart) PrintHintTextToAll("Forcing match start.  An admin must 'say !abort' to abort!\nGoing live in %d seconds.", goingLive);
		else PrintHintTextToAll("All players ready.  Say !unready now to abort!\nGoing live in %d seconds.", goingLive);
		goingLive--;
	}
	//actually go live and unfreeze everyone
	else
	{
		//readyOff();
		
		if(ShouldResetRoundTwiceToGoLive())
		{
			PrintHintTextToAll("Match will be live after 2 round restarts.");
			
			insideCampaignRestart = 2;
			RestartCampaignAny();
		}
		else	 // scavenge mode, reready -- DO NOT reset the round twice
		{
			RoundEndBeforeLive();
			RoundIsLive();
		}
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

bool:ShouldResetRoundTwiceToGoLive()
{
	
	if(inWarmUp)	//scavenge pre-first round warmup
		return true;
	
	//do not reset the round for L4D2 versus or L4D2 scavenge reready
	return false;
}

public Action:eventRoundEndCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	DebugPrintToAll("[DEBUG] Event round has ended");
	
	if(isSecondRound)
	{
		SaveSpectators();
	}
	if(!isCampaignBeingRestarted)
	{
		
		if(!isSecondRound)
		{
			DebugPrintToAll("[DEBUG] Second round detected.");
			if(GetConVarBool(cvarEnforceReady) && !isSecondRound && GetConVarBool(cvarDisableReadySpawns) && (GetConVarInt(cvarReadyHalves) || pauseBetweenHalves))
			{
				SetConVarInt(FindConVar("director_no_specials"), 1);
			}
		}
		else
			DebugPrintToAll("[DEBUG] End of second round detected.");
		
		isSecondRound = true;
	}
	
	//we just ended the last restart, match will be live soon
	if(insideCampaignRestart == 1) 
	{
		//enable the director etc, but dont unfreeze all players just yet
		RoundEndBeforeLive();
	}
	
	isCampaignBeingRestarted = false;
}

public Action:eventRSLiveCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Event round has started");
	#endif
	
	//currently automating campaign restart before going live?
	if(insideCampaignRestart > 0) 
	{
		insideCampaignRestart--;
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Round restarting, left = %d", insideCampaignRestart);
		#endif
		
		//first restart, do one more
		if(insideCampaignRestart == 1) 
		{
		#if READY_RESTART_ROUND_DELAY
			CreateTimer(READY_RESTART_ROUND_DELAY, timerOneRoundRestart, _, _);
		#else //with RestartScenarioFromVote there is no need to have a delay
			RestartCampaignAny();
		#endif
			
			//PrintHintTextToAll("Match will be live after 1 round restart.");
			
		}
		//last restart, match is now live!
		else if (!insideCampaignRestart)
		{
			RoundIsLive();
		}
		else
		{
			LogError("insideCampaignRestart somehow neither 0 nor 1 after decrementing");
		}
		
		return Plugin_Continue;
	}
	
	//normal round start event not triggered by our plugin
	
	//our code will just enable ready mode at the start of a round
	//if the cvar is set to it
	if(GetConVarInt(cvarEnforceReady)
	&& (!isSecondRound || GetConVarInt(cvarReadyHalves) || pauseBetweenHalves)) 
	{
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Calling comPready, pauseBetweenHalves = %d", pauseBetweenHalves);
		#endif
		
		compReady(0, 0);
		pauseBetweenHalves = 0;
	}
	
	return Plugin_Continue;
}

public Action:timerOneRoundRestart(Handle:timer)
{
	PrintToChatAll("[SM] Match will be live after 1 round restart!");
	PrintHintTextToAll("Match will be live after 1 round restart!");
	
	RestartCampaignAny();
	
	return Plugin_Stop;
}

public Action:timerLiveMessageCallback(Handle:timer)
{
	PrintHintTextToAll("Match is LIVE!");
	
	if(GetConVarInt(cvarReadyHalves) || isSecondRound)
	{
		PrintToChatAll("[SM] Match is LIVE!");
	}
	else
	{
		PrintToChatAll("[SM] Match is LIVE for both halves, say !reready to request a ready-up before the next half.");
	}
	
	return Plugin_Stop;
}


public Action:timerUnreadyCallback(Handle:timer)
{
	if(!readyMode)
	{
		unreadyTimerExists = false;
		return Plugin_Stop;
	}
	
	if(insideCampaignRestart)
	{
		return Plugin_Continue;
	}
	
	//new curPlayers = CountInGameHumans();
	//new minPlayers = GetConVarInt(cvarReadyMinimum);
	
	for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGameHuman(i)) 
		{
			//use panel for ready up stuff?
			if(!readyStatus[i])
			{
				PrintHintText(i, "You are NOT READY!\n\nSay !ready in chat to ready up.");
			}
			else
			{
				PrintHintText(i, "You are ready.\n\nSay !unready in chat if no longer ready.");
			}
		}
	}
	
	DrawReadyPanelList();
	if (inWarmUp)
	{
		new ent = -1;
		new prev = 0;
		while ((ent = FindEntityByClassname(ent, "weapon_gascan")) != -1)
		{
			if (prev)
			{
				RemoveEdict(prev);
			}
			prev = ent;
		}
		if (prev)
		{
			RemoveEdict(prev);
		}
		DebugPrintToAll("Removed all gas cans");
	}
	
	return Plugin_Continue;
}

public Action:eventSpawnReadyCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (readyMode && !inWarmUp)
	{
		new player = GetClientOfUserId(GetEventInt(event, "userid"));
		#if READY_DEBUG
		decl String:curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Spawned %s [%d], freezing.", curname, player);
		#endif
		ToggleFreezePlayer(player, true);
	}
	return Plugin_Handled;
}

public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	DebugPrintToAll("OnSpawnTank(vector[%f,%f,%f], qangle[%f,%f,%f]", 
		vector[0], vector[1], vector[2], qangle[0], qangle[1], qangle[2]);
		
	if(readyMode)
	{
		DebugPrintToAll("Blocking tank spawn...");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action:L4D_OnSpawnWitch(const Float:vector[3], const Float:qangle[3])
{
	DebugPrintToAll("OnSpawnWitch(vector[%f,%f,%f], qangle[%f,%f,%f])", 
		vector[0], vector[1], vector[2], qangle[0], qangle[1], qangle[2]);
		
	if(readyMode)
	{
		DebugPrintToAll("Blocking witch spawn...");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action:L4D_OnSetCampaignScores(&scoreA, &scoreB)
{
	teamScores[PersistentTeam_A] = scoreA;
	teamScores[PersistentTeam_B] = scoreB;
	if (!scoreA && !scoreB && beforeMapStart)
	{
		OnNewCampaign();
	}
	return Plugin_Continue;
}

public Action:L4D_OnClearTeamScores(bool:newCampaign)
{
	if (newCampaign)
	{
		OnNewCampaign();
	}
}

OnNewCampaign()
{
	defaultTeams = true;
	isNewCampaign = true;
	
	CloseHandle(teamPlacementTrie);
	teamPlacementTrie = CreateTrie();
	
	CloseHandle(casterTrie);
	casterTrie = CreateTrie();
}

//When a player replaces a bot (i.e. player joins survivors team)
public Action:eventBotPlayerReplaceCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	//	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	
	if(readyMode && !inWarmUp)
	{
		//called when player joins survivor....?
		#if READY_DEBUG
		decl String:curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Player %s [%d] replacing bot, freezing player.", curname, player);
		#endif
		
		ToggleFreezePlayer(player, true);
	}
	
	return Plugin_Handled;
}


//When a bot replaces a player (i.e. player switches to spectate or infected)
public Action:eventPlayerBotReplaceCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	//	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	
	if(readyMode && !inWarmUp)
	{
		#if READY_DEBUG
		decl String:curname[128];
		GetClientName(player,curname,128);
		
		DebugPrintToAll("[DEBUG] Bot replacing player %s [%d], unfreezing player.", curname, player);
		#endif
		
		ToggleFreezePlayer(player, false);
	}
	
	return Plugin_Handled;
}

//When a player gets hurt during ready mode, block all damage
public Action:eventPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	new health = GetEventInt(event, "health");
	new dmg_health = GetEventInt(event, "dmg_health");
	
	#if READY_DEBUG
	decl String:curname[128];
	GetClientName(player,curname,128);
	
	DebugPrintToAll("[DEBUG] Player hurt %s [%d], health = %d, dmg_health = %d.", curname, player, health, dmg_health);
	#endif
	
	SetEntityHealth(player, health + dmg_health);
}

RestartCampaignAny()
{	
	decl String:currentmap[128];
	GetCurrentMap(currentmap, sizeof(currentmap));
	
	DebugPrintToAll("RestartCampaignAny() - Restarting scenario from vote ...");
	
	Call_StartForward(fwdOnReadyRoundRestarted);
	Call_Finish();
	
	L4D_RestartScenarioFromVote(currentmap);
}

public Action:CommandRestartMap(client, args)
{	
	if(!isMapRestartPending)
	{
		PrintToChatAll("[SM] Map resetting in %.0f seconds.", READY_RESTART_MAP_DELAY);
		RestartMapDelayed();
	}
	
	return Plugin_Handled;
}

RestartMapDelayed()
{
	isMapRestartPending = true;
	
	CreateTimer(READY_RESTART_MAP_DELAY, timerRestartMap, _, TIMER_FLAG_NO_MAPCHANGE);
	DebugPrintToAll("[SM] Map will restart in %f seconds.", READY_RESTART_MAP_DELAY);
}

public Action:timerRestartMap(Handle:timer)
{
	RestartMapNow();
}

RestartMapNow()
{
	isMapRestartPending = false;
	
	decl String:currentMap[256];
	
	GetCurrentMap(currentMap, 256);
	
	ServerCommand("changelevel %s", currentMap);
}

public Action:Command_CallVote(client, args)
{
	if (client && IsClientInGame(client) && GetClientTeam(client) != L4D_TEAM_SPECTATE)
	{
		return Plugin_Continue;
	}
	
	ReplyToCommand(client, "[SM] You must be ingame and not spectator to vote");
	return Plugin_Handled;
}

public Action:Command_Spectate(client, args)
{
	if(IsPlayerAlive(client) && GetClientTeam(client) == L4D_TEAM_INFECTED)
	{
		ForcePlayerSuicide(client);
	}
	if(GetClientTeam(client) != L4D_TEAM_SPECTATE)
	{
		ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
		PrintToChatAll("[SM] %N has become a spectator.", client);
		if(readyMode) checkStatus();
	}
	//respectate trick to get around spectator camera being stuck
	else
	{
		ChangePlayerTeam(client, L4D_TEAM_INFECTED);
		CreateTimer(0.1, Timer_Respectate, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Handled;
}

public Action:Timer_Respectate(Handle:timer, any:client)
{
	ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
	PrintToChatAll("[SM] %N has become a spectator (again).", client);
	if(readyMode) checkStatus();
}

static bool:OptIsGagged(client)
{
	if (GetFeatureStatus(FeatureType_Native, "BaseComm_IsGagged") == FeatureStatus_Available)
	{
		return BaseComm_IsGagged(client);
	}
	
	return false;
}

public Action:Command_Say(client, args)
{
	if (args < 1
	|| (!readyMode && !isPaused)
	|| OptIsGagged(client))
	{
		return Plugin_Continue;
	}
	
	if (client && GetClientTeam(client) == L4D_TEAM_SPECTATE)
	{
		if (!IsClientCaster(client) && GetConVarBool(cvarBlockSpecGlobalChat))
		{
			Command_Teamsay(client, args);
			PrintHintText(client, "Spectators cannot global chat in ready modes");
			return Plugin_Handled;
		}
	}
	
	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(sayWord[0] == '!' || sayWord[0] == '/')
	{
		if(StrEqual(sayWord[1], "notready")
		|| StrEqual(sayWord[1], "unready")
		|| StrEqual(sayWord[1], "ready")
		|| StrEqual(sayWord[1], "cast"))
		{
			return Plugin_Handled;
		}
	}
	
	if (isPaused) //Do our own chat output when the game is paused
	{
		decl String:sText[256];
		GetCmdArg(1, sText, sizeof(sText));
		if (!client
		|| (IsChatTrigger() && sText[0] == '/') //Ignore if it is a server message or a silent chat trigger
		|| sText[0] == '@') //Or admin talk
		{
			return Plugin_Continue;
		}
		
		PrintToChatAll("\x03%N\x01 : %s", client, sText); //Display the users message
		return Plugin_Handled; //Since the issue only occurs sometimes we need to block default output to prevent showing text twice
	}
	return Plugin_Continue;
}

public Action:Command_Teamsay(client, args)
{
	if (args < 1
	|| (!readyMode && !isPaused)
	|| OptIsGagged(client))
	{
		return Plugin_Continue;
	}
	
	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(sayWord[0] == '!' || sayWord[0] == '/')
	{
		if(StrEqual(sayWord[1], "notready")
		|| StrEqual(sayWord[1], "unready")
		|| StrEqual(sayWord[1], "ready")
		|| StrEqual(sayWord[1], "cast"))
		{
			return Plugin_Handled;
		}
	}
	
	if (isPaused) //Do our own chat output when the game is paused
	{
		decl String:sText[256];
		GetCmdArg(1, sText, sizeof(sText));
		if (!client
		|| (IsChatTrigger() && sText[0] == '/') //Ignore if it is a server message or a silent chat trigger
		|| sText[0] == '@') //Or admin talk
		{
			return Plugin_Continue;
		}
		
		decl String:sTeamName[16];
		new iTeam = GetClientTeam(client);
		if (iTeam == 3)
		{
			sTeamName = "Infected";
		}
		else if (iTeam == 2)
		{
			sTeamName = "Survivor";
		}
		else
		{
			sTeamName = "Spectator";
		}
		for (new i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				if (GetClientTeam(i) == iTeam) //Is teamchat so only display it to people on the same team
				{
					PrintToChat(i, "\x01(%s) \x03%N\x01 : %s", sTeamName, client, sText); //Display the users message
				}
			}
		}
		return Plugin_Handled; //Since the issue only occurs sometimes we need to block default output to prevent showing text twice
	}
	return Plugin_Continue;
}

public Action:readyUp(client, args)
{
	if (!readyMode
	|| !client
	|| readyStatus[client]
	|| (GetClientTeam(client) == L4D_TEAM_SPECTATE && !IsClientCaster(client)))
	{
		return Plugin_Handled;
	}
	
	//don't allow readying up if there's too few players
	new realPlayers = CountInGameHumans();
	new minPlayers = GetConVarInt(cvarReadyMinimum);
	
	//ready up the player and see if everyone is ready now
	decl String:name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	
	if(realPlayers >= minPlayers)
		PrintToChatAll("%s is ready.", name);
	else
	PrintToChatAll("%s is ready. A minimum of %d players is required.", name, minPlayers);
	
	readyStatus[client] = 1;
	checkStatus();
	
	DrawReadyPanelList();
	
	return Plugin_Handled;
}

public Action:readyDown(client, args)
{
	if (!readyMode
	|| !client
	|| !readyStatus[client]
	|| (GetClientTeam(client) == L4D_TEAM_SPECTATE && !IsClientCaster(client))
	|| isCampaignBeingRestarted
	|| insideCampaignRestart)
	{
		return Plugin_Handled;
	}
	
	decl String:name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	PrintToChatAll("%s is no longer ready.", name);
	
	readyStatus[client] = 0;
	checkStatus();
	
	DrawReadyPanelList();
	
	return Plugin_Handled;
}

public Action:regCaster(client, args)
{
	if (!readyMode
	|| !client
	|| GetClientTeam(client) != L4D_TEAM_SPECTATE)
	{
		return Plugin_Handled;
	}
	
	decl String:authid[96];
	GetClientAuthString(client, authid, sizeof(authid));
	SetTrieValue(casterTrie, authid, 1);
	
	ReplyToCommand(client, "You have registered as match caster, readying up will wait for you");
	return Plugin_Handled;
}

public Action:Command_Unpause(client, args)
{
	if (isPaused)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:Command_Reready(client, args)
{
	if (readyMode) return Plugin_Handled;
	
	pauseBetweenHalves = 1;
	PrintToChatAll("[SM] Match will pause at the end of this half and require readying up again.");
	
	return Plugin_Handled;
}


//draws a menu panel of ready and unready players
DrawReadyPanelList()
{
	if (!readyMode) return;
	static bool:scrollingText;
	/*
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Drawing the ready panel");
	#endif
	*/
	
	decl String:readyPlayers[1024];
	decl String:name[MAX_NAME_LENGTH];
	
	readyPlayers[0] = 0;
	
	new numPlayersRdy, numPlayersNotRdy, numPlayersSpec;	
	new ready, unready, spec;
	new bool:isCaster[L4D_MAXCLIENTS_PLUS1];
	
	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			isCaster[i] = IsClientCaster(i);

			if (GetClientTeam(i) == L4D_TEAM_SPECTATE && !isCaster[i])
			{
				spec++;
			}
			else
			{
				if(readyStatus[i])
					ready++;
				else
					unready++;
			}
		}
	}
	
	new Handle:panel = CreatePanel();
	
	if(ready)
	{
		DrawPanelText(panel, "READY");
		
		//->%d. %s makes the text yellow
		// otherwise the text is white
		
		for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
		{
			if(IsClientInGameHuman(i)) 
			{
				GetClientName(i, name, sizeof(name));
				
				if(readyStatus[i]) 
				{
					numPlayersRdy++;
					Format(readyPlayers, 1024, "->%d. %s%s", numPlayersRdy, name, isCaster[i] ? " [CASTER]" : "" );

					DrawPanelText(panel, readyPlayers);
					
					#if READY_DEBUG
					DrawPanelText(panel, readyPlayers);
					#endif
				}
			}
		}
	}
	
	if(unready)
	{
		DrawPanelText(panel, "NOT READY");
		
		for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
		{
			if(IsClientInGameHuman(i) && GetClientTeam(i) != L4D_TEAM_SPECTATE)
			{
				GetClientName(i, name, sizeof(name));
				
				if(!readyStatus[i]) 
				{
					numPlayersNotRdy++;
					Format(readyPlayers, 1024, "->%d. %s%s", numPlayersNotRdy, name, isCaster[i] ? " [CASTER]" : "" );

					DrawPanelText(panel, readyPlayers);
					#if READY_DEBUG
					DrawPanelText(panel, readyPlayers);
					#endif
				}
			}
		}
	}
	
	if (spec)
	{
		DrawPanelText(panel, "SPECTATING");
		
		for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
		{
			if(IsClientInGameHuman(i) && GetClientTeam(i) == L4D_TEAM_SPECTATE) 
			{
				GetClientName(i, name, sizeof(name));
			
				numPlayersSpec++;
				Format(readyPlayers, 1024, "->%d. %s", numPlayersSpec, name);
				DrawPanelText(panel, readyPlayers);
			}
		}
	}
	
	decl String:versionInfo[128];
	decl String:sCFGName[128];
	GetConVarString(cvarCFGName, sCFGName, sizeof(sCFGName));
	if (scrollingText)
	{
		Format(versionInfo, sizeof(versionInfo), "Created by Downtown1 & Frustian");
	}
	else
	{
		Format(versionInfo, sizeof(versionInfo), "Ready Up Modification v%s", READY_VERSION);
	}
	scrollingText = !scrollingText;
	DrawPanelText(panel, versionInfo);
	
	//#if CEVO_ADD_NOTICE
	if (sCFGName[0])
	{
		DrawPanelText(panel, sCFGName);
	}
	//#endif
	
	for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			SendPanelToClient(panel, i, Menu_ReadyPanel, READY_LIST_PANEL_LIFETIME);
		}
	}
	
	if(menuPanel != INVALID_HANDLE)
	{
		CloseHandle(menuPanel);
	}
	menuPanel = panel;
}


public Menu_ReadyPanel(Handle:menu, MenuAction:action, param1, param2) 
{
}

//freeze everyone until they ready up
readyOn()
{
	
	DebugPrintToAll("readyOn() called");
	
#if READY_SCAVENGE_WARMUP
	if(IsScavengeMode() && !isSecondRound)
	{
		//DebugPrintToAll("Warm 
		inWarmUp = true;
	}
	else
	{
		
		inWarmUp = false;
	}
#else
	inWarmUp = false;
#endif
	readyMode = true;
	
	PrintHintTextToAll("Ready mode on.\nSay !ready to ready up or !unready to unready.");
	
	if (!inWarmUp)
	{
		if(!hookedPlayerHurt) 
		{
			HookEvent("player_hurt", eventPlayerHurt);
			hookedPlayerHurt = 1;
		}
		if(IsScavengeMode())
		{
			//reset the scavenge setup timer every 0.5 seconds
			CreateTimer(READY_RESTART_SCAVENGE_TIMER, Timer_ResetScavengeSetup, _, TIMER_REPEAT);
		}
		else //versus
		{
			if(!isSecondRound && GetConVarBool(cvarDisableReadySpawns))
			{
				SetConVarInt(FindConVar("director_no_specials"), 1);
			}
			L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.9);
		}
		
		for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
		{
			readyStatus[i] = 0;
			if (IsValidEntity(i) && IsClientInGame(i) && (GetClientTeam(i) == L4D_TEAM_SURVIVORS)) 
			{
				
				#if READY_DEBUG
				decl String:curname[128];
				GetClientName(i,curname,128);
				DebugPrintToAll("[DEBUG] Freezing %s [%d] during readyOn().", curname, i);
				#endif
				
				ToggleFreezePlayer(i, true);
			}
		}
	}
	else // warm up on
	{
		if (bReadyOffCalled)
		{
			iInitialSetupTime = GetConVarInt(cvarScavengeSetup);
			iInitialAllTalk = GetConVarInt(FindConVar("sv_alltalk"));
			iInitialGhostTimeMin = GetConVarInt(FindConVar("z_ghost_delay_min"));
			iInitialGhostTimeMax = GetConVarInt(FindConVar("z_ghost_delay_max"));
		}
		bReadyOffCalled = false;
		DebugPrintToAll("Warmup on");
		iInitialSetupTime = GetConVarInt(cvarScavengeSetup);
		SetConVarInt(cvarScavengeSetup, 0);
		SetConVarFlags(cvarGod,GetConVarFlags(cvarGod) & ~FCVAR_NOTIFY);
		SetConVarInt(cvarGod, 1);
		SetConVarFlags(cvarGod,GetConVarFlags(cvarGod) | FCVAR_NOTIFY);
		SetConVarInt(FindConVar("director_no_mobs"), 1);
		SetConVarInt(FindConVar("director_ready_duration"), 0);
		SetConVarInt(FindConVar("z_common_limit"), 0);
		SetConVarInt(FindConVar("sv_alltalk"), 1);
		SetConVarInt(FindConVar("z_ghost_delay_max"), 0);
		SetConVarInt(FindConVar("z_ghost_delay_min"), 0);
		L4D_SetRoundEndTime(L4D_SCAVENGE_GAMECLOCK_HALT);
	}
	
	if(!unreadyTimerExists)
	{
		unreadyTimerExists = true;
		CreateTimer(READY_UNREADY_HINT_PERIOD, timerUnreadyCallback, _, TIMER_REPEAT);
	}
}

//allow everyone to move now
readyOff()
{
	DebugPrintToAll("readyOff() called");
	
	readyMode = false;
	
	//events seem to be all unhooked _before_ OnPluginEnd
	//though even if it wasnt, they'd get unhooked after anyway..
	if(hookedPlayerHurt && !insidePluginEnd) 
	{
		UnhookEvent("player_hurt", eventPlayerHurt);
		hookedPlayerHurt = 0;
	}
	if (!inWarmUp)
	{	
		if(GetConVarBool(cvarDisableReadySpawns))
		{
			ResetConVar(FindConVar("director_no_specials"));
		}
		if(insidePluginEnd)
		{
			UnfreezeAllPlayers();
		}
	}
	else //warm up off
	{
		bReadyOffCalled = true;
		DebugPrintToAll("Warmup off");
		SetConVarInt(cvarScavengeSetup, iInitialSetupTime);
		SetConVarFlags(cvarGod,GetConVarFlags(cvarGod) & ~FCVAR_NOTIFY);
		SetConVarInt(cvarGod, 0);
		SetConVarFlags(cvarGod,GetConVarFlags(cvarGod) | FCVAR_NOTIFY);
		
		
		SetConVarInt(FindConVar("sv_alltalk"), iInitialAllTalk);
		SetConVarInt(FindConVar("z_ghost_delay_max"), iInitialGhostTimeMax);
		SetConVarInt(FindConVar("z_ghost_delay_min"), iInitialGhostTimeMin);
		L4D_ResetRoundNumber();
		inWarmUp = false;
	}
	
	//used to unfreeze all players here always
	//now we will do it at the beginning of the round when its live
	//so that players cant open the safe room door during the restarts
}
stock L4D_ResetRoundNumber()
{
	static bool:init = false;
	static Handle:func = INVALID_HANDLE;
	
	if(!init)
	{
		new Handle:conf = LoadGameConfigFile(GAMECONFIG_FILE);
		if(conf == INVALID_HANDLE)
		{
			LogError("Could not load gamedata/%s.txt", GAMECONFIG_FILE);
			DebugPrintToAll("Could not load gamedata/%s.txt", GAMECONFIG_FILE);
		}
		
		StartPrepSDKCall(SDKCall_GameRules);
		new bool:readConf = PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTerrorGameRules_ResetRoundNumber");
		if(!readConf)
		{
			ThrowError("Failed to read function from game configuration file");
		}
		func = EndPrepSDKCall();
		
		if(func == INVALID_HANDLE)
		{
			ThrowError("Failed to end prep sdk call");
		}
		
		init = true;
	}

	SDKCall(func);
	DebugPrintToAll("CTerrorGameRules::ResetRoundNumber()");
}
stock L4D_SetRoundEndTime(Float:endTime)
{
	static bool:init = false;
	static Handle:func = INVALID_HANDLE;
	if(!init)
	{
		new Handle:conf = LoadGameConfigFile(GAMECONFIG_FILE);
		if(conf == INVALID_HANDLE)
		{
			LogError("Could not load gamedata/%s.txt", GAMECONFIG_FILE);
			DebugPrintToAll("Could not load gamedata/%s.txt", GAMECONFIG_FILE);
		}
		
		StartPrepSDKCall(SDKCall_GameRules);
		new bool:readConf = PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTerrorGameRules_SetRoundEndTime");
		if(!readConf)
		{
			ThrowError("Failed to read function from game configuration file");
		}
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		func = EndPrepSDKCall();
		
		if(func == INVALID_HANDLE)
		{
			ThrowError("Failed to end prep sdk call");
		}
		
		init = true;
	}

	SDKCall(func, endTime);
	DebugPrintToAll("CTerrorGameRules::SetRoundTime(%f)", endTime);
}
UnfreezeAllPlayers()
{
	for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if (IsClientInGame(i) && L4D2Team:GetClientTeam(i) != L4D2Team_Spectators) 
		{
			#if READY_DEBUG
			decl String:curname[128];
			GetClientName(i,curname,128);
			DebugPrintToAll("[DEBUG] Unfreezing %s [%d] during UnfreezeAllPlayers().", curname, i);
			#endif
			
			ToggleFreezePlayer(i, false);
		}
	}
}

//make everyone un-ready, but don't actually freeze them
compOn()
{
	DebugPrintToAll("compOn() called");
	
	goingLive = 0;
	readyMode = false;
	forcedStart = 0;
	
	for (new i = 1; i <= MAXPLAYERS; i++) readyStatus[i] = 0;
}

//abort an impending countdown to a live match
public Action:compAbort(client, args)
{
	if (!goingLive)
	{
		ReplyToCommand(0, "L4DC: Nothing to abort.");
		return Plugin_Handled;
	}
	
	if (goingLive)
	{
		KillTimer(liveTimer);
		forcedStart = 0;
		goingLive = 0;
	}
	
	PrintHintTextToAll("Match was aborted by command.");
	
	return Plugin_Handled;
}

//begin the ready mode (everyone now needs to ready up before they can move)
public Action:compReady(client, args)
{
	if (goingLive)
	{
		ReplyToCommand(0, "[L4D RUP] Already going live, ignoring.");
		return Plugin_Handled;
	}
	
	compOn();
	readyOn();
	
	return Plugin_Handled;
}

//force start a match using admin
public Action:compStart(client, args)
{
	if(!readyMode)
		return Plugin_Handled;
	
	if (goingLive)
	{
		ReplyToCommand(0, "[L4D RUP] Already going live, ignoring.");
		return Plugin_Handled;
	}
	
	goingLive = READY_LIVE_COUNTDOWN;
	forcedStart = 1;
	liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

//restart the map when we toggle the cvar
public ConVarChange_ReadyEnabled(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		new value = StringToInt(newValue);
		
		if(value)
		{
			//if sv_search_key is "" && l4d_ready_disable_search_key is 1
			//then don't let admins turn on our plugin
			if(GetConVarInt(cvarReadySearchKeyDisable))
			{
				decl String:searchKey[128];
				GetConVarString(cvarSearchKey, searchKey, 128);
				
				if(!searchKey[0])
				{
					LogMessage("Ready plugin will not start while sv_search_key is \"\"");
					PrintToChatAll("[SM] Ready plugin will not start while sv_search_key is \"\"");
					
					ServerCommand("l4d_ready_enabled 0");
					return;
				}
			}
			
			PrintToChatAll("[SM] Ready plugin has been enabled, restarting map in %.0f seconds", READY_RESTART_MAP_DELAY);
		}
		else
		{
			PrintToChatAll("[SM] Ready plugin has been disabled, restarting map in %.0f seconds", READY_RESTART_MAP_DELAY);
			readyOff();
		}
		RestartMapDelayed();
	}
}


//disable most non-competitive plugins
public ConVarChange_ReadyCompetition(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		new value = StringToInt(newValue);
		
		if(value)
		{
			//TODO: use plugin iterators such as GetPluginIterator
			// to unload all plugins BUT the ones below
			
			ServerCommand("sm plugins load_unlock");
			ServerCommand("sm plugins unload_all");
			ServerCommand("sm plugins load basebans.smx");
			ServerCommand("sm plugins load basecommands.smx");
			ServerCommand("sm plugins load admin-flatfile.smx");
			ServerCommand("sm plugins load adminhelp.smx");
			ServerCommand("sm plugins load adminmenu.smx");
			ServerCommand("sm plugins load l4dscores.smx"); //IMPORTANT: load before l4dready!
			ServerCommand("sm plugins load l4dready.smx");
			ServerCommand("sm plugins load_lock");
			
			DebugPrintToAll("Competition mode enabled, plugins unloaded...");
			
			//TODO: also call sm_restartmap and sm_resetscores
			// this removes the dependency from configs to know what to do :)
			
			//Maybe make this command sm_competition_on, sm_competition_off ?
			//that way people will probably not use in server.cfg 
			// and they can exec the command over and over and it will be fine
		}
		else
		{
			ServerCommand("sm plugins load_unlock");
			ServerCommand("sm plugins refresh");

			DebugPrintToAll("Competition mode enabled, plugins reloaded...");
		}
	}
}

//disable the ready mod if sv_search_key is ""
public ConVarChange_SearchKey(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{	
		if(!newValue[0])
		{
			//wait about 5 secs and then disable the ready up mod
			
			//this gives time for l4d_ready_server_cfg to get executed
			//if a server.cfg disables the sv_search_key
			CreateTimer(5.0, Timer_SearchKeyDisabled, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

//repeatedly count down until the match goes live
public Action:Timer_SearchKeyDisabled(Handle:timer)
{
	//if sv_search_key is "" && l4d_ready_disable_search_key is 1
	//then don't let admins turn on our plugin
	if(GetConVarInt(cvarReadySearchKeyDisable) && GetConVarInt(cvarEnforceReady))
	{
		decl String:searchKey[128];
		GetConVarString(cvarSearchKey, searchKey, 128);
		
		if(!searchKey[0])
		{
			PrintToChatAll("[SM] sv_search_key is not set, the l4dready plugin will now automatically disable itself.");
			
			ServerCommand("l4d_ready_enabled 0");
			return;
		}
	}
}

public Action:Command_SwapTeams(client, args)
{
	PrintToChatAll("[SM] Survivor and Infected teams have been swapped.");
	
	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) != L4D_TEAM_SPECTATE)
		{
			teamPlacementArray[i] = GetOppositeClientTeam(i);
		}
	}
	
	TryTeamPlacementDelayed();
	
	return Plugin_Handled;
}


public Action:Command_Swap(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swap <player1> [player2] ... [playerN] - swap all listed players to opposite teams");
		return Plugin_Handled;
	}
	
	new player_id;
	decl String:player[64];
	
	for(new i; i < args; i++)
	{
		GetCmdArg(i+1, player, sizeof(player));
		player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);
		
		if(player_id == -1)
			continue;
		
		new team = GetOppositeClientTeam(player_id);
		teamPlacementArray[player_id] = team;
		PrintToChatAll("[SM] %N has been swapped to the %s team.", player_id, L4D_TEAM_NAME(team));
	}
	
	TryTeamPlacement();
	
	return Plugin_Handled;
}


public Action:Command_SwapTo(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swapto <player1> [player2] ... [playerN] <teamnum> - swap all listed players to team <teamnum> (1,2,or 3)");
		return Plugin_Handled;
	}
	
	new team;
	decl String:teamStr[64];
	GetCmdArg(args, teamStr, sizeof(teamStr));
	team = StringToInt(teamStr);
	if(!team)
	{
		ReplyToCommand(client, "[SM] Invalid team %s specified, needs to be 1, 2, or 3", teamStr);
		return Plugin_Handled;
	}
	
	new player_id;
	decl String:player[64];
	
	for(new i; i < args - 1; i++)
	{
		GetCmdArg(i+1, player, sizeof(player));
		player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);
		
		if(player_id == -1)
			continue;
		
		teamPlacementArray[player_id] = team;
		PrintToChatAll("[SM] %N has been swapped to the %s team.", player_id, L4D_TEAM_NAME(team));
	}
	
	TryTeamPlacement();
	
	return Plugin_Handled;
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	TryTeamPlacementDelayed();
}

/*
* Do a delayed "team placement"
* 
* This way all the pending team changes will go through instantly
* and we don't end up in TryTeamPlacement again before then
*/
new bool:pendingTryTeamPlacement;
TryTeamPlacementDelayed()
{
	if(!pendingTryTeamPlacement)
	{
		CreateTimer(SCORE_DELAY_PLACEMENT, Timer_TryTeamPlacement);	
		pendingTryTeamPlacement = true;
	}
}

public Action:Timer_TryTeamPlacement(Handle:timer)
{
	TryTeamPlacement();
	pendingTryTeamPlacement = false;
}

/*
* Try to place people on the right teams
* after some kind of event happens that allows someone to be moved.
* 
* Should only be called indirectly by TryTeamPlacementDelayed()
*/
TryTeamPlacement()
{
	/*
	* Calculate how many free slots a team has
	*/
	new free_slots[4];
	
	free_slots[L4D_TEAM_SPECTATE] = GetTeamMaxHumans(L4D_TEAM_SPECTATE);
	free_slots[L4D_TEAM_SURVIVORS] = GetTeamMaxHumans(L4D_TEAM_SURVIVORS);
	free_slots[L4D_TEAM_INFECTED] = GetTeamMaxHumans(L4D_TEAM_INFECTED);	
	
	free_slots[L4D_TEAM_SURVIVORS] -= GetTeamHumanCount(L4D_TEAM_SURVIVORS);
	free_slots[L4D_TEAM_INFECTED] -= GetTeamHumanCount(L4D_TEAM_INFECTED);
	
	DebugPrintToAll("TP: Trying to do team placement (free slots %d/%d)...", free_slots[L4D_TEAM_SURVIVORS], free_slots[L4D_TEAM_INFECTED]);
	
	/*
	* Try to place people on the teams they should be on.
	*/
	
	decl String:authid[96];
	new anyval;
	
	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			new team = teamPlacementArray[i];

			//client was not manually placed? then check...
			if(!team)
			{
				GetClientAuthString(i, authid, sizeof(authid));
				//if client was a spectator before and should go there again.
				if (GetTrieValue(teamPlacementTrie, authid, anyval))
				{
					DebugPrintToAll("TP: %N was spectator before and will be put there again.", i);
				
					team = L4D_TEAM_SPECTATE;
					// also scratch their info from the Trie to avoid repetition effects
					RemoveFromTrie(teamPlacementTrie, authid);
				}
				// in any other case theres nothing to do
				else
				{
					continue;
				}
			}
			
			new old_team = GetClientTeam(i);
			
			//client is already on the right team
			if(team == old_team)
			{
				teamPlacementArray[i] = 0;
				teamPlacementAttempts[i] = 0;
				
				DebugPrintToAll("TP: %N is already on correct team (%d)", i, team);
			}
			//there's still room to place him on the right team
			else if (free_slots[team] > 0)
			{
				ChangePlayerTeamDelayed(i, team);
				DebugPrintToAll("TP: Moving %N to %d soon", i, team);
				
				free_slots[team]--;
				free_slots[old_team]++;
			}
			/*
			* no room to place him on the right team,
			* so lets just move this person to spectate
			* in anticipation of being to move him later
			*/
			else
			{
				DebugPrintToAll("TP: %d attempts to move %N to team %d", teamPlacementAttempts[i], i, team);
				
				/*
				* don't keep playing in an infinite join spectator loop,
				* let him join another team if moving him fails
				*/
				if(teamPlacementAttempts[i] > 0)
				{
					DebugPrintToAll("TP: Cannot move %N onto %d, team full", i, team);
					
					//client joined a team after he was moved to spec temporarily
					if(GetClientTeam(i) != L4D_TEAM_SPECTATE)
					{
						DebugPrintToAll("TP: %N has willfully moved onto %d, cancelling placement", i, GetClientTeam(i));
						teamPlacementArray[i] = 0;
						teamPlacementAttempts[i] = 0;
					}
				}
				/*
				* place him to spectator so room on the previous team is available
				*/
				else
				{
					free_slots[L4D_TEAM_SPECTATE]--;
					free_slots[old_team]++;
					
					DebugPrintToAll("TP: Moved %N to spectator, as %d has no room", i, team);
					
					ChangePlayerTeamDelayed(i, L4D_TEAM_SPECTATE);
					
					teamPlacementAttempts[i]++;
				}
			}
		}
		//the player is a bot, or disconnected, etc.
		else 
		{
			if(!IsClientInGame(i) || IsFakeClient(i)) 
			{
				if(teamPlacementArray[i])
					DebugPrintToAll("TP: Defaultly removing %d from placement consideration", i);
				
				teamPlacementArray[i] = 0;
				teamPlacementAttempts[i] = 0;
			}			
		}
	}
	
	/* If somehow all 8 players are connected and on opposite teams
	*  then unfortunately this function will not work.
	*  but of course this should not be called in that case,
	*  instead swapteams can be used
	*/
}

/*
* Saves the annoying crowd of Spectators into a Trie so they dont get sorted into a team
* next map.
*/
SaveSpectators()
{
	ClearTrie(teamPlacementTrie);
	decl String:authid[96];
	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			if (GetClientTeam(i) == L4D_TEAM_SPECTATE)
			{
				GetClientAuthString(i, authid, sizeof(authid));
				SetTrieValue(teamPlacementTrie, authid, L4D_TEAM_SPECTATE);
			}
		}
	}
}

bool:IsClientCaster(client)
{
	decl String:authid[96];
	new dummy;
	GetClientAuthString(client, authid, sizeof(authid));
	
	if (GetTrieValue(casterTrie, authid, dummy))
		return true;
		
	return false;
}

/*
* Return the opposite team of that the client is on
*/
stock GetOppositeClientTeam(client)
{
	return OppositeCurrentTeam(GetClientTeam(client));	
}

stock OppositeCurrentTeam(team)
{
	if(team == L4D_TEAM_INFECTED)
		return L4D_TEAM_SURVIVORS;
	else if(team == L4D_TEAM_SURVIVORS)
		return L4D_TEAM_INFECTED;
	else if(team == L4D_TEAM_SPECTATE)
		return L4D_TEAM_SPECTATE;
	
	else
		return -1;
}

stock ChangePlayerTeamDelayed(client, team)
{
	new Handle:pack;
	
	CreateDataTimer(SCORE_DELAY_TEAM_SWITCH, Timer_ChangePlayerTeam, pack);	
	
	WritePackCell(pack, client);
	WritePackCell(pack, team);
}

public Action:Timer_ChangePlayerTeam(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	
	new client = ReadPackCell(pack);
	new team = ReadPackCell(pack);
	
	ChangePlayerTeam(client, team);
}


stock bool:ChangePlayerTeam(client, team)
{
	if(GetClientTeam(client) == team) return true;
	
	if(team != L4D_TEAM_SURVIVORS)
	{
		//we can always swap to infected or spectator, it has no actual limit
		ChangeClientTeam(client, team);
		return true;
	}
	
	if(GetTeamHumanCount(team) == GetTeamMaxHumans(team))
	{
		DebugPrintToAll("ChangePlayerTeam() : Cannot switch %N to team %d, as team is full");
		return false;
	}
	
	//for survivors its more tricky
	new bot;
	
	for(bot = 1; 
		bot < L4D_MAXCLIENTS_PLUS1 && (!IsClientInGame(bot) || !IsFakeClient(bot) || (GetClientTeam(bot) != L4D_TEAM_SURVIVORS));
		bot++) {}
	
	if(bot == L4D_MAXCLIENTS_PLUS1)
	{
		DebugPrintToAll("Could not find a survivor bot, adding a bot ourselves");
		
		decl String:command[] = "sb_add";
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		
		ServerCommand("sb_add");
		
		SetCommandFlags(command, flags);
		
		DebugPrintToAll("Added a survivor bot, trying again...");
		return false;
	}

	//have to do this to give control of a survivor bot
	SDKCall(fSHS, bot, client);
	SDKCall(fTOB, client, true);
	
	return true;
}

stock GetTeamHumanCount(team)
{
	new humans = 0;
	
	new i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) == team)
		{
			humans++;
		}
	}
	
	return humans;
}

stock GetTeamMaxHumans(team)
{
	if(team == L4D_TEAM_SURVIVORS)
	{
		return GetConVarInt(FindConVar("survivor_limit"));
	}
	else if(team == L4D_TEAM_INFECTED)
	{
		return GetConVarInt(FindConVar("z_max_player_zombies"));
	}
	else if(team == L4D_TEAM_SPECTATE)
	{
		return L4D_MAXCLIENTS;
	}
	
	return -1;
}

//when the match goes live, at round_end of the last automatic restart
//just before the round_start
RoundEndBeforeLive()
{
	readyOff();	
}

//round_start just after the last automatic restart
RoundIsLive()
{
	UnfreezeAllPlayers();
	
	if(GetConVarBool(cvarDisableReadySpawns))
	{
		ResetConVar(FindConVar("director_no_specials"));
	}
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, GetConVarFloat(FindConVar("versus_force_start_time")));
	
	Call_StartForward(fwdOnRoundIsLive);
	Call_Finish();
	
	CreateTimer(1.0, timerLiveMessageCallback, _, _);
}

ToggleFreezePlayer(client, freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

//client is in-game and not a bot
bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client);
}

CountInGameHumans()
{
	new i, realPlayers = 0;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i)) 
		{
			realPlayers++;
		}
	}
	return realPlayers;
}

public GetAnyClient()
{
	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGameHuman(i))
		{
			return i;
		}
	}
	return 0;
}


DebugPrintToAll(const String:format[], any:...)
{
#if READY_DEBUG	|| READY_DEBUG_LOG
	decl String:buffer[192];
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
#if READY_DEBUG
	PrintToChatAll("[READY] %s", buffer);
#endif
	LogMessage("%s", buffer);
#else
	//suppress "format" never used warning
	if(format[0])
		return;
	else
		return;
#endif
}

bool:IsTargetL4D2()
{
	decl String:gameFolder[32];
	GetGameFolderName(gameFolder, sizeof(gameFolder));
	if (StrContains(gameFolder, "left4dead2") > -1)
	{
		return true;
	}
	else
	{
		return false;
	}	
}

stock bool:IsScavengeMode()
{
	decl String:sGameMode[32];
	GetConVarString(cvarGameMode, sGameMode, sizeof(sGameMode));
	if (StrContains(sGameMode, "scavenge") > -1)
	{
		return true;
	}
	else
	{
		return false;
	}	
}

stock bool:IsVersusMode()
{
	decl String:sGameMode[32];
	GetConVarString(cvarGameMode, sGameMode, sizeof(sGameMode));
	if (StrContains(sGameMode, "versus") > -1
	|| StrEqual(sGameMode, "mutation12")) // realism versus
	{
		return true;
	}
	else
	{
		return false;
	}	
}

public PersistentTeam:GetClientPersistentTeam(client)
{
	return GetL4D2TeamPersistentTeam(L4D2Team:GetClientTeam(client));
}

public PersistentTeam:GetL4D2TeamPersistentTeam(L4D2Team:team)
{
	if (team == L4D2Team_Unknown || team == L4D2Team_Spectators)
	{
		return PersistentTeam_Invalid;
	}
	if ((defaultTeams && !isSecondRound) || (!defaultTeams && isSecondRound))
	{
		if (team == L4D2Team_Survivors)
		{
			return PersistentTeam_A;
		}
		else
		{
			return PersistentTeam_B;
		}
	}
	else
	{
		if (team == L4D2Team_Survivors)
		{
			return PersistentTeam_B;
		}
		else
		{
			return PersistentTeam_A;
		}
	}
}

TeamAttemptPause(client)
{
	static iPauses[PersistentTeam];
	if (isNewCampaign)
	{
		iPauses[PersistentTeam_A] = 0;
		iPauses[PersistentTeam_B] = 0;
	}
	if (iPauses[GetClientPersistentTeam(client)] >= GetConVarInt(cvarPausesAllowed))
	{
		ReplyToCommand(client, "[SM] Your team does not have any pauses remaining for this campaign.");
		return false;
	}
	iPauses[GetClientPersistentTeam(client)]++;
	PrintToChatAll("[SM] %N has paused the game! Their team has %d pauses remaining for this campaign.", client, GetConVarInt(cvarPausesAllowed) - iPauses[GetClientPersistentTeam(client)]);
	PrintToChatAll("[SM] Players will be stuck at 99%% loading while the game is paused. Unpause it to let them through.");
	PauseGame(client);
	return true;
}

ClientAttemptsPause(client)
{
	new team = GetClientTeam(client);
	if(!(team == L4D_TEAM_INFECTED || team == L4D_TEAM_SURVIVORS) || !GetConVarInt(cvarPausesAllowed) || readyMode || isPaused)
	{
		return;
	}
	if (TeamAttemptPause(client))
	{
		lastTeamPause = team;
	}
}

ClientAttemptsUnpause(client)
{
	new team = GetClientTeam(client);
	if(!(team == L4D_TEAM_INFECTED || team == L4D_TEAM_SURVIVORS) || !GetConVarInt(cvarPausesAllowed) || !isPaused || isUnpausing || readyMode)
	{
		return;
	}
	if (team == lastTeamPause || canUnpause)
	{
		PrintToChatAll("[SM] %N has unpaused the game! Game is going live in %d seconds...", client, L4D_UNPAUSE_DELAY);
		UnpauseGameDelay(client);
		return;
	}
	ReplyToCommand(client, "[SM]Your team can not unpause at this time.");
}

public nativeIsGamePaused(Handle:plugin, numParams)
{
	return isPaused;
}

PauseGame(any:client)
{
	SetConVarInt(FindConVar("sv_pausable"), 1); //Ensure sv_pausable is set to 1
	FakeClientCommand(client, "setpause"); //Send pause command
	SetConVarInt(FindConVar("sv_pausable"), 0); //Reset sv_pausable back to 0
	iInitialAllTalk = GetConVarInt(FindConVar("sv_alltalk"));
	SetConVarInt(FindConVar("sv_alltalk"), 1);
	isPaused = true;
	canUnpause = false;
	timerMinimumPause = CreateTimer(GetConVarFloat(cvarPauseDuration), AllCanUnpause, _, TIMER_FLAG_NO_MAPCHANGE);
}

UnpauseGame(any:client)
{
	if (!client)
	{
		client = GetAnyClient();
	}
	
	isPaused = false;
	SetConVarInt(FindConVar("sv_pausable"), 1); //Ensure sv_pausable is set to 1
	FakeClientCommand(client, "unpause"); //Send unpause command
	SetConVarInt(FindConVar("sv_pausable"), 0); //Reset sv_pausable back to 0
	SetConVarInt(FindConVar("sv_alltalk"), iInitialAllTalk);
	if (!canUnpause)
	{
		KillTimer(timerMinimumPause);
		canUnpause = true;
	}
}

public Action:UnPauseCountDown(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	static Countdown = L4D_UNPAUSE_DELAY-1;
	//new timeslooped = RoundToCeil(GetGameTime())-ReadPackCell(pack);
	if (Countdown <= 0)
	{
		PrintHintTextToAll("Game is LIVE");
		isUnpausing = false;
		Countdown = L4D_UNPAUSE_DELAY-1;
		UnpauseGame(ReadPackCell(pack));
		
		return Plugin_Stop;
	}
	
	PrintToChatAll("Game is going live in %d seconds...", Countdown);
	if (Countdown >= L4D_UNPAUSE_DELAY-1 || !isUnpausing)
		isUnpausing = true;
	Countdown--;
	
	return Plugin_Continue;
}

UnpauseGameDelay(client)
{
	isUnpausing = true;
	new Handle:pack;
	CreateDataTimer(1.0, UnPauseCountDown, pack, TIMER_REPEAT);
	//WritePackCell(pack, RoundToCeil(GetGameTime()));
	WritePackCell(pack, client);
}

public Action:AllCanUnpause(Handle:timer)
{
	if (isPaused)
	{
		canUnpause = true;
		PrintToChatAll("[SM] The required minimum pause time has elapsed.  Either team can now unpause the game.");
	}
	return Plugin_Stop;
}

public Action:readyPause(client, args)
{
	//server can pause without a request
	if(!client)
	{
		for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
		{
			if(IsClientInGame(i))
			{
				PauseGame(i);
				return Plugin_Handled;
			}
		}
	}
	
	ClientAttemptsPause(client);
	
	return Plugin_Handled;
}
public Action:readyUnpause(client, args)
{
	//server can unpause without a request
	if(!client)
	{
		for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
		{
			if(IsClientInGame(i))
			{
				UnpauseGame(i);
				return Plugin_Handled;
			}
		}
	}
	
	ClientAttemptsUnpause(client);
	
	return Plugin_Handled;
}
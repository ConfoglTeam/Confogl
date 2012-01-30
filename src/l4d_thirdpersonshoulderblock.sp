
#define PLUGIN_VERSION "1.3"

#pragma semicolon 1

#include <sourcemod>

public Plugin:myinfo =
{
	name = "Thirdpersonshoulder Block",
	author = "Don",
	description = "Kicks clients who enable the thirdpersonshoulder mode on L4D1/2 to prevent them from looking around corners, through walls etc.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=159582"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:sGame[12];
	GetGameFolderName(sGame, sizeof(sGame));
	if (StrEqual(sGame, "left4dead") || StrEqual(sGame, "left4dead2"))	/* Only load the plugin if the server is running Left 4 Dead or Left 4 Dead 2.
										 * Loading the plugin on Counter-Strike: Source or Team Fortress 2 would cause all clients to get kicked,
										 * because the thirdpersonshoulder mode and the corresponding ConVar that we check do not exist there.
										 */
	{
		return APLRes_Success;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports L4D1/2");
		return APLRes_Failure;
	}
}

public OnPluginStart()
{
	CreateConVar("l4d_tpsblock_version", PLUGIN_VERSION, "Version of the Thirdpersonshoulder Block plugin", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateTimer(GetRandomFloat(2.5, 3.5), CheckClients, _, TIMER_REPEAT);
}

public Action:CheckClients(Handle:timer)
{
	for (new iClientIndex = 1; iClientIndex <= MaxClients; iClientIndex++)
	{
		if (IsClientInGame(iClientIndex) && !IsFakeClient(iClientIndex))
		{
			if (GetClientTeam(iClientIndex) == 2 || GetClientTeam(iClientIndex) == 3)	// Only query clients on survivor or infected team, ignore spectators.
			{
				QueryClientConVar(iClientIndex, "c_thirdpersonshoulder", QueryClientConVarCallback);
			}
		}
	}	
}

public QueryClientConVarCallback(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (IsClientInGame(client) && !IsClientInKickQueue(client))
	{
		if (result != ConVarQuery_Okay)		/* If the ConVar was somehow not found on the client, is not valid or is protected, kick the client.
							 * The ConVar should always be readable unless the client is trying to prevent it from being read out.
							 */
		{
			KickClient(client, "Kicked for potentially using thirdpersonshoulder mode.\nConVar c_thirdpersonshoulder not found, not valid or protected");
			LogAction(0, client, "Kicked \"%L\" for potentially using thirdpersonshoulder mode, ConVar c_thirdpersonshoulder not found, not valid or protected", client);
			PrintToChatAll("[SM] Kicked %N for potentially using thirdpersonshoulder mode, ConVar c_thirdpersonshoulder not found, not valid or protected", client);
		}
		else if (!StrEqual(cvarValue, "false") && !StrEqual(cvarValue, "0"))	/* If the ConVar was found on the client, but is not set to either "false" or "0",
											 * kick the client as well, as he might be using thirdpersonshoulder.
											 */
		{
			KickClient(client, "Kicked for potentially using thirdpersonshoulder mode.\nEnter \"c_thirdpersonshoulder 0\" (without the \"\") in your console before rejoining the server");
			LogAction(0, client, "Kicked \"%L\" for potentially using thirdpersonshoulder mode", client);
			PrintToChatAll("[SM] Kicked %N for potentially using thirdpersonshoulder mode", client);
		}
	}
}

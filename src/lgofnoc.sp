#pragma semicolon 1

#include <sourcemod>
#include "functions.sp"
#include "configs.sp"
#include "customtags.inc"
#include "keyvalues_stocks.inc"

#include "MapInfo.sp"
#include "CvarSettings.sp"
#include "MatchMode.sp"

public Plugin:myinfo = 
{
	name = "LGOFNOC Config Manager",
	author = "Confogl Team",
	description = "A competitive configuration management system for Source games",
	version = "1.0",
	url = "http://github.com/ProdigySim/LGOFNOC/"
}

public OnPluginStart()
{
	InitConfigsPaths();
	InitCvarSettings();
	RegisterMatchModeCommands();
	
	AddCustomServerTag("lgofnoc", true);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegisterConfigsNatives();
	RegisterMapInfoNatives();
	RegisterMatchModeNatives();
	RegPluginLibrary("lgofnoc");
}

public OnPluginEnd()
{
	ClearAllCvarSettings();
	RemoveCustomServerTag("lgofnoc");
}

public OnMapStart()
{
	UpdateMapInfo();
	MatchMode_ExecuteConfigs();
}

public OnMapEnd() 
{
	MapInfo_OnMapEnd();
}

public OnGameFrame()
{
	GameFramePluginCheck();
}

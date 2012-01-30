#include <sourcemod>
#include <left4downtown>


public Plugin:myinfo = 
{
	name = "L4D2 Consistent Hordes",
	author = "ProdigySim",
	description = "Resets the natural horde timer on round start",
	version = "1.0",
	url = "http://prodigysim.com/"
}

public Action:OFSLA_ForceMobSpawnTimer(Handle:timer)
{
	// Workaround to make tank horde blocking always work
	// Makes the first horde always start 100s after survivors leave saferoom
	static Handle:MobSpawnTimeMin, Handle:MobSpawnTimeMax;
	if(MobSpawnTimeMin == INVALID_HANDLE)
	{
		MobSpawnTimeMin = FindConVar("z_mob_spawn_min_interval_normal");
		MobSpawnTimeMax = FindConVar("z_mob_spawn_max_interval_normal");
	}
	L4D2_CTimerStart(L4D2CT_MobSpawnTimer, GetRandomFloat(GetConVarFloat(MobSpawnTimeMin), GetConVarFloat(MobSpawnTimeMax)));
}
public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	CreateTimer(0.1, OFSLA_ForceMobSpawnTimer);
	
	return Plugin_Continue;
}

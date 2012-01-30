#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include "weapons.inc"

#define MAX_WEAPON_NAME_LENGTH 32
#define GAMEDATA_FILE          "l4d_wlimits"
#define GAMEDATA_USE_AMMO      "CWeaponAmmoSpawn_Use"

public Plugin:myinfo =
{
	name = "L4D Weapon Limits",
	author = "CanadaRox",
	description = "Restrict weapons individually or together",
	version = "1.1a",
	url = "https://www.github.com/CanadaRox/sourcemod-plugins/tree/master/weapon_limits"
}

enum LimitArrayEntry
{
	LAE_iLimit,
	LAE_WeaponArray[_:WeaponId/32+1]
}

new Handle:hSDKGiveDefaultAmmo;
new Handle:hLimitArray;
new bIsLocked;
new iAmmoPile;

public OnPluginStart()
{
	hLimitArray = CreateArray(_:LimitArrayEntry);
	L4D2Weapons_Init();

	/* Preparing SDK Call */
	/* {{{ */
	new Handle:conf = LoadGameConfigFile(GAMEDATA_FILE);

	if (conf == INVALID_HANDLE)
		ThrowError("Gamedata missing: %s", GAMEDATA_FILE);

	StartPrepSDKCall(SDKCall_Entity);

	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Signature, GAMEDATA_USE_AMMO))
		ThrowError("Gamedata missing signature: %s", GAMEDATA_USE_AMMO);

	// Client that used the ammo spawn
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	hSDKGiveDefaultAmmo = EndPrepSDKCall();
	/* }}} */

	RegServerCmd("l4d_wlimits_add", AddLimit_Cmd, "Add a weapon limit");
	RegServerCmd("l4d_wlimits_lock", LockLimits_Cmd, "Locks the limits to improve search speeds");
	RegServerCmd("l4d_wlimits_clear", ClearLimits_Cmd, "Clears all weapon limits (limits must be locked to be cleared)");
}

public OnPluginEnd()
{
	ClearLimits();
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_WeaponCanUse, WeaponCanUse);
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(2.0, RoundStartDelay_Timer);
}

public Action:RoundStartDelay_Timer(Handle:timer)
{
	FindAmmoSpawn();
}

public Action:AddLimit_Cmd(args)
{
	if (bIsLocked)
	{
		PrintToServer("Limits have been locked");
		return Plugin_Handled;
	}
	else if (args < 2)
	{
		PrintToServer("Usage: l4d_wlimits_add <limit> <weapon1> <weapon2> ... <weaponN>");
		return Plugin_Handled;
	}

	decl String:sTempBuff[MAX_WEAPON_NAME_LENGTH];
	GetCmdArg(1, sTempBuff, sizeof(sTempBuff));

	new newEntry[LimitArrayEntry];
	decl WeaponId:wepid;
	newEntry[LAE_iLimit] = StringToInt(sTempBuff);

	for (new i = 2; i <= args; ++i)
	{
		GetCmdArg(i, sTempBuff, sizeof(sTempBuff));
		wepid = WeaponNameToId(sTempBuff);
		newEntry[LAE_WeaponArray][_:wepid/32] |= (1 << (_:wepid % 32));
	}
	PushArrayArray(hLimitArray, newEntry[0]);
	return Plugin_Handled;
}

public Action:LockLimits_Cmd(args)
{
	if (bIsLocked)
	{
		PrintToServer("Weapon limits already locked");
	}
	else
	{
		bIsLocked = true;
	}
}

public Action:ClearLimits_Cmd(args)
{
	if (bIsLocked)
	{
		bIsLocked = false;
		PrintToChatAll("[L4D Weapon Limits] Weapon limits cleared!");
		ClearLimits();
	}
}

public Action:WeaponCanUse(client, weapon)
{
	if (GetClientTeam(client) != 2 || !bIsLocked) return Plugin_Continue;
	new WeaponId:wepid = IdentifyWeapon(weapon);

	decl arrayEntry[LimitArrayEntry];
	new size = GetArraySize(hLimitArray);
	for (new i = 0; i < size; ++i)
	{
		GetArrayArray(hLimitArray, i, arrayEntry[0]);
		if (arrayEntry[LAE_WeaponArray][_:wepid/32] & (1 << (_:wepid % 32)) && GetWeaponCount(arrayEntry[LAE_WeaponArray]) >= arrayEntry[LAE_iLimit])
		{
			new wep_slot = GetSlotFromWeaponId(wepid);
			new player_weapon = GetPlayerWeaponSlot(client, _:wep_slot);
			new WeaponId:player_wepid = IdentifyWeapon(player_weapon); 
			if (!player_wepid || wepid == player_wepid || !(arrayEntry[LAE_WeaponArray][_:player_wepid/32] & (1 << (_:player_wepid % 32))))
			{
				if (wep_slot == 0) GiveDefaultAmmo(client);
				if (player_wepid) PrintToChat(client, "[Weapon Limits] This weapon group has reached its max of %d", arrayEntry[LAE_iLimit]);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}


stock GetWeaponCount(const mask[])
{
	new count;
	decl WeaponId:wepid, j;
	for (new i = 1; i < MaxClients + 1; ++i)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			for (j = 0; j < 5; ++j)
			{
				wepid = IdentifyWeapon(GetPlayerWeaponSlot(i, j));
				if (mask[_:wepid/32] & (1 << (_:wepid % 32)))
				{
					++count;
				}
			}
		}
	}
	return count;
}

stock ClearLimits()
{
	if (hLimitArray != INVALID_HANDLE)
		ClearArray(hLimitArray);
}

stock CloseLimits()
{
	if (hLimitArray != INVALID_HANDLE)
		CloseHandle(hLimitArray)
}

stock GiveDefaultAmmo(client)
{
	if (iAmmoPile != -1) 
		SDKCall(hSDKGiveDefaultAmmo, iAmmoPile, client);
}

stock FindAmmoSpawn()
{
	new psychonic = GetEntityCount();
	decl String:classname[64];
	for (new i = MaxClients; i < psychonic; ++i)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, classname, sizeof(classname));
			if (StrEqual(classname, "weapon_ammo_spawn"))
			{
				return i;
			}
		}
	}
	//We have to make an ammo pile!
	return MakeAmmoPile();
}

stock MakeAmmoPile()
{
	new ammo = CreateEntityByName("weapon_ammo_spawn");
	DispatchSpawn(ammo);
	LogMessage("No ammo pile found, creating one: %d", iAmmoPile);
	return ammo;
}

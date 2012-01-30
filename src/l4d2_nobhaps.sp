#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "Simple Anti-Bunnyhop",
	author = "CanadaRox, ProdigySim, blodia",
	description = "Stops bunnyhops by restricting speed when a player lands on the ground to their MaxSpeed",
	version = "0.1",
	url = "https://bitbucket.org/CanadaRox/random-sourcemod-stuff/"
};


#define DEBUG 0

#define L4DBUILD 1

new Handle:hCvarEnable;
#if defined(L4DBUILD)
new Handle:hCvarSIExcept;
#endif

public OnPluginStart()
{
	hCvarEnable = CreateConVar("simple_antibhop_enable", "1", "Enable or disable the Simple Anti-Bhop plugin", FCVAR_PLUGIN);
#if defined(L4DBUILD)
	hCvarSIExcept = CreateConVar("bhop_except_si_flags", "0", 
		"Bitfield for exempting SI in anti-bhop functionality. From least significant: Smoker, Boomer, Hunter, Spitter, Jockey, Charger, Tank", FCVAR_PLUGIN);
#endif

}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	static Float:LeftGroundMaxSpeed[MAXPLAYERS + 1];
	
	if(!GetConVarBool(hCvarEnable)) return Plugin_Continue;
	
	if (IsPlayerAlive(client))
	{
		#if defined(L4DBUILD)
		if(GetClientTeam(client) == 3)
		{
			new class = GetEntProp(client, Prop_Send, "m_zombieClass");
			if(class == 8) // tank
			{
				--class;
			}
			class--;
			new except = GetConVarInt(hCvarSIExcept);
			if(class >=0 && class <=6 && ((1 << class) & except))
			{
				// Skipping calculation for This SI based on exception rules
				return Plugin_Continue;
			}
		}
		#endif
		
		new ClientFlags = GetEntityFlags(client);
		if (ClientFlags & FL_ONGROUND)
		{
			if (LeftGroundMaxSpeed[client] != -1.0)
			{
				
				new Float:CurVelVec[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", CurVelVec);
				
				if (GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[client])
				{
					#if DEBUG
					PrintToChat(client, "Speed: %f {%.02f, %.02f, %.02f}, MaxSpeed: %f", GetVectorLength(CurVelVec), CurVelVec[0], CurVelVec[1], CurVelVec[2], LeftGroundMaxSpeed[client]);
					#endif
					NormalizeVector(CurVelVec, CurVelVec);
					ScaleVector(CurVelVec, LeftGroundMaxSpeed[client]);
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, CurVelVec);
				}
				LeftGroundMaxSpeed[client] = -1.0;
			}
		}
		else if(LeftGroundMaxSpeed[client] == -1.0)
		{
			LeftGroundMaxSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
		}
	}
	
	return Plugin_Continue;
}  
/**
 * vim: set ts=4 :
 * =============================================================================
 * Left 4 Downtown 2 SourceMod Extension
 * Copyright (C) 2010 Michael "ProdigySim" Busby
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */
 
 #if defined _l4d2director_included
  #endinput
#endif
#define _l4d2director_included

/**
 * @brief Gets the number of tanks currently in play.
 * @remarks This value is tracked by the director, and should be a good 
 *		indicator that a tank is in play
 * 
 * @return 	current tank count
 */
native L4D2_GetTankCount();

/**
 * @brief Gets the campaign scores stored in the Versus Director
 * @remarks These are the actual values used for campaign scores--not proxies
 * 
 * @param scores 		Array to store the campaign scores in
 * @noreturn 				
 */
native L4D2_GetVersusCampaignScores(scores[2]);

/**
 * @brief Sets the campaign scores stored in the Versus Director
 * @remarks These are the actual values used for campaign scores--not proxies
 * 
 * @param scores 		Array of campaign scores to set the director's values to.
 * @noreturn 				
 */
native L4D2_SetVersusCampaignScores(const scores[2]);

/**
 * @brief Gets the flow percent for tank spawns for both versus rounds.
 * @remarks These values are checked against as the survivors move through the
 *		map. Once they are passed, the tank spawns. Note that this is flow
 *		as a percent of the map's flow, not flow distance.
 * 
 * @param tankFlows	Array to store the Tank Spawn Flow percents in
 * @noreturn 				
 */
native L4D2_GetVersusTankFlowPercent(Float:tankFlows[2]);

/**
 * @brief Sets the flow percent for tank spawns for both versus rounds.
 * @remarks These values are checked against as the survivors move through the
 *		map. Once they are passed, the tank spawns. Note that this is flow
 *		as a percent of the map's flow, not flow distance.
 * 
 * @param tankFlows	Array of Tank Spawn Flow percents to store in director
 * @noreturn 				
 */
native L4D2_SetVersusTankFlowPercent(const Float:tankFlows[2]);

enum DirectorType {
	// Base director class
	DT_CDirector,
	// Director class with versus-related vars
	DT_CDirectorVersusMode,
	// Scavenge Director
	DT_CDirectorScavengeMode,
};

/**
 * @brief Retrieves an integer value from the Director based on the offset given
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to read from
 * @param offset		Offset to read from.
 * @return				Integer value at the given property offset.
 * @error				Not supported or Director unavailable.
 */
native L4D2_Director_GetDataInt(DirectorType:director, offset);

/**
 * @brief Retrieves a floating point value from the Director based on the offset given
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to read from
 * @param offset		Offset to read from.
 * @return				Floating point value at the given property offset.
 * @error				Not supported or Director unavailable.
 */
native Float:L4D2_Director_GetDataFloat(DirectorType:director, offset);

/**
 * @brief Retrieves a boolean value from the Director based on the offset given
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to read from
 * @param offset		Offset to read from.
 * @return				Boolean value at the given property offset.
 * @error				Not supported or Director unavailable.
 */
native bool:L4D2_Director_GetDataBool(DirectorType:director, offset);

/**
 * @brief Sets an integer value in the Director based on the offset given
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to read from
 * @param offset		Offset to write to.
 * @param val			Value to write
 * @noreturn
 * @error				Not supported or Director unavailable.
 */
native L4D2_Director_SetDataInt(DirectorType:director, offset, any:val);

/**
 * @brief Sets a floating point value in the Director based on the offset given
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to read from
 * @param offset		Offset to write to.
 * @param val			Value to write
 * @noreturn
 * @error				Not supported or Director unavailable.
 */
native L4D2_Director_SetDataFloat(DirectorType:director, offset, Float:val);

/**
 * @brief Sets a boolean value in the Director based on the offset given
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to read from
 * @param offset		Offset to write to.
 * @param val			Value to write
 * @noreturn
 * @error				Not supported or Director unavailable.
 */
native L4D2_Director_SetDataBool(DirectorType:director, offset, bool:val);

/**
 * @brief Find the offset of a given variable in the given director
 * @remarks Names are unofficial, and could change in different versions of Left4Downtown2
 * @param director		Which Director structure to look up property in
 * @param prop			Property name.
 * @return				Offset into the specified director of the variable
 * @error				Property not supported
 */
native L4D2_Director_GetVariableOffset(DirectorType:director, const String:prop[]);

/**
 * @brief Retrieves an integer variable from the Director based on the offset of the named variable
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to read from
 * @param prop			Property name.
 * @param element		Element # (starting from 0) if property is an array.
 * @return				Integer value at the given property offset.
 * @error				Not supported or Director unavailable.
 */
stock L4D2_Director_GetPropInt(DirectorType:director, const String:prop[], element=0)
{
	return L4D2_Director_GetDataInt(director, L4D2_Director_GetVariableOffset(director, prop)+element*4);
}

/**
 * @brief Retrieves a floating point variable from the Director based on the offset of the named variable
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to read from
 * @param prop			Property name.
 * @param element		Element # (starting from 0) if property is an array.
 * @return				Floating point value at the given property offset.
 * @error				Not supported or Director unavailable.
 */
stock Float:L4D2_Director_GetPropFloat(DirectorType:director, const String:prop[], element=0)
{
	return L4D2_Director_GetDataFloat(director, L4D2_Director_GetVariableOffset(director, prop)+element*4);
}

/**
 * @brief Retrieves a boolean variable from the Director based on the offset of the named variable
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to read from
 * @param prop			Property name.
 * @param element		Element # (starting from 0) if property is an array.
 * @return				Boolean value at the given property offset.
 * @error				Not supported or Director unavailable.
 */
stock bool:L4D2_Director_GetPropBool(DirectorType:director, const String:prop[], element=0)
{
	return L4D2_Director_GetDataBool(director, L4D2_Director_GetVariableOffset(director, prop)+element);
}

/**
 * @brief Sets an integer variable in the Director based on the offset of the named variable
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to write to
 * @param prop			Property name.
 * @param val			Value to write to the Director.
 * @param element		Element # (starting from 0) if property is an array.
 * @noreturn
 * @error				Not supported or Director unavailable.
 */
stock L4D2_Director_SetPropInt(DirectorType:director, const String:prop[], any:val, element=0)
{
	L4D2_Director_SetDataInt(director, L4D2_Director_GetVariableOffset(director, prop)+element*4, val);
}

/**
 * @brief Sets a floating point variable in the Director based on the offset of the named variable
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to write to
 * @param prop			Property name.
 * @param val			Value to write to the Director.
 * @param element		Element # (starting from 0) if property is an array.
 * @noreturn
 * @error				Not supported or Director unavailable.
 */
stock L4D2_Director_SetPropFloat(DirectorType:director, const String:prop[], Float:val, element=0)
{
	L4D2_Director_SetDataFloat(director, L4D2_Director_GetVariableOffset(director, prop)+element*4, val);
}

/**
 * @brief Sets a boolean variable in the Director based on the offset of the named variable
 * @remarks You'll have to do your own type and length checking here. No guarantees
 * @param director		Which Director structure to write to
 * @param prop			Property name.
 * @param val			Value to write to the Director.
 * @param element		Element # (starting from 0) if property is an array.
 * @noreturn
 * @error				Not supported or Director unavailable.
 */
stock L4D2_Director_SetPropBool(DirectorType:director, const String:prop[], bool:val, element=0)
{
	L4D2_Director_SetDataBool(director, L4D2_Director_GetVariableOffset(director, prop)+element, val);
}

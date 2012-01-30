#include <sourcemod> 
#include <adt_trie>

#if defined __l4d2_gamemodes_inc__
#endinput
#endif
#define __l4d2_gamemodes_inc__

// L4D2 Game modes

// Gamemode enumerations. These values are arbitrary.
enum L4D2GameMode
{
  L4D2GM_UNKNOWN = -1,
    L4D2GM_COOP =0,
    L4D2GM_REALISM,
    L4D2GM_SURVIVAL,
    L4D2GM_VERSUS,
    L4D2GM_SCAVENGE,
    L4D2GM_MUTATION1,
    L4D2GM_MUTATION2,
    L4D2GM_MUTATION3,
    L4D2GM_MUTATION4,
    L4D2GM_MUTATION5,
    L4D2GM_MUTATION6,
    L4D2GM_MUTATION7,
    L4D2GM_MUTATION8,
    L4D2GM_MUTATION9,
    L4D2GM_MUTATION10,
    L4D2GM_MUTATION11,
    L4D2GM_MUTATION12,
    L4D2GM_MUTATION13,
    L4D2GM_MUTATION14,
    L4D2GM_MUTATION15,
    L4D2GM_MUTATION16,
    L4D2GM_MUTATION17,
    L4D2GM_MUTATION18,
    L4D2GM_MUTATION19,
    L4D2GM_MUTATION20,
    L4D2GM_COMMUNITY1,
    L4D2GM_COMMUNITY2,
    L4D2GM_COMMUNITY3,
    L4D2GM_COMMUNITY4,
    L4D2GM_COMMUNITY5,
	// Don't add after here
	L4D2GameModesCount
};

// Names of the gamemodes, as seen in gamemodes.txt
new const String:g_sL4D2_GameModeStrings[L4D2GameModesCount][] = {
  "coop",  "realism",  "survival",
  "versus",  "scavenge",  "mutation1",
  "mutation2",  "mutation3",  "mutation4",
  "mutation5",  "mutation6",  "mutation7",
  "mutation8",  "mutation9",  "mutation10",
  "mutation11",  "mutation12",  "mutation13",
  "mutation14",  "mutation15",  "mutation16",
  "mutation17",  "mutation18",  "mutation19",
  "mutation20",  "community1",  "community2",
  "community3",  "community4",  "community5"
};

// Base gamemodes for each gamemode, as seen in gamemodes.txt
new const L4D2GameMode:g_iL4D2_BaseGameModes[L4D2GameModesCount] = {
    L4D2GM_COOP, L4D2GM_REALISM, L4D2GM_SURVIVAL,   // coop, realism, survival
    L4D2GM_VERSUS, L4D2GM_SCAVENGE, L4D2GM_COOP,    // versus scavenge mutation1
    L4D2GM_COOP, L4D2GM_COOP, L4D2GM_COOP,          // mutation 2-4
    L4D2GM_COOP, L4D2GM_UNKNOWN, L4D2GM_COOP,       // mutation 5-7
    L4D2GM_COOP, L4D2GM_COOP, L4D2GM_COOP,          // mutation 8-10
    L4D2GM_VERSUS, L4D2GM_VERSUS, L4D2GM_SCAVENGE,  // mutation 11-13
    L4D2GM_COOP, L4D2GM_SURVIVAL, L4D2GM_COOP,      // mutation 14-16
    L4D2GM_COOP, L4D2GM_VERSUS, L4D2GM_VERSUS,      // mutation 17-19
    L4D2GM_COOP, L4D2GM_COOP, L4D2GM_COOP,          // mutation20, community1-2
    L4D2GM_VERSUS, L4D2GM_SURVIVAL, L4D2GM_COOP     // community3-5
};

static Handle:game_modes_trie;

/**
 * Initializes internal structure necessary for gamemodes.inc functions
 * @remark It is recommended that you run this function on plugin start, but not necessary
 *
 * @noreturn
 */
stock InitializeGameModesTrie()
{
    if(game_modes_trie != INVALID_HANDLE) 
	CloseHandle(game_modes_trie);
    
    game_modes_trie = CreateTrie();
    for(new i = 0; i < _:L4D2GameModesCount; i++)
    {
		SetTrieValue(game_modes_trie, g_sL4D2_GameModeStrings[i], i);
    }
}


/**
 * Gets the base gamemode of the given gamemode.
 * @remark Good for finding if a mutation is coop/versus/scavenge/survival
 *
 * @param gamemode	Gamemode to lookup base gamemode of
 * @return L4D2GameMode index of the base gamemode of the given gamemode
 */
stock L4D2GameMode:GetBaseGameMode(L4D2GameMode:gamemode)
{
    if(IsValidGameMode(gamemode))
        return g_iL4D2_BaseGameModes[gamemode];
    return L4D2GM_UNKNOWN;
}


/**
 * Performs bounds checking to determine if a gamemode ID is known/valid
 * @remark Simple check to see if gamemode is valid/known
 *
 * @param gamemode	L4D2GameMode to check for validity
 * @return True if gamemode is valid, false otherwise.
 */
stock bool:IsValidGameMode(L4D2GameMode:gamemode)
{
    return gamemode > L4D2GM_UNKNOWN && gamemode < L4D2GameModesCount;
}


/**
 * Tries to look up a L4D2Gamemode for a given Gamemode Name.
 *
 * @param gamemode 	Name of the gamemode to look up
 * @return			The corresponding L4D2GameMode if found, else L4D2GM_UNKNOWN
 */
stock L4D2GameMode:GameModeStringToId(const String:gamemode[])
{
    if(game_modes_trie == INVALID_HANDLE)
	InitializeGameModesTrie();
    new L4D2GameMode:gm;
    if(GetTrieValue(game_modes_trie, gamemode, gm))
    {
	return L4D2GameMode:gm;
    }
    return L4D2GM_UNKNOWN;
}

/**
 * Tries to look up the base L4D2Gamemode for a given Gamemode Name.
 * @remark This is the same as looking up the GameModeId, then doing GetBaseGameMode
 *
 * @param gamemode 	Name of the gamemode to look up
 * @return			The corresponding base L4D2GameMode if found, else L4D2GM_UNKNOWN
 */
stock L4D2GameMode:FindBaseGameMode(const String:gamemode[])
{
    return GetBaseGameMode(GameModeStringToId(gamemode));
}

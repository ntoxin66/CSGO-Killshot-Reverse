/**
 * =============================================================================
 * Killshot Reverse for SourceMod (C)2018 Matthew J Dunn.   All rights reserved.
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
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#pragma newdecls required
#pragma semicolon 1

#define DMG_HEADSHOT (1 << 30)
#define VERSION "2.0.1"

ConVar hEnabled = null;
ConVar hDamageRatio = null;
ConVar hDisableAllDamage = null;
ConVar hDisableFallDamage = null;
ConVar hFriendlyFire = null;
ConVar hReverseAllDamage = null;
ConVar hDisableKnifeDamage = null;
ConVar hRoundDisableTimer = null;
ConVar hBlockVictimDamage = null;
ConVar hBlockKillShotOnly = null;
ConVar hDebugMessages = null;

bool SuicidingPlayers[MAXPLAYERS + 1];
float g_fRoundStartTime = 0.0;

public Plugin myinfo =
{
	name = "Killshot Reverse",
	author = "Neuro Toxin",
	description = "Reverses damage from friendly killshots and more.",
	version = VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=237011",
}

public void OnPluginStart()
{
	LoadTranslations("killshotreverse.phrases.txt");
	CreateConvarAll();
	HookClientAll();
	HookEvent("round_start", OnRoundStart, EventHookMode_Pre);
}

public void OnPluginEnd()
{
	UnhookClientAll();
	UnhookEvent("round_start", OnRoundStart, EventHookMode_Pre);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	SuicidingPlayers[client] = false;
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}

public void CreateConvarAll()
{
	hEnabled = CreateConVar("killshotreverse_enable", "1", "Enable/Disable the plugin from editing damage values.");
	hDamageRatio = CreateConVar("killshotreverse_dmgratio", "0.25", "The ratio of damage to apply back to the attacker.", _, true, 0.1, true, 4.0);
	hDisableAllDamage = CreateConVar("killshotreverse_disablealldamage", "0", "Disable all damage between all players.");
	hDisableFallDamage = CreateConVar("killshotreverse_disablefalldamage", "0", "Disables fall damage for players.");
	hReverseAllDamage = CreateConVar("killshotreverse_reversealldamage", "0", "Reverses all damage to attacking player.");
	hDisableKnifeDamage = CreateConVar("killshotreverse_disableknifedamage", "1", "Disabled friendly fire for knife damage.");
	hRoundDisableTimer = CreateConVar("killshotreverse_rounddisabletimer", "20.0", "Disable friendly fire for the first x seconds of each round.");
	hBlockVictimDamage = CreateConVar("killshotreverse_blockvictimdamage", "1", "Victims wont receive damage from friendly fire killshots.");
	hBlockKillShotOnly = CreateConVar("killshotreverse_blockkillshotsonly", "1", "Allows all friendly fire damage to be reversed.");
	hDebugMessages = CreateConVar("killshotreverse_debugmessages", "0", "Prints debug messages to client consoles.");
	hFriendlyFire = FindConVar("mp_friendlyfire");
	
	ConVar hVersion = CreateConVar("sm_killshotreverse_version", VERSION);
	hVersion.Flags |= FCVAR_NOTIFY;
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (hRoundDisableTimer.FloatValue > 0.0)
		g_fRoundStartTime = GetGameTime();
		
	for (int client = 1; client < MAXPLAYERS; client++)
		SuicidingPlayers[client] = false;	
}

public void HookClientAll()
{
	for (int client = 1; client < MAXPLAYERS; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
		SuicidingPlayers[client] = false;
	}
}

public void UnhookClientAll()
{
	for (int client = 1; client < MAXPLAYERS; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	}
}

// need to optimise hDebugMessages.BoolValue checks
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!hEnabled.BoolValue)
		return Plugin_Continue;
		
	if (hDebugMessages.BoolValue)
		PrintToConsoleAll("KSR: OnTakeDamage(int victim=%d, int &attacker=%d, int &inflictor=%d, float &damage=%f, int &damagetype=%d)", victim, attacker, inflictor, damage, damagetype);
		
	if (damagetype & DMG_FALL)
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> (damagetype & DMG_FALL) == true");
			
		if (hDisableFallDamage.BoolValue)
		{
			if (hDebugMessages.BoolValue)
				PrintToConsoleAll("> return Plugin_Handled");
				
			return Plugin_Handled;
		}
		else
		{
			if (hDebugMessages.BoolValue)
				PrintToConsoleAll("> return Plugin_Continue");
				
			return Plugin_Continue;
		}
	}
	
	if (hDisableAllDamage.BoolValue)
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> hDisableAllDamage.BoolValue == true");
			
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Handled");
			
		return Plugin_Handled;
	}
		
	if (!hFriendlyFire.BoolValue)
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> hFriendlyFire.BoolValue == false");
			
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Continue");
			
		return Plugin_Continue;
	}
		
	if (attacker < 1 || attacker >= MaxClients)
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> Invalid &attacker: (attacker < 1 || attacker >= MaxClients) == true");
			
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Continue");
			
		return Plugin_Continue;
	}
		
	if (!IsClientInGame(attacker))
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> Invalid &attacker: IsClientInGame(attacker) == false");
			
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Handled");
			
		return Plugin_Handled;
	}
		
	if (!IsPlayerAlive(attacker))
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> Invalid &attacker: IsPlayerAlive(attacker) == false");
			
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Handled");
			
		// this should probably be Plugin_Continue;
		return Plugin_Handled;
	}
		
	if (GetClientTeam(attacker) != GetClientTeam(victim))
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> GetClientTeam(attacker) != GetClientTeam(victim)");
		
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Continue");
			
		return Plugin_Continue;
	}
		
	if (hRoundDisableTimer.FloatValue > 0.0 && GetGameTime() < (g_fRoundStartTime + hRoundDisableTimer.FloatValue))
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> (hRoundDisableTimer.FloatValue > 0.0 && GetGameTime() < (g_fRoundStartTime + hRoundDisableTimer.FloatValue)) == true");
			
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Handled");
			
		return Plugin_Handled;
	}
		
	if ((damagetype & DMG_SLASH) && hDisableKnifeDamage.BoolValue)
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> ((damagetype & DMG_SLASH) && hDisableKnifeDamage.BoolValue) == true");
			
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Handled");
			
		return Plugin_Handled;
	}
		
	char attackername[128]; GetClientName(attacker, attackername, sizeof(attackername));
	char victimname[128]; GetClientName(victim, victimname, sizeof(victimname));
	
	// Skip when not reversing all damage and damage type is headshot
	if (!hReverseAllDamage.BoolValue && !(damagetype & DMG_HEADSHOT))
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> (!hReverseAllDamage.BoolValue && !(damagetype & DMG_HEADSHOT)) == true");
			
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Continue");
			
		return Plugin_Continue;
	}
	
	PrintToConsoleAll("%t", "TeamDamage", attackername, victimname);
	
	// Skip if processing killshots only and this is not a killshot
	int health = GetClientHealth(victim);
	if (hBlockKillShotOnly.BoolValue && health > damage)
	{
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> (hBlockKillShotOnly.BoolValue && health > damage) == true");
			
		if (hDebugMessages.BoolValue)
			PrintToConsoleAll("> return Plugin_Continue");
			
		return Plugin_Continue;
	}
			
	float attackershealth = float(GetClientHealth(attacker));
	float reduceddamage = damage * hDamageRatio.FloatValue;
	float newhealth = attackershealth - reduceddamage;
	
	// Adjust attacker damage
	if (newhealth <= 0.0)
	{
		if (KillPlayer(attacker))
		{
			PrintToChatAll("%t", "Suicide", attackername, victimname);
			PrintToConsoleAll("%t", "Suicide", attackername, victimname);
			PrintToServer("%t", "Suicide", attackername, victimname);
		}
		
		if (hBlockVictimDamage.BoolValue)
			return Plugin_Handled;
		else
			return Plugin_Continue;
	}
	else
		SetEntityHealth(attacker, RoundFloat(newhealth));
		
	if (hBlockVictimDamage.BoolValue)
		return Plugin_Handled;
	else
		return Plugin_Continue;
}

stock bool KillPlayer(int client)
{
	if (SuicidingPlayers[client])
		return false;
		
	SuicidingPlayers[client] = true;
	RequestFrame(KillPlayerPost, GetClientUserId(client));
	return true;
}

public void KillPlayerPost(any userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0)
		return;
		
	if (!SuicidingPlayers[client])
		return;
		
	SuicidingPlayers[client] = false;
	ForcePlayerSuicide(client);
}

stock void PrintToConsoleAll(const char[] format, any ...)
{
	char output[512];
	VFormat(output, 256, format, 2);
	for (int client = 1; client < MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		if (IsFakeClient(client))
			continue;
			
		PrintToConsole(client, output);
	}
}
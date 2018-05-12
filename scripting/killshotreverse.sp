#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#pragma newdecls required
#pragma semicolon 1

Handle hEnabled = null;
Handle hDamageRatio = null;
Handle hDisableAllDamage = null;
Handle hDisableFallDamage = null;
Handle hFriendlyFire = null;
Handle hReverseAllDamage = null;
Handle hDisableKnifeDamage = null;
Handle hRoundDisableTimer = null;

bool Enabled = true;
float DamageRatio = 0.25;
bool DisableAllDamage = false;
bool SuicidingPlayers[MAXPLAYERS + 1];
bool DisableFallDamage = false;
bool FriendlyFire = true;
bool ReverseAllDamage = false;
bool DisableKnifeDamage = true;
float RoundDisableTimer = 20.0;

float g_fRoundStartTime = 0.0;

public Plugin myinfo =
{
	name = "Killshot Reverse",
	author = "Neuro Toxin",
	description = "Reverses damage from friendly killshots and more.",
	version = "1.5.1",
	url = "https://forums.alliedmods.net/showthread.php?t=237011",
}

public void OnPluginStart()
{
	LoadTranslations("killshotreverse.phrases.txt");
	CreateConvarAll();
	HookEvent("round_start", OnRoundStart, EventHookMode_Pre);
}

public void OnPluginEnd()
{
	if (Enabled)
		UnhookClientAll();
		
	RemoveConvarHooks();
	UnhookEvent("round_start", OnRoundStart, EventHookMode_Pre);
}

public void OnConfigsExecuted()
{
	GetConvarAll();
	
	if (Enabled)
		HookClientAll();
}

public void CreateConvarAll()
{
	hEnabled = CreateConVar("killshotreverse_enable", "1", "Enables applying killshot damage to the attacker.");
	hDamageRatio = CreateConVar("killshotreverse_dmgratio", "0.25", "The ratio of damage to apply back to the attacker.", _, true, 0.1, true, 4.0);
	hDisableAllDamage = CreateConVar("killshotreverse_disablealldamage", "0", "Disable all damage between all players.");
	hDisableFallDamage = CreateConVar("killshotreverse_disablefalldamage", "0", "Disables fall damage for players.");
	hReverseAllDamage = CreateConVar("killshotreverse_reversealldamage", "0", "Reverses all damage to attacking player.");
	hDisableKnifeDamage = CreateConVar("killshotreverse_disableknifedamage", "1", "Disabled friendly fire for knife damage.");
	hRoundDisableTimer = CreateConVar("killshotreverse_rounddisabletimer", "20.0", "Disable friendly fire for the first x seconds of each round.");
	hFriendlyFire = FindConVar("mp_friendlyfire");
	
	HookConVarChange(hEnabled, OnCvarChanged);
	HookConVarChange(hDamageRatio, OnCvarChanged);
	HookConVarChange(hDisableAllDamage, OnCvarChanged);
	HookConVarChange(hDisableFallDamage, OnCvarChanged);
	HookConVarChange(hReverseAllDamage, OnCvarChanged);
	HookConVarChange(hDisableKnifeDamage, OnCvarChanged);
	HookConVarChange(hRoundDisableTimer, OnCvarChanged);
	HookConVarChange(hFriendlyFire, OnCvarChanged);
	
	Handle hVersion = CreateConVar("sm_killshotreverse_version", "1.6.0");
	int flags = GetConVarFlags(hVersion);
	flags |= FCVAR_NOTIFY;
	SetConVarFlags(hVersion, flags);
}

public void RemoveConvarHooks()
{
	UnhookConVarChange(hEnabled, OnCvarChanged);
	UnhookConVarChange(hDamageRatio, OnCvarChanged);
	UnhookConVarChange(hDisableAllDamage, OnCvarChanged);
	UnhookConVarChange(hDisableFallDamage, OnCvarChanged);
	UnhookConVarChange(hDisableKnifeDamage, OnCvarChanged);
	UnhookConVarChange(hRoundDisableTimer, OnCvarChanged);
	UnhookConVarChange(hFriendlyFire, OnCvarChanged);
}

public void GetConvarAll()
{
	Enabled = GetConVarBool(hEnabled);
	DamageRatio = GetConVarFloat(hDamageRatio);
	DisableAllDamage = GetConVarBool(hDisableAllDamage);
	DisableFallDamage = GetConVarBool(hDisableFallDamage);
	FriendlyFire = GetConVarBool(hFriendlyFire);
	ReverseAllDamage = GetConVarBool(hReverseAllDamage);
	DisableKnifeDamage = GetConVarBool(hDisableKnifeDamage);
	RoundDisableTimer = GetConVarFloat(hRoundDisableTimer);
}

public void OnCvarChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	if (cvar == hEnabled)
	{
		bool value = !StrEqual(newVal, "0");
		if (value == Enabled)
			return;
			
		if (value)
			HookClientAll();
		else
			UnhookClientAll();
		
		Enabled = value;
	}
	else if (cvar == hDamageRatio)
		DamageRatio = StringToFloat(newVal);
	else if (cvar == hDisableAllDamage)
		DisableAllDamage = StringToInt(newVal) == 0 ? false : true;
	else if (cvar == hDisableFallDamage)
		DisableFallDamage = StringToInt(newVal) == 0 ? false : true;
	else if (cvar == hFriendlyFire)
		FriendlyFire = StringToInt(newVal) == 0 ? false : true;
	else if (cvar == hReverseAllDamage)
		ReverseAllDamage = StringToInt(newVal) == 0 ? false : true;
	else if (cvar == hDisableKnifeDamage)
		DisableKnifeDamage = StringToInt(newVal) == 0 ? false : true;
	else if (cvar == hRoundDisableTimer)
		RoundDisableTimer = StringToFloat(newVal);
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (RoundDisableTimer > 0.0)
		g_fRoundStartTime = GetGameTime() + RoundDisableTimer;
	for (int client = 1; client < MAXPLAYERS; client++)
	{
		SuicidingPlayers[client] = false;	
	}
}

public void OnClientPutInServer(int client)
{
	if (!Enabled)
		return;

	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	SuicidingPlayers[client] = false;
}

public void OnClientDisconnect(int client)
{
	if (!Enabled)
		return;

	SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
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

#define DMG_HEADSHOT (1 << 30)

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damagetype == 32 && DisableFallDamage)
	{
		if (DisableFallDamage)
			return Plugin_Handled;
		else
			return Plugin_Continue;
	}
	
	if (attacker < 1 || attacker >= MaxClients)
		return Plugin_Continue;
		
	if (!IsClientInGame(attacker))
		return Plugin_Handled;

	if (!IsPlayerAlive(attacker))
		return Plugin_Handled;
		
	if (DisableAllDamage)
		return Plugin_Handled;
		
	if (!FriendlyFire)
		return Plugin_Continue;

	int attackerteam = GetClientTeam(attacker);
	int victimteam = GetClientTeam(victim);

	if (victimteam != attackerteam)
		return Plugin_Continue;
		
	if (RoundDisableTimer > 0.0 && GetGameTime() < g_fRoundStartTime)
		return Plugin_Handled;
	
	if ((damagetype & DMG_SLASH) && DisableKnifeDamage)
		return Plugin_Handled;
		
	char attackername[128]; GetClientName(attacker, attackername, sizeof(attackername));
	char victimname[128]; GetClientName(victim, victimname, sizeof(victimname));

	PrintToConsoleAll("%t", "TeamDamage", attackername, victimname);
	//PrintToConsoleAll("[SM] OnTakeDamage(victim=%d, &attacker=%d, &inflictor=%d, &Float:damage=%f, &damagetype=%d)", victim, attacker, inflictor, damage, damagetype);

	int health = GetClientHealth(victim);
	if (!ReverseAllDamage)
		if (health > damage && !(damagetype & DMG_HEADSHOT))
			return Plugin_Continue;

	float attackershealth = float(GetClientHealth(attacker));
	float reduceddamage = damage * DamageRatio;
	float newhealth = attackershealth - reduceddamage;

	if (newhealth <= 0.0)
	{
		if (KillPlayer(attacker))
		{
			PrintToChatAll("%t", "Suicide", attackername, victimname);
			PrintToConsoleAll("%t", "Suicide", attackername, victimname);
			PrintToServer("%t", "Suicide", attackername, victimname);
		}
		return Plugin_Handled;
	}
	else
		SetEntityHealth(attacker, RoundFloat(newhealth));
	
	return Plugin_Handled;
}

stock bool KillPlayer(int client)
{
	if (SuicidingPlayers[client])
		return false;
	
	SuicidingPlayers[client] = true;
	CreateTimer(0.1, KillPlayerPost, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	return true;
}

public Action KillPlayerPost(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (client == 0) // || !IsClientInGame(client))
	{
		PrintToConsoleAll("[SM] --> NotValidClient");
		return Plugin_Handled;
	}
		
	if (!SuicidingPlayers[client])
	{
		return Plugin_Handled;
	}
		
	SuicidingPlayers[client] = false;
	ForcePlayerSuicide(client);
	return Plugin_Handled;
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
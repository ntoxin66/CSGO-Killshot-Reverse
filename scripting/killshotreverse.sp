#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>

new Handle:hEnabled = INVALID_HANDLE;
new Handle:hDamageRatio = INVALID_HANDLE;
new Handle:hDisableAllDamage = INVALID_HANDLE;
new Handle:hDisableFallDamage = INVALID_HANDLE;
new Handle:hFriendlyFire = INVALID_HANDLE;
new Handle:hReverseAllDamage = INVALID_HANDLE;
new Handle:hDisableKnifeDamage = INVALID_HANDLE;
new Handle:hRoundDisableTimer = INVALID_HANDLE;

new bool:Enabled = true;
new Float:DamageRatio = 0.25;
new bool:DisableAllDamage = false;
new bool:SuicidingPlayers[MAXPLAYERS + 1];
new bool:DisableFallDamage = false;
new bool:FriendlyFire = true;
new bool:ReverseAllDamage = false;
new bool:DisableKnifeDamage = true;
new Float:RoundDisableTimer = 20.0;

new Float:g_fRoundStartTime = 0.0;

public Plugin:myinfo =
{
	name = "Killshot Reverse",
	author = "Neuro Toxin",
	description = "Reverses damage from friendly killshots and more.",
	version = "1.5.1",
	url = "https://forums.alliedmods.net/showthread.php?t=237011",
}

public OnPluginStart()
{
	LoadTranslations("killshotreverse.phrases.txt");
	CreateConvarAll();
	HookEvent("round_start", OnRoundStart, EventHookMode_Pre);
}

public OnPluginEnd()
{
	if (Enabled)
		UnhookClientAll();
		
	RemoveConvarHooks();
	UnhookEvent("round_start", OnRoundStart, EventHookMode_Pre);
}

public OnConfigsExecuted()
{
	GetConvarAll();
	
	if (Enabled)
		HookClientAll();
}

public CreateConvarAll()
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
	
	new Handle:hVersion = CreateConVar("sm_killshotreverse_version", "1.6.0");
	new flags = GetConVarFlags(hVersion);
	flags |= FCVAR_NOTIFY;
	SetConVarFlags(hVersion, flags);
}

public RemoveConvarHooks()
{
	UnhookConVarChange(hEnabled, OnCvarChanged);
	UnhookConVarChange(hDamageRatio, OnCvarChanged);
	UnhookConVarChange(hDisableAllDamage, OnCvarChanged);
	UnhookConVarChange(hDisableFallDamage, OnCvarChanged);
	UnhookConVarChange(hDisableKnifeDamage, OnCvarChanged);
	UnhookConVarChange(hRoundDisableTimer, OnCvarChanged);
	UnhookConVarChange(hFriendlyFire, OnCvarChanged);
}

public GetConvarAll()
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

public OnCvarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if (cvar == hEnabled)
	{
		new bool:value = !StrEqual(newVal, "0");
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

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (RoundDisableTimer > 0.0)
		g_fRoundStartTime = GetGameTime() + RoundDisableTimer;
	for (new client = 1; client < MAXPLAYERS; client++)
	{
		SuicidingPlayers[client] = false;	
	}
}

public OnClientPutInServer(client)
{
	if (!Enabled)
		return;

	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	SuicidingPlayers[client] = false;
}

public OnClientDisconnect(client)
{
	if (!Enabled)
		return;

	SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}

public HookClientAll()
{
	for (new client = 1; client < MAXPLAYERS; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
		SuicidingPlayers[client] = false;
	}
}

public UnhookClientAll()
{
	for (new client = 1; client < MAXPLAYERS; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	}
}

#define DMG_HEADSHOT (1 << 30)

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
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

	new attackerteam = GetClientTeam(attacker);
	new victimteam = GetClientTeam(victim);

	if (victimteam != attackerteam)
		return Plugin_Continue;
		
	if (RoundDisableTimer > 0.0 && GetGameTime() < g_fRoundStartTime)
		return Plugin_Handled;
	
	if ((damagetype & DMG_SLASH) && DisableKnifeDamage)
		return Plugin_Handled;
		
	new String:attackername[128]; GetClientName(attacker, attackername, sizeof(attackername));
	new String:victimname[128]; GetClientName(victim, victimname, sizeof(victimname));

	PrintToConsoleAll("%t", "TeamDamage", attackername, victimname);
	//PrintToConsoleAll("[SM] OnTakeDamage(victim=%d, &attacker=%d, &inflictor=%d, &Float:damage=%f, &damagetype=%d)", victim, attacker, inflictor, damage, damagetype);

	new health = GetClientHealth(victim);
	if (!ReverseAllDamage)
		if (health > damage && !(damagetype & DMG_HEADSHOT))
			return Plugin_Continue;

	new Float:attackershealth = float(GetClientHealth(attacker));
	new Float:reduceddamage = damage * DamageRatio;
	new Float:newhealth = attackershealth - reduceddamage;

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

stock bool:KillPlayer(client)
{
	if (SuicidingPlayers[client])
		return false;
	
	SuicidingPlayers[client] = true;
	CreateTimer(0.1, KillPlayerPost, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	return true;
}

public Action:KillPlayerPost(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	
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

stock PrintToConsoleAll(const String:format[], any:...)
{
	new String:output[512];
	VFormat(output, 256, format, 2);
	for (new client = 1; client < MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (IsFakeClient(client))
			continue;
			
		PrintToConsole(client, output);
	}
}
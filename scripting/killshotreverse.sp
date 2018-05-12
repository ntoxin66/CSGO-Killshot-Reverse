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

new bool:Enabled = true;
new Float:DamageRatio = 0.25;
new bool:DisableAllDamage = false;
new bool:SuicidingPlayers[MAXPLAYERS + 1];
new bool:DisableFallDamage = false;
new bool:FriendlyFire = true;
new bool:ReverseAllDamage = false;

public Plugin:myinfo =
{
	name = "Killshot Reverse",
	author = "Neuro Toxin",
	description = "Reverses damage from friendly killshots and more.",
	version = "1.5",
	url = "https://forums.alliedmods.net/showthread.php?t=237011",
}

public OnPluginStart()
{
	LoadTranslations("killshotreverse.phrases.txt");
	CreateConvarAll();
	HookEvent("round_start", OnRoundStart, EventHookMode_Pre);
	
	if (Enabled)
		HookClientAll();
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
}

public CreateConvarAll()
{
	hEnabled = CreateConVar("killshotreverse_enable", "1", "Enables applying killshot damage to the attacker.");
	hDamageRatio = CreateConVar("killshotreverse_dmgratio", "0.25", "The ratio of damage to apply back to the attacker.", _, true, 0.1, true, 4.0);
	hDisableAllDamage = CreateConVar("killshotreverse_disablealldamage", "0", "Disable all damage between all players.");
	hDisableFallDamage = CreateConVar("killshotreverse_disablefalldamage", "0", "Disables fall damage for players.");
	hReverseAllDamage = CreateConVar("killshotreverse_reversealldamage", "0", "Reverses all damage to attacking player.");
	hFriendlyFire = FindConVar("mp_friendlyfire");
	
	HookConVarChange(hEnabled, OnCvarChanged);
	HookConVarChange(hDamageRatio, OnCvarChanged);
	HookConVarChange(hDisableAllDamage, OnCvarChanged);
	HookConVarChange(hDisableFallDamage, OnCvarChanged);
	HookConVarChange(hReverseAllDamage, OnCvarChanged);
	HookConVarChange(hFriendlyFire, OnCvarChanged);
	
	new Handle:hVersion = CreateConVar("sm_killshotreverse_version", "1.5");
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
}

public OnEnableChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	
	
	
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
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client < MAXPLAYERS; client++)
	{
		SuicidingPlayers[client] = false;	
	}
}

public OnClientPutInServer(client)
{
	if (!Enabled)
		return;

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SuicidingPlayers[client] = false;
}

public OnClientDisconnect(client)
{
	if (!Enabled)
		return;

	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public HookClientAll()
{
	for (new client = 1; client < MAXPLAYERS; client++)
	{
		if (!IsValidClient(client))
			continue;
		
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		SuicidingPlayers[client] = false;
	}
}

public UnhookClientAll()
{
	for (new client = 1; client < MAXPLAYERS; client++)
	{
		if (!IsValidClient(client))
			continue;
		
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (damagetype == 32 && DisableFallDamage)
	{
		if (DisableFallDamage)
			return Plugin_Handled;
		else
			return Plugin_Continue;
	}
	
	if (!IsValidClient(attacker))
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

	new String:attackername[128]; GetClientName(attacker, attackername, sizeof(attackername));
	new String:victimname[128]; GetClientName(victim, victimname, sizeof(victimname));

	PrintToConsoleAll("%t", "TeamDamage", attackername, victimname);

	new health = GetClientHealth(victim);
	
	if (!ReverseAllDamage)
		if (health > damage)
			return Plugin_Continue;

	new Float:attackershealth = float(GetClientHealth(attacker));
	new Float:reduceddamage = damage * DamageRatio;
	new newhealth = int:RoundToNearest(attackershealth - reduceddamage);
	
	if (newhealth <= 0)
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
		SetEntityHealth(attacker, newhealth);

	return Plugin_Handled;
}

stock bool:KillPlayer(client)
{
	if (SuicidingPlayers[client])
		return false;
		
	new userid = GetClientUserId(client);
	CreateTimer(0.1, KillPlayerPost, userid, TIMER_FLAG_NO_MAPCHANGE);
	SuicidingPlayers[client] = true;
	return true;
}

public Action:KillPlayerPost(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	
	if (IsValidClient(client))
		return Plugin_Handled;
		
	if (!SuicidingPlayers[client])
		return Plugin_Handled;
		
	SuicidingPlayers[client] = false;
	ForcePlayerSuicide(client);
	return Plugin_Handled;
}

stock PrintToConsoleAll(const String:format[], any:...)
{
	new String:output[512];
	VFormat(output, 256, format, 2);
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client))
			continue;
			
		if (IsFakeClient(client))
			continue;
			
		PrintToConsole(client, output);
	}
}

stock bool:IsValidClient(client)
{
	if (client < 1 || client > MaxClients)
		return false;
		
	if (!IsClientConnected(client))
		return false;
		
	if (!IsClientInGame(client))
		return false;

	return true;
}
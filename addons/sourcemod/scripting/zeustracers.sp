#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#define TASER "weapon_tracers_taser"
#define GLOW "weapon_taser_glow_impact"
//#define SPARK "weapon_taser_sparks"
#define SOUND_IMPACT "weapons/taser/taser_hit.wav"
#define SOUND_SHOOT "weapons/taser/taser_shoot.wav"

ConVar g_cEnabled;
bool g_bOverride[MAXPLAYERS + 1];
bool g_bZeus[MAXPLAYERS + 1];
bool g_bGlow[MAXPLAYERS + 1];
float g_fImpactSound[MAXPLAYERS + 1];
float g_fMuzzleSound[MAXPLAYERS + 1];
bool g_bAccess[MAXPLAYERS + 1];
float g_fLastAngles[MAXPLAYERS + 1][3];
ArrayList g_hArray;

public Plugin myinfo = 
{
	name = "[CS:GO] Zeus Tracers Bullets",
	author = "Tak (Chaosxk)",
	description = "Creates the zeus tracers effect on weapon fire.",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("sm_zeustracers_version", PLUGIN_VERSION, "Version for Zeus Tracers Bullets.", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_cEnabled = CreateConVar("sm_zeustracers_enabled", "1", "Enables/Disables this plugin.");
	
	RegAdminCmd("sm_zeustracers", Command_ZeusTracers, ADMFLAG_GENERIC, "Enables zeus tracers for every weapon on player.");
	
	AddTempEntHook("Shotgun Shot", Hook_BulletShot);
	HookEvent("bullet_impact", Event_BulletImpact);
	
	g_hArray = new ArrayList();
	AutoExecConfig(false, "zeustracers");
}

public void OnMapStart()
{
	PrecacheEffect("ParticleEffect");
	PrecacheParticleEffect(TASER);
	PrecacheParticleEffect(GLOW);
	//PrecacheParticleEffect(SPARK);
	PrecacheSound(SOUND_IMPACT);
	PrecacheSound(SOUND_SHOOT);
}

public void OnConfigsExecuted()
{
	SetupKVFiles();
	
	//Handles loading cache data when plugins get reloaded mid-game
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		OnClientPostAdminCheck(i);
		
		if (!IsPlayerAlive(i))
			continue;
			
		int weapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
		Hook_WeaponSwitch(i, weapon);
	}
}

public void OnClientPostAdminCheck(int client)
{
	g_bOverride[client] = false;
	SDKHook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponSwitch);
}

public Action Command_ZeusTracers(int client, int args)
{
	if (!g_cEnabled.BoolValue)
	{
		ReplyToCommand(client, "[SM] This plugin is disabled.");
		return Plugin_Handled;
	}
	
	if (args != 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_zeustracers <client> <1:ON | 0:OFF>");
		return Plugin_Handled;
	}
	
	char arg1[64], arg2[4];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	bool button = !!StringToInt(arg2);
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToCommand(client, "[SM] Can not find client.");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		if(1 <= target_list[i] <= MaxClients && IsClientInGame(target_list[i]))
		{
			g_bOverride[target_list[i]] = button;
		}
	}
	
	if (tn_is_ml)
		ShowActivity2(client, "[SM] ", "%N has %s %t zeus tracers.", client, button ? "given" : "removed", target_name);
	else
		ShowActivity2(client, "[SM] ", "%N has %s %s zeus tracers.", client, button ? "given" : "removed", target_name);
		
	return Plugin_Handled;
}

public void Hook_WeaponSwitch(int client, int weapon)
{
	if (weapon == -1)
		return;
		
	char buffer[32], weaponname[32];
	GetEntityClassname(weapon, weaponname, sizeof(weaponname));
	
	for (int i = 0; i < g_hArray.Length; i++)
	{
		DataPack pack = g_hArray.Get(i);
		pack.Reset();
		pack.ReadString(buffer, sizeof(buffer));
		
		if (!strcmp(buffer, weaponname))
		{
			//Update current cache values
			g_bZeus[client] = pack.ReadCell();
			g_bGlow[client] = pack.ReadCell();
			g_fImpactSound[client] = pack.ReadFloat();
			g_fMuzzleSound[client] = pack.ReadFloat();
			g_bAccess[client] = pack.ReadCell();
		}
	}
}

public Action Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;
		
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!g_bOverride[client] && !g_bZeus[client])
		return Plugin_Continue;
		
	if (!g_bOverride[client] && !CheckCommandAccess(client, "", g_bAccess[client], true))
		return Plugin_Continue;
	
	float impact_pos[3];
	impact_pos[0] = event.GetFloat("x");
	impact_pos[1] = event.GetFloat("y");
	impact_pos[2] = event.GetFloat("z");
	
	float muzzle_pos[3], camera_pos[3];
	GetWeaponAttachmentPosition(client, "muzzle_flash", muzzle_pos);
	GetWeaponAttachmentPosition(client, "camera_buymenu", camera_pos);
	
	//Create an offset for first person
	float pov_pos[3];
	pov_pos[0] = muzzle_pos[0] - camera_pos[0];
	pov_pos[1] = muzzle_pos[1] - camera_pos[1];
	pov_pos[2] = muzzle_pos[2] - camera_pos[2] + 0.1;
	ScaleVector(pov_pos, 0.4);
	SubtractVectors(muzzle_pos, pov_pos, pov_pos);
	
	//Move the beam a bit forward so it isn't too close for first person
	float distance = GetVectorDistance(pov_pos, impact_pos);
	float percentage = 0.2 / (distance / 100);
	pov_pos[0] = pov_pos[0] + ((impact_pos[0] - pov_pos[0]) * percentage);
	pov_pos[1] = pov_pos[1] + ((impact_pos[1] - pov_pos[1]) * percentage);
	pov_pos[2] = pov_pos[2] + ((impact_pos[2] - pov_pos[2]) * percentage);
	
	//Display the particle to first person 
	TE_DispatchEffect(TASER, pov_pos, impact_pos, g_fLastAngles[client]);
	TE_SendToClient(client);
	
	//Display the particle to everyone else under the normal position
	TE_DispatchEffect(TASER, muzzle_pos, impact_pos, g_fLastAngles[client]);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || i == client || IsFakeClient(i))
			continue;
		TE_SendToClient(i);
	}
	
	if (g_bGlow[client])
	{
		//Move the impact glow a bit out so it doesn't clip the wall
		impact_pos[0] = impact_pos[0] + ((pov_pos[0] - impact_pos[0]) * percentage);
		impact_pos[1] = impact_pos[1] + ((pov_pos[1] - impact_pos[1]) * percentage);
		impact_pos[2] = impact_pos[2] + ((pov_pos[2] - impact_pos[2]) * percentage);
		
		TE_DispatchEffect(GLOW, impact_pos, impact_pos);
		TE_SendToAll();
	}
	
	//TE_DispatchEffect(SPARK, impact_pos, impact_pos);
	//TE_SendToAll();
	return Plugin_Continue;
}


public Action Hook_BulletShot(const char[] te_name, const int[] Players, int numClients, float delay)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;
		
	int client = TE_ReadNum("m_iPlayer") + 1;
	
	if (!g_bOverride[client] && !g_bZeus[client])
		return Plugin_Continue;
		
	if (!g_bOverride[client] && !CheckCommandAccess(client, "", g_bAccess[client], true))
		return Plugin_Continue;
	
	float origin[3];
	TE_ReadVector("m_vecOrigin", origin);
	g_fLastAngles[client][0] = TE_ReadFloat("m_vecAngles[0]");
	g_fLastAngles[client][1] = TE_ReadFloat("m_vecAngles[1]");
	g_fLastAngles[client][2] = 0.0;
	
	float impact_pos[3];
	Handle trace = TR_TraceRayFilterEx(origin, g_fLastAngles[client], MASK_SHOT, RayType_Infinite, TR_DontHitSelf, client);
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(impact_pos, trace);
	}
	delete trace;
	//Play the taser sounds
	EmitAmbientSound(SOUND_IMPACT, impact_pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fImpactSound[client], SNDPITCH_LOW);
	EmitAmbientSound(SOUND_SHOOT, origin, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fMuzzleSound[client], SNDPITCH_LOW);
	return Plugin_Continue;
}

public bool TR_DontHitSelf(int entity, int mask, any data)
{
	if (entity == data) 
		return false;
	return true;
}

void GetWeaponAttachmentPosition(int client, const char[] attachment, float pos[3])
{
	if (!attachment[0])
		return;
		
	int entity = CreateEntityByName("info_target");
	DispatchSpawn(entity);
	
	int weapon;
	
	if ((weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")) == -1)
		return;
	
	if ((weapon = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel")) == -1)
		return;
		
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", weapon, entity, 0);
	
	SetVariantString(attachment); 
	AcceptEntityInput(entity, "SetParentAttachment", weapon, entity, 0);
	
	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);
	AcceptEntityInput(entity, "kill");
}

void TE_DispatchEffect(const char[] particle, const float pos[3], const float endpos[3], const float angles[3] = NULL_VECTOR)
{
	TE_Start("EffectDispatch");
	TE_WriteFloatArray("m_vStart.x", pos, 3);
	TE_WriteFloatArray("m_vOrigin.x", endpos, 3);
	TE_WriteVector("m_vAngles", angles);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(particle));
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
}

void PrecacheParticleEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");
		
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

int GetParticleEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}

void PrecacheEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");
		
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

int GetEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}

void SetupKVFiles()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/zeustracers_guns.cfg");
	
	if (!FileExists(sPath))
	{
		LogError("Error: Can not find map filepath %s", sPath);
		SetFailState("Error: Can not find map filepath %s", sPath);
	}
	
	Handle kv = CreateKeyValues("Zeus Tracers");
	FileToKeyValues(kv, sPath);

	if (!KvGotoFirstSubKey(kv))
	{
		LogError("Can not read file: %s", sPath);
		SetFailState("Can not read file: %s", sPath);
	}
	
	//Clear array of old data when map changes
	g_hArray.Clear();
	
	char weaponname[32], flagstring[2];
	int enable, glow;
	float impactsound, muzzlesound;
	
	do
	{
		KvGetSectionName(kv, weaponname, sizeof(weaponname));
		enable = KvGetNum(kv, "Enable", 0);
		glow = KvGetNum(kv, "Impact Glow", 1);
		impactsound = KvGetFloat(kv, "Impact Sound", 0.0);
		muzzlesound = KvGetFloat(kv, "Muzzle Sound", 0.0);
		KvGetString(kv, "Flag", flagstring, sizeof(flagstring), "");
		int buffer = flagstring[0];
		AdminFlag flag;
		FindFlagByChar(buffer, flag);
		
		//Cache values
		DataPack pack = new DataPack();
		pack.WriteString(weaponname);
		pack.WriteCell(enable);
		pack.WriteCell(glow);
		pack.WriteFloat(impactsound);
		pack.WriteFloat(muzzlesound);
		pack.WriteCell(view_as<int>(flag));
		g_hArray.Push(pack);
		
	} while (KvGotoNextKey(kv));
}
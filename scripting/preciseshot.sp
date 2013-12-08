#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <sdktools>

#define VERSION "v2.0"

static Float:PrethinkBuffer;

new Handle:PSEnableDrop = INVALID_HANDLE;
new Handle:PSClientMessage = INVALID_HANDLE;
new Handle:PSWeaponUse = INVALID_HANDLE;
new Handle:PSWeaponName = INVALID_HANDLE;
new Handle:PSDamage = INVALID_HANDLE;
new Handle:PSDamageCheck = INVALID_HANDLE;
new Handle:PSEnableBleed = INVALID_HANDLE;
new Handle:PSBleedHP = INVALID_HANDLE;
new Handle:PSBleedFreq = INVALID_HANDLE;
new Handle:PSEnableVision = INVALID_HANDLE;
new Handle:PSVisionHP = INVALID_HANDLE;
new Handle:PSEnableSlowSpeed = INVALID_HANDLE;
new Handle:PSSlowSpeedAmount = INVALID_HANDLE;
new Handle:PSSlowSpeedHP = INVALID_HANDLE;

new m_iFOV;
new BloodClient[2000];

public Plugin:myinfo = 
{
	name = "PreciseShot",
	author = "Xilver266 Steam: donchopo",
	description = "Force drop weapon client on shooting him in the hands",
	version = VERSION,
	url = "servers-cfg.foroactivo.com"
};

public OnPluginStart()
{
	AutoExecConfig(true, "plugin.preciseshot");
	CreateConVar("sm_preciseshot_version", VERSION, "PreciseShot", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	PSEnableDrop = CreateConVar("sm_ps_enabledrop", "1", "Force drop weapon client on shooting him in the hands", _, true, 0.0, true, 1.0);
	PSWeaponUse = CreateConVar("sm_ps_weaponuse", "0", "Use a specific weapon for make the drop function", _, true, 0.0, true, 1.0);
	PSWeaponName = CreateConVar("sm_ps_weaponname", "weapon_usp", "Specific weapon (Dependency: sm_psweaponuse)");
	PSDamageCheck = CreateConVar("sm_ps_damagecheck", "1", "Damage to force drop weapon", _, true, 0.0, true, 1.0);	
	PSDamage = CreateConVar("sm_ps_damage", "10", "Amount of damage to force drop weapon (Dependency: sm_psdamagecheck)");
	PSClientMessage = CreateConVar("sm_ps_messages", "1", "Show messages to client", _, true, 0.0, true, 1.0);
	PSEnableBleed = CreateConVar("sm_ps_enable_bleed", "1", "Enable bleed", _, true, 0.0, true, 1.0);
	PSBleedFreq = CreateConVar("sm_ps_bleedingfreq", "15", "Time between bleeding (Dependency: sm_psenablebleed)");
	PSBleedHP = CreateConVar("sm_ps_bleedinghp", "50", "HP required to start bleeding (Dependency: sm_psenablebleed)");
	PSEnableVision = CreateConVar("sm_ps_enable_vision", "1", "Enable dark vision", _, true, 0.0, true, 1.0);
	PSVisionHP = CreateConVar("sm_ps_visionhp", "25", "HP required to set dark vision.");
	PSEnableSlowSpeed = CreateConVar("sm_ps_enable_slowspeed", "1", "Enable slow speed on low health", _, true, 0.0, true, 1.0);
	PSSlowSpeedAmount = CreateConVar("sm_ps_slowspeed", "0.7", "Speed on low health (Dependency: sm_ps_enable_slowspeed)");
	PSSlowSpeedHP = CreateConVar("sm_ps_slowspeedhp", "50", "HP required to start slow speed (Dependency: sm_ps_enable_slowspeed)");
	
	HookEvent("player_hurt", PlayerHurt);
	HookEvent("player_spawn", PlayerSpawn);
	
	m_iFOV = FindSendPropOffs("CBasePlayer","m_iFOV");
	
}

public OnMapStart()
{
	ForcePrecache("blood_impact_red_01_droplets");
	ForcePrecache("blood_impact_red_01_smalldroplets");
	ForcePrecache("blood_zombie_split_spray_tiny");
	ForcePrecache("blood_zombie_split_spray_tiny2");
	ForcePrecache("blood_impact_red_01");
	ForcePrecache("blood_impact_red_01_goop");
	ForcePrecache("blood_impact_red_01_mist");
	ForcePrecache("blood_advisor_puncture");
	ForcePrecache("blood_advisor_puncture_withdraw");
	ForcePrecache("blood_antlionguard_injured_heavy_tiny");
	ForcePrecache("blood_advisor_pierce_spray");
	ForcePrecache("blood_advisor_pierce_spray_b");
	ForcePrecache("blood_advisor_pierce_spray_c");
	ForcePrecache("blood_zombie_split_spray");
}

ForcePrecache(String:ParticleName[])
{
	decl Particle;
	Particle = CreateEntityByName("info_particle_system");
	
	if(IsValidEdict(Particle))
	{
		DispatchKeyValue(Particle, "effect_name", ParticleName);
		DispatchSpawn(Particle);
		ActivateEntity(Particle);
		AcceptEntityInput(Particle, "start");
		CreateTimer(0.3, RemoveBlood, Particle, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetConVarBool(PSEnableVision))
	{
		Normal_Vision(client);
	}
}

public Action:PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (GetConVarBool(PSEnableVision))
	{
		if (GetClientHealth(victim) <= GetConVarInt(PSVisionHP))
		{
			Dark_Vision(victim);
		}
	}
	if (GetConVarBool(PSEnableSlowSpeed))
	{
		if (GetClientHealth(victim) <= GetConVarInt(PSSlowSpeedHP))
		{
			SetEntPropFloat(victim, Prop_Data, "m_flLaggedMovementValue", GetConVarFloat(PSSlowSpeedAmount));
		}
	}
}

public OnclientPutInServer(client)
{
	SDKHook(client, SDKHook_TraceAttack, HookTraceAttack);
}

public IsValidClient(client) 
{ 
	if (!( 1 <= client <= MaxClients ) || !IsClientInGame(client)) 
		return false; 
	
	return true; 
}

public Action:HookTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, HitGroup)
{
	if (IsValidClient(attacker))
	{
		if (GetConVarBool(PSEnableDrop))
		{
			new String:g_Weapon[32];
			GetClientWeapon(attacker, g_Weapon, sizeof(g_Weapon));
			
			new String:g_WeaponName[32];
			GetConVarString(PSWeaponName, g_WeaponName, sizeof(g_WeaponName));
			
			if (HitGroup == 4 || HitGroup == 5)
			{
				if (GetConVarBool(PSDamageCheck))
				{
					if (damage >= GetConVarInt(PSDamage))
					{
						if (GetConVarBool(PSWeaponUse))
						{
							if (StrEqual(g_Weapon, g_WeaponName))
							{
								if (GetClientTeam(attacker) == GetClientTeam(victim))
									return Plugin_Handled;
								
								FakeClientCommand(victim, "drop");
								
								if (GetConVarBool(PSClientMessage))
								{
									PrintToChat(victim, "\x04[SM PreciseShot] \x01The player \x04%N \x01have thrown thee the gun", attacker);
									PrintToChat(attacker, "\x04[SM PreciseShot] \x01You've thrown the gun of \x03%N", victim);
								}
								return Plugin_Continue;	
							}	
						}
						else
						{
							if (GetClientTeam(attacker) == GetClientTeam(victim))
								return Plugin_Handled;
							
							FakeClientCommand(victim, "drop");
							
							if (GetConVarBool(PSClientMessage))
							{
								PrintToChat(victim, "\x04[SM PreciseShot] \x01The player \x04%N \x01have thrown thee the gun", attacker);
								PrintToChat(attacker, "\x04[SM PreciseShot] \x01You've thrown the gun of \x03%N", victim);
							}
							return Plugin_Continue;	
						}
					}
				}
				else
				{
					if (GetConVarBool(PSWeaponUse))
					{
						if (StrEqual(g_Weapon, g_WeaponName))
						{
							if (GetClientTeam(attacker) == GetClientTeam(victim))
								return Plugin_Handled;
							
							FakeClientCommand(victim, "drop");
							
							if (GetConVarBool(PSClientMessage))
							{
								PrintToChat(victim, "\x04[SM PreciseShot] \x01The player \x04%N \x01have thrown thee the gun", attacker);
								PrintToChat(attacker, "\x04[SM PreciseShot] \x01You've thrown the gun of \x03%N", victim);
							}
							return Plugin_Continue;	
						}				
					}
					else
					{
						if (GetClientTeam(attacker) == GetClientTeam(victim))
							return Plugin_Handled;
						
						FakeClientCommand(victim, "drop");
						
						if (GetConVarBool(PSClientMessage))
						{
							PrintToChat(victim, "\x04[SM PreciseShot] \x01The player \x04%N \x01have thrown thee the gun", attacker);
							PrintToChat(attacker, "\x04[SM PreciseShot] \x01You've thrown the gun of \x03%N", victim);
						}
						return Plugin_Continue;				
					}
				}
			}
		}
	}
	return Plugin_Changed;
}

public Action:RemoveBlood(Handle:Timer, any:Particle)
{
	if (IsValidEntity(Particle))
	{
		decl String:Classname[64];
		GetEdictClassname(Particle, Classname, sizeof(Classname));
		
		if (StrEqual(Classname, "info_particle_system", false))
		{
			RemoveEdict(Particle);
		}
	}
}

public Action:Bleed(Handle:Timer, any:client)
{
	if (IsClientInGame(client))
	{
		if (GetClientHealth(client) < 100 && IsPlayerAlive(client))
		{
			decl Roll;
			decl Float:Origin[3], Float:Direction[3];
			
			Roll = GetRandomInt(1, 2);
			GetClientAbsOrigin(client, Origin);
			Origin[2] += 10.0;
			
			Direction[0] = GetRandomFloat(-1.0, 1.0);
			Direction[1] = GetRandomFloat(-1.0, 1.0);
			
			if (Roll == 1) WriteParticle(client, "blood_zombie_split_spray_tiny");
			if (Roll == 2) WriteParticle(client, "blood_zombie_split_spray_tiny2");
			
			Roll = GetRandomInt(1, 2);
			if (Roll == 1) WriteParticle(client, "blood_impact_red_01_droplets");
			
			Roll = GetRandomInt(1, 2);
			if (Roll == 1) WriteParticle(client, "blood_impact_red_01_smalldroplets");
			
			Direction[2] = -1.0;
			Decal(client, Direction);
		}
	}
}

stock Decal(client, Float:Direction[3])
{
	decl Blood;
	decl String:Angles[128];
	
	Format(Angles, 128, "%f %f %f", Direction[0], Direction[1], Direction[2]);
	
	Blood = CreateEntityByName("env_blood");
	
	if (IsValidEdict(Blood))
	{
		DispatchSpawn(Blood);
		DispatchKeyValue(Blood, "color", "0");
		DispatchKeyValue(Blood, "amount", "1000");
		DispatchKeyValue(Blood, "spraydir", Angles);
		DispatchKeyValue(Blood, "spawnflags", "12");
	}
	
	if (IsValidEdict(Blood)) RemoveEdict(Blood);
}

public OnGameFrame()
{
	if (GetConVarBool(PSEnableBleed))
	{
		if (PrethinkBuffer <= (GetGameTime() - GetConVarInt(PSBleedFreq)))
		{
			PrethinkBuffer = GetGameTime();
			decl MaxPlayers;
			MaxPlayers = GetMaxClients();
			
			for (new client = 1; client <= MaxPlayers; client++)
			{
				if (IsClientInGame(client))
				{
					if (IsPlayerAlive(client))
					{
						if (GetClientHealth(client) <= GetConVarInt(PSBleedHP))
						{
							CreateTimer(1.0, Bleed, client);
						}
					}
				}
			}
		}
	}
}

WriteParticle(Ent, String:ParticleName[])
{
	decl Particle;
	decl String:tName[64];
	
	Particle = CreateEntityByName("info_particle_system");
	
	if (IsValidEdict(Particle))
	{
		decl Float:Position[3], Float:Angles[3];
		
		Angles[0] = GetRandomFloat(0.0, 360.0);
		Angles[1] = GetRandomFloat(-15.0, 15.0);
		Angles[2] = GetRandomFloat(-15.0, 15.0);
		
		GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", Position);
		
		Position[2] += GetRandomFloat(15.0, 35.0);
		
		TeleportEntity(Particle, Position, Angles, NULL_VECTOR);
		
		Format(tName, sizeof(tName), "Entity%d", Ent);
		DispatchKeyValue(Ent, "targetname", tName);
		GetEntPropString(Ent, Prop_Data, "m_iName", tName, sizeof(tName));
		
		DispatchKeyValue(Particle, "targetname", "CSSParticle");
		DispatchKeyValue(Particle, "parentname", tName);
		DispatchKeyValue(Particle, "effect_name", ParticleName);
		
		DispatchSpawn(Particle);
		
		SetVariantString(tName);
		AcceptEntityInput(Particle, "SetParent", Particle, Particle, 0);
		
		ActivateEntity(Particle);
		AcceptEntityInput(Particle, "start");
		
		CreateTimer(3.0, RemoveBlood, Particle);
	}
}

public Action:EmitBlood(Handle:Timer, any:Blood)
{
	if (IsValidEdict(Blood) && IsClientConnected(BloodClient[Blood]))
		AcceptEntityInput(Blood, "EmitBlood", BloodClient[Blood]);
	
	if (IsValidEdict(Blood)) 
		RemoveEdict(Blood);
}

stock Dark_Vision(const any:client)
{
	new Handle:message = StartMessageOne("Fade", client, 1);
	
	if (IsClientInGame(client) && IsClientConnected(client) && IsPlayerAlive(client))
	{
		//FFADE_IN            0x0001        // Just here so we don't pass 0 into the function
		//FFADE_OUT           0x0002        // Fade out (not in)
		//FFADE_MODULATE      0x0004        // Modulate (don't blend)
		//FFADE_STAYOUT       0x0008        // ignores the duration, stays faded out until new ScreenFade message received
		//FFADE_PURGE         0x0010        // Purges all other fades, replacing them with this one
		
		
		SetEntData(client, m_iFOV, 90, 4, true);
		BfWriteShort(message, 585);
		BfWriteShort(message, 585);
		BfWriteShort(message, (0x0008)); //Fade out
		BfWriteByte(message, 0); //fade red
		BfWriteByte(message, 0); //fade green
		BfWriteByte(message, 0); //fade blue
		BfWriteByte(message, 100); //fade alpha
		EndMessage();
	}
}

stock Normal_Vision(const any:client)
{
	new Handle:message = StartMessageOne("Fade", client, 1);
	
	if (IsClientInGame(client) && IsClientConnected(client))
	{
		//FFADE_IN            0x0001        // Just here so we don't pass 0 into the function
		//FFADE_OUT           0x0002        // Fade out (not in)
		//FFADE_MODULATE      0x0004        // Modulate (don't blend)
		//FFADE_STAYOUT       0x0008        // ignores the duration, stays faded out until new ScreenFade message received
		//FFADE_PURGE         0x0010        // Purges all other fades, replacing them with this one
		
		
		SetEntData(client, m_iFOV, 90, 4, true);
		BfWriteShort(message, 585);
		BfWriteShort(message, 585);
		BfWriteShort(message, (0x0008)); //Fade out
		BfWriteByte(message, 0); //fade red
		BfWriteByte(message, 0); //fade green
		BfWriteByte(message, 0); //fade blue
		BfWriteByte(message, 0); //fade alpha
		EndMessage();
	}
}
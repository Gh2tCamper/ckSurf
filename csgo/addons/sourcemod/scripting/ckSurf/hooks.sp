//button hook
public Action NormalSHook_callback(clients[64], &numClients, char sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
    if(entity > MaxClients)
    {
        char clsname[20]; GetEntityClassname(entity, clsname, sizeof(clsname));
        if(StrEqual(clsname, "func_button", false))
        {
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}  

//attack spam protection
public Action Event_OnFire(Handle event, const char[] name, bool dontBroadcast)
{
	int client   = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && IsClientInGame(client) && g_bAttackSpamProtection) 
	{
		char weapon[64];
		GetEventString(event, "weapon", weapon, 64);
		if (StrContains(weapon,"knife",true) == -1 && g_AttackCounter[client] < 41)
		{	
			if (g_AttackCounter[client] < 41)
			{
				g_AttackCounter[client]++;
				if (StrContains(weapon,"grenade",true) != -1 || StrContains(weapon,"flash",true) != -1)
				{
					g_AttackCounter[client] = g_AttackCounter[client] + 9;
					if (g_AttackCounter[client] > 41)
						g_AttackCounter[client] = 41;
				}
			}
		}
	}
}

// - PlayerSpawn -
public Action Event_OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client != 0)
	{	
		PlayerSpawn(client);
	}
	return Plugin_Continue;
}

PlayerSpawn(client)
{
	if (!IsValidClient(client))
		return;

	g_fStartCommandUsed_LastTime[client] = GetGameTime();
	g_SpecTarget[client] = -1;	
	g_bPause[client] = false;
	g_bFirstButtonTouch[client]=true;
	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntityRenderMode(client, RENDER_NORMAL);
	
	//strip weapons
	if ((GetClientTeam(client) > 1) && IsValidClient(client))
	{			
		StripAllWeapons(client);
		if (!IsFakeClient(client))
			GivePlayerItem(client, "weapon_usp_silencer");
		if (!g_bStartWithUsp[client])
		{
			int weapon = GetPlayerWeaponSlot(client, 2);
			if (weapon != -1 && !IsFakeClient(client))
				 SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		}
	}	

	//godmode
	if (g_bgodmode || IsFakeClient(client))
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	else
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		
	//NoBlock
	if(g_bNoBlock || IsFakeClient(client))
		SetEntData(client, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), 2, 4, true);
	else
		SetEntData(client, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), 5, 4, true);
						
	//botmimic2		
	if(g_hBotMimicsRecord[client] != null && IsFakeClient(client))
	{
		g_BotMimicTick[client] = 0;
		g_CurrentAdditionalTeleportIndex[client] = 0;
	}	
	
	if (IsFakeClient(client))	
	{
		if (client==g_InfoBot)
			CS_SetClientClanTag(client, ""); 	
		else
			CS_SetClientClanTag(client, "LOCALHOST"); 	
		return;
	}
	
	//change player skin
	if (g_bPlayerSkinChange && (GetClientTeam(client) > 1))
	{
		SetEntPropString(client, Prop_Send, "m_szArmsModel", g_sArmModel);
		SetEntityModel(client,  g_sPlayerModel);
	}		

	//1st spawn & t/ct
	if (g_bFirstSpawn[client] && (GetClientTeam(client) > 1))		
	{
		StartRecording(client);
		CreateTimer(1.5, CenterMsgTimer, client,TIMER_FLAG_NO_MAPCHANGE);		
		g_bFirstSpawn[client] = false;
	}
	
	//get start pos for challenge
	GetClientAbsOrigin(client, g_fSpawnPosition[client]);
	
	//restore position
	if (!g_specToStage[client])
	{

		if ((GetClientTeam(client) > 1))
		{
			if (g_bRestorePosition[client])
			{		
				g_bPositionRestored[client] = true;
				TeleportEntity(client, g_fPlayerCordsRestore[client],g_fPlayerAnglesRestore[client],NULL_VECTOR);
				g_bRestorePosition[client]  = false;
			}
			else
			{
				if (g_bRespawnPosition[client])
				{
					TeleportEntity(client, g_fPlayerCordsRestore[client],g_fPlayerAnglesRestore[client],NULL_VECTOR);
					g_bRespawnPosition[client] = false;
				}
				else
				{
					if (g_bAutoTimer)
					{
						if (bSpawnToStartZone)
						{
							//int startZoneId = getZoneID(0, 1);
							//TeleportEntity(client, g_fZonePositions[startZoneId], NULL_VECTOR, Float:{0.0,0.0,-100.0});
							Command_Restart(client, 1);
						}

						CreateTimer(0.1, StartTimer, client,TIMER_FLAG_NO_MAPCHANGE);
					}
					else
					{
						
						g_bTimeractivated[client] = false;	
						g_fStartTime[client] = -1.0;
						g_fCurrentRunTime[client] = -1.0;	

						// Spawn client to the start zone.
						if (bSpawnToStartZone) 
						{
							//int startZoneId = getZoneID(0, 1);
							Command_Restart(client, 1);
							//if (startZoneId > 0)
							//	TeleportEntity(client, g_fZonePositions[startZoneId], NULL_VECTOR, Float:{0.0,0.0,-100.0});		
						}
					}
				}
			}	
		}
	}
	else
	{
		Array_Copy(g_fTeleLocation[client], g_fPlayerCordsRestore[client], 3);
		Array_Copy(NULL_VECTOR, g_fPlayerAnglesRestore[client], 3);
		SetEntPropVector(client, Prop_Data, "m_vecVelocity", Float:{0.0,0.0,-100.0});
		TeleportEntity(client, g_fTeleLocation[client],NULL_VECTOR,Float:{0.0,0.0,-100.0});
		g_specToStage[client] = false;
	}
	
	//hide radar
	CreateTimer(0.0, HideRadar, client,TIMER_FLAG_NO_MAPCHANGE);
	
	//set clantag
	CreateTimer(1.5, SetClanTag, client,TIMER_FLAG_NO_MAPCHANGE);	
			
	//set speclist
	Format(g_szPlayerPanelText[client], 512, "");		

	//get speed & origin
	g_fLastSpeed[client] = GetSpeed(client);
	GetClientAbsOrigin(client, g_fLastPosition[client]);	
}

public Action Say_Hook(client, const char[] command, argc)
{
	//Call Admin - Own Reason
	if (g_bClientOwnReason[client])
	{
		g_bClientOwnReason[client] = false;
		return Plugin_Continue;
	}

	char sText[1024];
	GetCmdArgString(sText, sizeof(sText));
	
	if (IsValidClient(client) && g_ClientRenamingZone[client])
	{
		Admin_renameZone(client, sText);
		return Plugin_Handled;
	}

	if (!g_benableChatProcessing)
		return Plugin_Continue;	
	
	if (IsValidClient(client))
	{
		if (client > 0)
			if (BaseComm_IsClientGagged(client))
				return Plugin_Handled;

		if (checkSpam(client))
			return Plugin_Handled;
		
		StripQuotes(sText);
		TrimString(sText);

		ReplaceString(sText,1024,"{darkred}","",false);
		ReplaceString(sText,1024,"{green}","",false);
		ReplaceString(sText,1024,"{lightgreen}","",false);
		ReplaceString(sText,1024,"{blue}","",false);
		ReplaceString(sText,1024,"{olive}","",false);
		ReplaceString(sText,1024,"{lime}","",false);
		ReplaceString(sText,1024,"{red}","",false);
		ReplaceString(sText,1024,"{purple}","",false);
		ReplaceString(sText,1024,"{grey}","",false);
		ReplaceString(sText,1024,"{yellow}","",false);
		ReplaceString(sText,1024,"{lightblue}","",false);
		ReplaceString(sText,1024,"{steelblue}","",false);
		ReplaceString(sText,1024,"{darkblue}","",false);
		ReplaceString(sText,1024,"{pink}","",false);
		ReplaceString(sText,1024,"{lightred}","",false);

		//empty message
		if(StrEqual(sText, " ") || !sText[0])
		{
			return Plugin_Handled;		
		}

		//lowercase
		if((sText[0] == '/') || (sText[0] == '!'))
		{
			if(IsCharUpper(sText[1]))
			{
				for(int i = 0; i <= strlen(sText); ++i)
						sText[i] = CharToLower(sText[i]);
				FakeClientCommand(client, "say %s", sText);
				return Plugin_Handled;
			}
		}
		
		//blocked commands
		for(int i = 0; i < sizeof(g_BlockedChatText); i++)
		{
			if (StrEqual(g_BlockedChatText[i],sText,true))
			{
				return Plugin_Handled;			
			}
		}

		// !s and !stage commands
		if (StrContains(sText,"!s",false)==0 || StrContains(sText,"!stage",false)==0)	
			return Plugin_Handled;	
		
		// !b and !bonus commands
		if (StrContains(sText,"!b",false)==0 || StrContains(sText,"!bonus",false)==0)	
			return Plugin_Handled;

		//chat trigger?
		if((IsChatTrigger() && sText[0] == '/') || (sText[0] == '@' && (GetUserFlagBits(client) & ADMFLAG_ROOT ||  GetUserFlagBits(client) & ADMFLAG_GENERIC)))
		{
			return Plugin_Continue;
		}
		
		//log the chat of the player to the server so that tools such as HLSW/HLSTATX see it and also it remains logged in the log file
		WriteChatLog(client, "say", sText);
		
		char szName[64];
		GetClientName(client,szName,64);		
		ReplaceString(szName,64,"{darkred}","",false);
		ReplaceString(szName,64,"{green}","",false);
		ReplaceString(szName,64,"{lightgreen}","",false);
		ReplaceString(szName,64,"{blue}","",false);
		ReplaceString(szName,64,"{olive}","",false);
		ReplaceString(szName,64,"{lime}","",false);
		ReplaceString(szName,64,"{red}","",false);
		ReplaceString(szName,64,"{purple}","",false);
		ReplaceString(szName,64,"{grey}","",false);
		ReplaceString(szName,64,"{yellow}","",false);
		ReplaceString(szName,64,"{lightblue}","",false);
		ReplaceString(szName,64,"{steelblue}","",false);
		ReplaceString(szName,64,"{darkblue}","",false);
		ReplaceString(szName,64,"{pink}","",false);
		ReplaceString(szName,64,"{lightred}","",false);

		////////////////
		//say stuff
		//
		//SPEC

		/*#define WHITE 0x01
		#define DARKRED 0x02
		#define PURPLE 0x03
		#define GREEN 0x04
		#define MOSSGREEN 0x05
		#define LIMEGREEN 0x06
		#define RED 0x07
		#define GRAY 0x08
		#define YELLOW 0x09
		#define DARKGREY 0x0A
		#define BLUE 0x0B
		#define DARKBLUE 0x0C
		#define LIGHTBLUE 0x0D
		#define PINK 0x0E
		#define LIGHTRED 0x0F
		*/

		if (g_bPointSystem && g_bColoredNames)
		{
			switch(g_PlayerChatRank[client])
			{
				case 0: // 1st Rank
					Format(szName, 64, "%c%s", WHITE, szName);
				case 1:
					Format(szName, 64, "%c%s", WHITE, szName);
				case 2:
					Format(szName, 64, "%c%s", GRAY, szName);
				case 3:
					Format(szName, 64, "%c%s", LIGHTBLUE, szName);
				case 4:
					Format(szName, 64, "%c%s", BLUE, szName);
				case 5:
					Format(szName, 64, "%c%s", DARKBLUE, szName);
				case 6:
					Format(szName, 64, "%c%s", PINK, szName);
				case 7:
					Format(szName, 64, "%c%s", LIGHTRED, szName);
				case 8: // Highest rank
					Format(szName, 64, "%c%s", DARKRED, szName);
			/*	case 9: // Admin
					Format(szName, 64, "%c%s", GREEN, szName);
				case 10: // VIP
					Format(szName, 64, "%c%s", MOSSGREEN, szName);
				case 11: // Mapper
					Format(szName, 64, "%c%s", YELLOW, szName);*/
			}
		}

		if (GetClientTeam(client) == 1)
		{
			PrintSpecMessageAll(client);
			return Plugin_Handled;
		}
		else
		{
			char szChatRank[64];
			Format(szChatRank, 64, "%s",g_pr_chat_coloredrank[client]);			
			
			if (g_bCountry && (g_bPointSystem || (StrEqual(g_pr_rankname[client], "ADMIN", false) && g_bAdminClantag)))
			{	
				if (IsPlayerAlive(client))
					CPrintToChatAllEx(client,"{green}%s{default} %s {teamcolor}%s{default}: %s",g_szCountryCode[client],szChatRank,szName,sText);			
				else
					CPrintToChatAllEx(client,"{green}%s{default} %s {teamcolor}*DEAD* %s{default}: %s",g_szCountryCode[client],szChatRank,szName,sText);
				return Plugin_Handled;
			}
			else
			{
				if (g_bPointSystem || ((StrEqual(g_pr_rankname[client], "ADMIN", false)) && g_bAdminClantag))
				{
					if (IsPlayerAlive(client))
						CPrintToChatAllEx(client,"%s {teamcolor}%s{default}: %s",szChatRank,szName,sText);	
					else
						CPrintToChatAllEx(client,"%s {teamcolor}*DEAD* %s{default}: %s",szChatRank,szName,sText);
					return Plugin_Handled;							
				}
				else
					if (g_bCountry)
					{
						if (IsPlayerAlive(client))
							CPrintToChatAllEx(client,"[{green}%s{default}] {teamcolor}%s{default}: %s",g_szCountryCode[client],szName,sText);	
						else
							CPrintToChatAllEx(client,"[{green}%s{default}] {teamcolor}*DEAD* %s{default}: %s",g_szCountryCode[client],szName,sText);		
						return Plugin_Handled;							
					}								
			}
		}	
	}
	return Plugin_Continue;
}

public Action Event_OnPlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client) || IsFakeClient(client))
		return Plugin_Continue;
	int team = GetEventInt(event, "team");
	if(team == 1)
	{
		SpecListMenuDead(client);
		if (!g_bFirstSpawn[client])
		{
			GetClientAbsOrigin(client,g_fPlayerCordsRestore[client]);
			GetClientEyeAngles(client, g_fPlayerAnglesRestore[client]);
			g_bRespawnPosition[client] = true;
		}
		if (g_bTimeractivated[client])
		{	
			g_fStartPauseTime[client] = GetGameTime();
			if (g_fPauseTime[client] > 0.0)
				g_fStartPauseTime[client] = g_fStartPauseTime[client] - g_fPauseTime[client];	
		}
		g_bSpectate[client] = true;
		if (g_bPause[client])
			g_bPauseWasActivated[client]=true;
		g_bPause[client]=false;
	}
	return Plugin_Continue;
}

public Action Event_PlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_bDisconnectMsg)
	{
		char szName[64];
		char disconnectReason[64];
		int clientid = GetEventInt(event,"userid");
		int client = GetClientOfUserId(clientid);
		if (!IsValidClient(client) || IsFakeClient(client))
			return Plugin_Handled;
		GetEventString(event, "name", szName, sizeof(szName));
		GetEventString(event, "reason", disconnectReason, sizeof(disconnectReason));  
		for (int i = 1; i <= MaxClients; i++)
			if (IsValidClient(i) && i != client && !IsFakeClient(i))
				PrintToChat(i, "%t", "Disconnected1",WHITE, MOSSGREEN, szName, WHITE, disconnectReason);	
		return Plugin_Handled;
	}
	else
	{
		SetEventBroadcast(event, true);
		return Plugin_Handled;
	}
}

public Action Hook_SetTransmit(entity, client) 
{ 
    if (client != entity && (0 < entity <= MaxClients) && IsValidClient(client)) 
	{
		if (g_bChallenge[client] && !g_bHide[client])
		{
			if (!StrEqual(g_szSteamID[entity], g_szChallenge_OpponentID[client], false))
				return Plugin_Handled;
		}
		else
			if (g_bHide[client] && entity != g_SpecTarget[client])
				return Plugin_Handled; 
			else
				if (entity == g_InfoBot && entity != g_SpecTarget[client])
					return Plugin_Handled;
	}	
    return Plugin_Continue; 
}  

public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetEventInt(event,"userid");
	if (IsValidClient(client))
	{
		if (!IsFakeClient(client))
		{
			if(g_hRecording[client] != null)
				StopRecording(client);			
			CreateTimer(2.0, RemoveRagdoll, client);
		}
		else 
			if(g_hBotMimicsRecord[client] != null)
			{
				g_BotMimicTick[client] = 0;
				g_CurrentAdditionalTeleportIndex[client] = 0;
				if(GetClientTeam(client) >= CS_TEAM_T)
					CreateTimer(1.0, RespawnBot, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
	}
	return Plugin_Continue;
}
					
public Action CS_OnTerminateRound(&Float:delay, &CSRoundEndReason:reason)
{
	if (g_bRoundEnd)
		return Plugin_Continue;
	int timeleft;
	GetMapTimeLeft(timeleft);
	if (timeleft>= -1)
		return Plugin_Handled;
	g_bRoundEnd=true;
	return Plugin_Continue;
}  

public Action Event_OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd=true;
	return Plugin_Continue;
}

public OnPlayerThink(entity)
{
	SetEntPropEnt(entity, Prop_Send, "m_bSpotted", 0); 
}


// OnRoundRestart
public Action Event_OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	int iEnt;
	for(int i = 0; i < sizeof(EntityList); i++)
	{
		while((iEnt = FindEntityByClassname(iEnt, EntityList[i])) != -1)
		{
			AcceptEntityInput(iEnt, "Disable");
			AcceptEntityInput(iEnt, "Kill");
		}
	}

	// PushFix by Mev, George, & Blacky
	// https://forums.alliedmods.net/showthread.php?t=267131
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "trigger_push")) != -1)
	{
		SDKHook(iEnt, SDKHook_Touch, OnTouchPushTrigger);
	}
	
	RefreshZones();

	g_bRoundEnd=false;
	return Plugin_Continue; 
}

// PushFix by Mev, George, & Blacky
// https://forums.alliedmods.net/showthread.php?t=267131
public Action OnTouchPushTrigger(int entity, int other)
{
	if(0 < other <= MaxClients && g_bTriggerPushFixEnable == true)
	{
		if (IsValidEntity(entity))
		{
			float m_vecPushDir[3];
			GetEntPropVector(entity, Prop_Data, "m_vecPushDir", m_vecPushDir);
			if (m_vecPushDir[2] == 0.0)
				return Plugin_Continue;
			else
				DoPush(entity, other, m_vecPushDir);
		}
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

// PlayerHurt 
public Action Event_OnPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bgodmode && g_Autohealing_Hp > 0)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		int remainingHeatlh = GetEventInt(event, "health");
		if (remainingHeatlh>0)
		{
			if ((remainingHeatlh+g_Autohealing_Hp) > 100)
				SetEntData(client, FindSendPropInfo("CBasePlayer", "m_iHealth"), 100);
			else
				SetEntData(client, FindSendPropInfo("CBasePlayer", "m_iHealth"), remainingHeatlh+g_Autohealing_Hp);
		}
	}
	return Plugin_Continue; 
}

// PlayerDamage (if godmode 0)
public Action Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (g_bgodmode)
		return Plugin_Handled;
	return Plugin_Continue;
}


//thx to TnTSCS (player slap stops timer)
//https://forums.alliedmods.net/showthread.php?t=233966
public Action OnLogAction(Handle source, Identity:ident, client, target, const char[] message)
{	
    if ((1 > target > MaxClients))
        return Plugin_Continue;
    if (IsValidClient(target) && IsPlayerAlive(target) && g_bTimeractivated[target] && !IsFakeClient(target))
	{
		char logtag[PLATFORM_MAX_PATH];
		if (ident == Identity_Plugin)
			GetPluginFilename(source, logtag, sizeof(logtag));
		else
			Format(logtag, sizeof(logtag), "OTHER");
		
		if ((strcmp("playercommands.smx", logtag, false) == 0) ||(strcmp("slap.smx", logtag, false) == 0))
			Client_Stop(target, 0);
	}   
    return Plugin_Continue;
}  

public Action OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	
	if (g_bRoundEnd || !IsValidClient(client))
		return Plugin_Continue;	

	if(IsPlayerAlive(client))	
	{
		RecordReplay(client, buttons, subtype, seed, impulse, weapon, angles, vel);
		if (IsFakeClient(client))
			PlayReplay(client, buttons, subtype, seed, impulse, weapon, angles, vel);

		float speed, origin[3], ang[3];
		g_CurrentButton[client] = buttons;
		GetClientAbsOrigin(client, origin);
		GetClientEyeAngles(client, ang);		

		speed = GetSpeed(client);		
		if (GetEntityFlags(client) & FL_ONGROUND)
			g_bOnGround[client]=true;
		else
			g_bOnGround[client]=false;

		if (speed < 10.0 && g_bOnGround[client]) // Not moving
		{
			if (!g_bClientStopped[client]) // Get start time
			{
				if (!IsFakeClient(client))
					////PrintToServer("Stopped");
				g_fClientLastMovement[client] = GetEngineTime();
				g_bClientStopped[client] = true;
			}
			else if (GetEngineTime() - g_fClientLastMovement[client] > BEAMLIFE)
			{
				if (!IsFakeClient(client))
					////PrintToServer("Refresh is true");
				g_bRefreshTrail[client] = true;
			}
		}
		else
		{
			if (!IsFakeClient(client))
				g_bClientStopped[client] = false;
		}

		//menu refreshing
		CheckRun(client);


		AutoBhopFunction(client, buttons);
		NoClipCheck(client);
		AttackProtection(client, buttons);
		HookCheck(client);

		// If in start zone, cap speed
		if (g_iClientInZone[client][0] == 1 && g_iClientInZone[client][2] > 0)
			LimitSpeed(client, 2);	// Bonus
		else
			if (g_iClientInZone[client][0] == 1)
				LimitSpeed(client, 0); // Normal Start
			else
				if (g_iClientInZone[client][0] == 5)
					LimitSpeed(client, 1); // Speed Start

		if (g_bOnGround[client])
		{
			g_bBeam[client] = false;
		}		
		g_fLastAngles[client] = ang;
		g_fLastSpeed[client] = speed;
		g_fLastPosition[client] = origin;
		g_LastButton[client] = buttons;

		BeamBox_OnPlayerRunCmd(client);
	}

	// Slope Boost Fix by Mev, & Blacky
	// https://forums.alliedmods.net/showthread.php?t=266888
	if(g_bSlopeFixEnable == true)
	{
		g_bLastOnGround[client] = g_bOnGroundFix[client];
		
		if (GetEntityFlags(client) & FL_ONGROUND)
			g_bOnGroundFix[client] = true;
		else
			g_bOnGroundFix[client] = false;
		
		g_vLast[client][0]    = g_vCurrent[client][0];
		g_vLast[client][1]    = g_vCurrent[client][1];
		g_vLast[client][2]    = g_vCurrent[client][2];
		g_vCurrent[client][0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
		g_vCurrent[client][1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
		g_vCurrent[client][2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
		
		// Check if player landed on the ground
		if (g_bOnGroundFix[client] == true && g_bLastOnGround[client] == false)
		{
			// Set up and do tracehull to find out if the player landed on a slope
			float vPos[3];
			GetEntPropVector(client, Prop_Data, "m_vecOrigin", vPos);

			float vMins[3];
			GetEntPropVector(client, Prop_Send, "m_vecMins", vMins);

			float vMaxs[3];
			GetEntPropVector(client, Prop_Send, "m_vecMaxs", vMaxs);

			float vEndPos[3];
			vEndPos[0] = vPos[0];
			vEndPos[1] = vPos[1];
			vEndPos[2] = vPos[2] - FindConVar("sv_maxvelocity").FloatValue;
			
			TR_TraceHullFilter(vPos, vEndPos, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceRayDontHitSelf, client);

			if(TR_DidHit())
			{
				// Gets the normal vector of the surface under the player
				float vPlane[3], vLast[3];
				TR_GetPlaneNormal(INVALID_HANDLE, vPlane);
				
				// Make sure it's not flat ground and not a surf ramp (1.0 = flat ground, < 0.7 = surf ramp)
				if(0.7 <= vPlane[2] < 1.0)
				{
					/*
					Copy the ClipVelocity function from sdk2013 
					(https://mxr.alliedmods.net/hl2sdk-sdk2013/source/game/shared/gamemovement.cpp#3145)
					With some minor changes to make it actually work
					*/
					vLast[0]  = g_vLast[client][0];
					vLast[1]  = g_vLast[client][1];
					vLast[2]  = g_vLast[client][2];
					vLast[2] -= (FindConVar("sv_gravity").FloatValue * GetTickInterval() * 0.5);
					
					float fBackOff = GetVectorDotProduct(vLast, vPlane);
						
					float change, vVel[3];
					for(int i; i < 2; i++)
					{
						change  = vPlane[i] * fBackOff;
						vVel[i] = vLast[i] - change;
					}
					
					float fAdjust = GetVectorDotProduct(vVel, vPlane);
					if(fAdjust < 0.0)
					{
						for(int i; i < 2; i++)
						{
							vVel[i] -= (vPlane[i] * fAdjust);
						}
					}
					
					vVel[2] = 0.0;
					vLast[2] = 0.0;
					
					// Make sure the player is going down a ramp by checking if they actually will gain speed from the boost
					if(GetVectorLength(vVel) > GetVectorLength(vLast))
					{
						// Teleport the player, also adds basevelocity
						if(GetEntityFlags(client) & FL_BASEVELOCITY)
						{
							float vBase[3];
							GetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", vBase);
							
							AddVectors(vVel, vBase, vVel);
						}
						
						TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);		
					}
				}
			}	
		}
	}

	return Plugin_Continue;
}

public Action Event_OnJump(Handle JumpEvent, const char[] Name, bool Broadcast)
{
	int client;
	client = GetClientOfUserId(GetEventInt(JumpEvent, "userid"));	
	g_bBeam[client]=true;
	
	//noclip check
	float  flEngineTime;
	flEngineTime = GetGameTime();
	float flDiff;
	flDiff = flEngineTime - g_fLastTimeNoClipUsed[client];
	if (flDiff < 4.0)
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Float:{0.0,0.0,-100.0});
}
		
			
public Hook_PostThinkPost(entity)
{
	SetEntProp(entity, Prop_Send, "m_bInBuyZone", 0);
} 

public Action Event_JoinTeamFailed(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;
	EJoinTeamReason m_eReason = EJoinTeamReason:GetEventInt(event, "reason");
	int m_iTs = GetTeamClientCount(CS_TEAM_T);
	int m_iCTs = GetTeamClientCount(CS_TEAM_CT);
	switch(m_eReason)
	{
		case k_OneTeamChange:
		{
			return Plugin_Continue;
		}

		case k_TeamsFull:
		{
			if(m_iCTs == g_CTSpawns && m_iTs == g_TSpawns)
				return Plugin_Continue;
		}
		case k_TTeamFull:
		{
			if(m_iTs == g_TSpawns)
				return Plugin_Continue;
		}
		case k_CTTeamFull:
		{
			if(m_iCTs == g_CTSpawns)
				return Plugin_Continue;
		}
		default:
		{
			return Plugin_Continue;
		}
	}
	ChangeClientTeam(client, g_SelectedTeam[client]);

	return Plugin_Handled;
}

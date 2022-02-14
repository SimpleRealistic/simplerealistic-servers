#pragma semicolon 1 

#define	PLUGIN_AUTHOR	"[W]atch [D]ogs"
#define PLUGIN_VERSION	"1.6.0 SCP"

#include <sourcemod> 
#include <cstrike> 
#include <clientprefs>

#undef REQUIRE_PLUGIN
#include <scp>
#define REQUIRE_PLUGIN

#include <multicolors>


Handle h_bEnable;
Handle g_hClientCookies;

char sTags[100][256];
char sFlags[100][8];
char sMode[100][32];
char sTagColors[100][32];
char sNameColors[100][32];
char sTextColors[100][32];
char sSteamIds[100][32];

int iTags = 0;

public Plugin myinfo = 
{
	name = "[CSGO/CSS] Chat/Scoreboard Tag Menu", 
	author = PLUGIN_AUTHOR, 
	description = "An advanced chat & scoreboard tag menu for players", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=299351"
};

public void OnPluginStart()
{
	LoadTranslations("TagMenu.phrases");
	
	h_bEnable = CreateConVar("sm_tagmenu_enable", "1", "Enable / Disable tag menu", _, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_tag", Command_TagMenu);
	RegConsoleCmd("sm_tags", Command_TagMenu);
	RegConsoleCmd("sm_tagmenu", Command_TagMenu);
	
	RegAdminCmd("sm_reloadtags", Command_ReloadTags, ADMFLAG_GENERIC);
	
	HookEvent("player_spawn", Event_PlayerSetTag);
	HookEvent("player_team", Event_PlayerSetTag);
	
	g_hClientCookies = RegClientCookie("Tag_Menu", "A cookie for saving clients's tags", CookieAccess_Private);
	
	LoadTagsFromFile();
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("scp"))
	{
		LogError("[TagMenu] Simple chat processor plugin not found! Chat function is disabled.");
	}
}

public Action Event_PlayerSetTag(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	SetClientTag(client);
}

public void OnClientPostAdminCheck(int client)
{
	if (AreClientCookiesCached(client))
	{
		SetClientTag(client);
	}
}

public void OnClientSettingsChanged(int client)
{
	if (AreClientCookiesCached(client))
	{
		SetClientTag(client);
	}
}

public Action Command_TagMenu(int client, int args)
{
	if (GetConVarBool(h_bEnable))
		TagMenu(client);
	else
		CReplyToCommand(client, "%t", "TagMenu_Disabled");
	
	return Plugin_Handled;
}

public Action Command_ReloadTags(int client, int args)
{
	LoadTagsFromFile();
	CReplyToCommand(client, "%t", "Tags_Reloaded");
	return Plugin_Handled;
}

public void TagMenu(int client)
{
	Handle menu = CreateMenu(MenuCallBack);
	SetMenuTitle(menu, "%t", "Menu_Title");
	
	char sDisableItem[128];
	Format(sDisableItem, sizeof(sDisableItem), "%t", "Item_Disable");
	AddMenuItem(menu, "0", sDisableItem);
	
	for (int i = 0; i < iTags; i++)
	{
		char sInfo[300];
		Format(sInfo, sizeof(sInfo), "%s_,_%s", sMode[i], sTags[i]);
		
		if (sFlags[i][0] == '\0')
		{
			if (sSteamIds[i][0] != '\0')
			{
				char sSteamID[32];
				GetClientAuthId(client, AuthId_Engine, sSteamID, sizeof(sSteamID));
				if (StrEqual(sSteamIds[i], sSteamID))
					AddMenuItem(menu, sInfo, sTags[i]);
				else
					AddMenuItem(menu, sInfo, sTags[i], ITEMDRAW_DISABLED);
			}
			else
				AddMenuItem(menu, sInfo, sTags[i]);
		}
		else
		{
			if (CheckCommandAccess(client, "", ReadFlagString(sFlags[i])))
			{
				AddMenuItem(menu, sInfo, sTags[i]);
			}
			else
				AddMenuItem(menu, sInfo, sTags[i], ITEMDRAW_DISABLED);
		}
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuCallBack(Handle menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char sItem[256], sSteamID[64];
		GetMenuItem(menu, itemNum, sItem, sizeof(sItem));
		GetClientAuthId(client, AuthId_Engine, sSteamID, sizeof(sSteamID));
		
		if (itemNum == 0)
		{
			CS_SetClientClanTag(client, "");
			SetAuthIdCookie(sSteamID, g_hClientCookies, "");
			CPrintToChat(client, "%t", "Tag_Disabled");
		}
		else
		{
			char sItems[2][256];
			ExplodeString(sItem, "_,_", sItems, 2, 256);
			
			if (StrEqual(sItems[0], "chat"))
			{
				SetAuthIdCookie(sSteamID, g_hClientCookies, sItem);
				CPrintToChat(client, "%t", "ChatTag_Enabled", sItems[1]);
			}
			else
			{
				CS_SetClientClanTag(client, sItems[1]);
				SetAuthIdCookie(sSteamID, g_hClientCookies, sItem);
				CPrintToChat(client, "%t", "Tag_Enabled", sItems[1]);
			}
		}
	}
	else if (action == MenuAction_End)CloseHandle(menu);
}

public Action OnChatMessage(int &client, Handle hRecipients, char[] sName, char[] sMessage)
{
	if(GetConVarBool(h_bEnable) && (MaxClients >= client > 0))
	{
		if(sMessage[0] == '/' || sMessage[0] == '@')
		{
			return Plugin_Continue;
		}
		
		char sCookie[300];
		GetClientCookie(client, g_hClientCookies, sCookie, sizeof(sCookie));
		
		if (sCookie[0] == '\0')
			return Plugin_Continue;
		
		char sCookies[2][256];
		ExplodeString(sCookie, "_,_", sCookies, 2, 256);
		
		if (StrEqual(sCookies[0], "scoreboard"))
			return Plugin_Continue;
		
		char sTagColor[32], sNameColor[32], sTextColor[32];
		FindTagColors(sCookies[1], sTagColor, sNameColor, sTextColor);
		
		Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", sTextColor, sMessage);
		Format(sName, MAXLENGTH_NAME, "%s%s %s%s", sTagColor, sCookies[1], sNameColor, sName);
		
		CFormatColor(sMessage, MAXLENGTH_MESSAGE);
		CFormatColor(sName, MAXLENGTH_MESSAGE);
		
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public void LoadTagsFromFile()
{
	Handle kv = CreateKeyValues("TagMenu");
	if (FileToKeyValues(kv, "addons/sourcemod/configs/tagmenu.cfg") && KvGotoFirstSubKey(kv))
	{
		iTags = 0;
		do
		{
			KvGetString(kv, "tag", sTags[iTags], 256);
			KvGetString(kv, "flag", sFlags[iTags], 8);
			KvGetString(kv, "steamid", sSteamIds[iTags], 32);
			KvGetString(kv, "tag_color", sTagColors[iTags], 32, "{default}");
			KvGetString(kv, "name_color", sNameColors[iTags], 32, "{teamcolor}");
			KvGetString(kv, "text_color", sTextColors[iTags], 32, "{default}");
			KvGetString(kv, "mode", sMode[iTags], 32, "both");
			iTags++;
		} while (KvGotoNextKey(kv));
	}
	else
	{
		SetFailState("[TagMenu] Error in parsing file tagmenu.cfg.");
	}
	CloseHandle(kv);
}

public void SetClientTag(int client)
{
	if (client < 1 || client > MaxClients || !GetConVarBool(h_bEnable) || !IsClientConnected(client) || IsFakeClient(client))
		return;
	
	char sCookie[256];
	GetClientCookie(client, g_hClientCookies, sCookie, sizeof(sCookie));
	
	if (sCookie[0] == '\0')
		return;
	
	char sCookies[2][256];
	ExplodeString(sCookie, "_,_", sCookies, 2, 256);
	
	if (!StrEqual(sCookies[0], "chat"))
	{
		char sPlayerTag[64];
		CS_GetClientClanTag(client, sPlayerTag, sizeof(sPlayerTag));
		if (!StrEqual(sPlayerTag, sCookies[1]))
		{
			CS_SetClientClanTag(client, sCookies[1]);
		}
	}
}

public void FindTagColors(char[] sTag, char[] sTagColor, char[] sNameColor, char[] sTextColor)
{
	for (int i = 0; i < iTags; i++)
	{
		if (StrEqual(sTags[i], sTag))
		{
			strcopy(sTagColor, 32, sTagColors[i]);
			strcopy(sNameColor, 32, sNameColors[i]);
			strcopy(sTextColor, 32, sTextColors[i]);
			break;
		}
	}
}
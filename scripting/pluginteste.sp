
#pragma semicolon  1
#include <sourcemod>

public Plugin:myinfo = {
    name = "Plugin Teste Velho",
    author = "@matheuseduardo",
    description = "Apenas um plugin teste para testar codificação em sourcepawn",
    version = "0.1",
    url = "https://bitbucket.org/matheuseduardo/plugin-teste"
};

new bool:g_bEnabled;
new Handle:g_cvarEnabled;


public OnPluginStart(){
    LoadTranslations("common.phrases");
    // LoadTranslations("pluginteste.phrases");
    
    g_cvarEnabled = CreateConVar("pluginteste_enabled","1","Is Plugin Teste enabled? 1 = true 0 = false",FCVAR_NONE,true,0.0,true,1.0);
    
    
    HookEventEx("player_changename", OnClientChangeName, EventHookMode_Pre);
    RegAdminCmd("sm_testecmda", TesteCmd, ADMFLAG_GENERIC, "comando testekkk1");
    
    AutoExecConfig(true, "pluginteste");
}

public OnConfigsExecuted() {
    g_bEnabled = GetConVarBool(g_cvarEnabled);
}



public Action:OnClientChangeName(Handle:event, const String:name[], bool:dontBroadcast) {
    // registrar novo nick para o usuário
    
    if(!g_bEnabled)
        return Plugin_Continue;
    
    new client = GetClientFromEvent(event);
    
    if (!IsValidPlayer(client))
        return Plugin_Continue;
        
    
}



public Action:TesteCmd(client, args){

    if(!g_bEnabled || IsValidPlayer(client)) 
        return Plugin_Handled;

    new string:name[MAX_NAME_LENGTH];
    ReplyToCommand(client, "que nome feio: %s", name);
    
}


// AUX METHODS

stock int GetClientFromEvent(Handle event) {
	return GetClientOfUserId(GetEventInt(event, "userid"));
}


stock bool IsValidClient(int client) {
    
	return (IsClientConnected(client) && IsClientInGame(client));
}

stock bool IsValidPlayer(int client) {
	return (IsValidClient(client) && !IsClientSourceTV(client) && !IsFakeClient(client));
}

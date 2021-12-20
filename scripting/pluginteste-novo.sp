
#pragma semicolon  1
#include <sourcemod>

#pragma newdecls required;

public Plugin myinfo = {
    name = "Plugin Teste Novo",
    author = "@matheuseduardo",
    description = "Apenas um plugin teste para testar codificação em sourcepawn",
    version = "1.1",
    url = "https://bitbucket.org/matheuseduardo/plugin-teste"
};

bool g_bEnabled;
Handle g_cvarEnabled;
bool DEBUGGING = false;


public void OnPluginStart(){
    
    LogDebug("carregando traduções");
    LoadTranslations("common.phrases");
    // LoadTranslations("pluginteste.phrases");
    
    LogDebug("definindo convar");
    g_cvarEnabled = CreateConVar("plugintestenovo_enabled","1","Is Plugin Teste enabled? 1 = true 0 = false",FCVAR_NONE,true,0.0,true,1.0);
    
    LogDebug("registrando evento");
    HookEvent("player_changename", OnClientChangeName, EventHookMode_Pre);
    
    LogDebug("registrando comando");
    RegAdminCmd("sm_testecmdb", TesteCmdb, ADMFLAG_GENERIC, "comando teste kkk2");
    
    LogDebug("autoexec");
    AutoExecConfig(true, "pluginteste-novo");
}

public void OnConfigsExecuted() {
    g_bEnabled = GetConVarBool(g_cvarEnabled);
    LogDebug("configurações carregadas");
}



public Action OnClientChangeName(Handle event, const char[] name, bool dontBroadcast) {
    // registrar novo nick para o usuário
    
    if(!g_bEnabled)
        return Plugin_Continue;
    
    int client = GetClientFromEvent(event);
    
    if (!IsValidPlayer(client))
        return Plugin_Continue;
    
    // ATUALIZA NOME NO SQLITE
    
    return Plugin_Continue;
    
}



public Action TesteCmdb(int client, int args){
    
    LogDebug("iniciou comando");
    
    if(!g_bEnabled || !IsValidPlayer(client)) {
        LogDebug("usuário inválido :((");
        return Plugin_Handled;
    }
    
    LogDebug("é jogador válido");
    
    char nameUser[MAX_NAME_LENGTH];
    GetClientName(client, nameUser, sizeof(nameUser));
    ReplyToCommand(client, "que nome feio: %s", nameUser);
    
    return Plugin_Continue;
}

public void LogDebug(char[] text) {
    PrintToServer("DEBUGGING! >>>>> %s", text);
}


// AUX METHODS

stock int GetClientFromEvent(Handle event) {
	return GetClientOfUserId(GetEventInt(event, "userid"));
}

stock bool IsValidClient(int client) {
    
    if (!IsClientConnected(client))
        LogDebug("cliente não conectado");
    
    if (!IsClientInGame(client))
        LogDebug("cliente não está em jogo");
    
    return (IsClientConnected(client) && IsClientInGame(client));
}

stock bool IsValidPlayer(int client) {
    
    if (IsClientSourceTV(client))
        LogDebug("é cliente sourcetv");
    
    if (IsFakeClient(client))
        LogDebug(" é cliente fake");
    
    return (IsValidClient(client) && !IsClientSourceTV(client) && !IsFakeClient(client));
}



#pragma semicolon  1
#include <sourcemod>

#pragma newdecls required;

public Plugin myinfo = {
    name = "Nicks History",
    author = "@matheuseduardo",
    description = "List last nicks used by same Steam ID",
    version = "0.9",
    url = "https://bitbucket.org/matheuseduardo/nicks-history/"
};

bool g_bEnabled;
Handle g_cvarEnabled;
bool DEBUGGING = false;
Database db;

char createTableQuery[] = "CREATE TABLE lastnicks ( "
    ... "    id           INTEGER      PRIMARY KEY AUTOINCREMENT, "
    ... "    steamid      STRING (64)  NOT NULL, "
    ... "    nickused     STRING (128) NOT NULL, "
    ... "    lasttimeused              NOT NULL "
    ...");";

char countsQuery[] = "select count(*) from lastnicks nickused = %";

char insertQuery[] = "insert into lastnicks (client, nick) values (%s, %s) ";

char updateQuery[] = "update %s set ";


public void OnPluginStart(){
    
    LogDebug("carregando traduções");
    LoadTranslations("common.phrases");
    LoadTranslations("nicks-history.phrases");
    
    LogDebug("definindo convar");
    g_cvarEnabled = CreateConVar("nickshistory_enabled","1","Is Nicks History enabled? 1 = true 0 = false", FCVAR_NONE, true, 0.0, true, 1.0);
    
    LogDebug("registrando evento");
    HookEvent("player_changename", OnClientChangeName, EventHookMode_Pre);
    
    LogDebug("registrando comando");
    RegAdminCmd("sm_testecmdb", TesteCmdb, ADMFLAG_GENERIC, "comando teste kkk2");
    
    LogDebug("autoexec");
    AutoExecConfig(true, "nicks-history");
}


public void OnConfigsExecuted() {
    g_bEnabled = GetConVarBool(g_cvarEnabled);
    LogDebug("configurações carregadas");
    
    ConectaDb();
}


public Action OnClientChangeName(Event event, const char[] name, bool dontBroadcast) {
    // registrar novo nick para o usuário
    
    LogDebug("evento mudou de nome");
    
    if(!g_bEnabled)
        return Plugin_Continue;
    
    int cliente = GetClientFromEvent(event);
    
    if (!IsValidPlayer(cliente))
        return Plugin_Continue;
    
    // obtém novo nome
    char novoNome[MAX_NAME_LENGTH];
    event.GetString("newname", novoNome, MAX_NAME_LENGTH);
    
    // obtém steam id
    char steamid[64];
    GetClientAuthId(cliente, AuthId_Steam2, steamid, strlen(steamid));
    
    char log[100];
    Format(log, strlen(log), "insere novo nick %s", novoNome);
    LogDebug(log);
    insertUpdateNewNick(steamid, novoNome);
    
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
    
    return Plugin_Changed;
}


public Action ConectaDb() {
    
    LogDebug("VAI conectar");
    
    // já conectado?
    if (db != INVALID_HANDLE) {
        LogDebug("já conectado");
        return Plugin_Continue;
    }
    
    char erroDb[256];
    
    db = SQLite_UseDatabase("nicks-history", erroDb, sizeof(erroDb));
    
    // falhou conexão?
    if (db == null) {
        LogDebug("não conectou");
        PrintToServer("Could not connect: %s", erroDb);
        SetFailState(erroDb);
    }
    
    return Plugin_Handled;
}

public void insertUpdateNewNick(char steamId[64], char novoNome[MAX_NAME_LENGTH]) {
    
    // verifica se já consta na base
    
    // se não, insere na tabela de usuário
    
    // caminho comum (sim ou não) insere histórico do nick
    
}


public void LogDebug(char[] text) {
    PrintToServer("DEBUGGING! >>>>> %s", text);
}


// AUX METHODS

stock int GetClientFromEvent(Event event) {
	return GetClientOfUserId(event.GetInt("userid"));
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


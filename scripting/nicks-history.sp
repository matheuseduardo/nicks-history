
#pragma semicolon  1
#include <sourcemod>

#pragma newdecls required;

public Plugin myinfo = {
    name = "Nicks History",
    author = "@matheuseduardo",
    description = "List last nicks used by same Steam ID",
    version = "0.10",
    url = "https://bitbucket.org/matheuseduardo/nicks-history/"
};

bool g_bEnabled;
Handle g_cvarEnabled;
bool DEBUGGING = false;
Database db;

char createTableQuery[] = "CREATE TABLE IF NOT EXISTS `lastnicks` ( "
    ... "    id        INTEGER      PRIMARY KEY AUTOINCREMENT, "
    ... "    steamid   STRING (64)  NOT NULL, "
    ... "    nick      STRING (128) NOT NULL, "
    ... "    lasttime  NUMERIC      NOT NULL "
    ...");";

// query para verificar a existência
char countQuery[] = "select count(*) from lastnicks where steamid = '%s' and nick = '%s'";

// query para inserir registros
char insertQuery[] = "insert into lastnicks (steamid, nick, lasttime) values ('%s', '%s', strftime('%%s','now')) ";

// query para atualizar se já existir
char updateQuery[] = "update lastnicks set lasttime = strftime('%%s','now') where steamid = '%s' and nick = '%s'";


public void OnPluginStart(){
    
    LogDebug("carregando traduções");
    LoadTranslations("common.phrases");
    LoadTranslations("nicks-history.phrases");
    
    LogDebug("definindo convar");
    g_cvarEnabled = CreateConVar("nickshistory_enabled","1","Is Nicks History enabled? 1 = true 0 = false", FCVAR_NONE, true, 0.0, true, 1.0);
    
    LogDebug("registrando evento");
    HookEvent("player_changename", OnClientChangeName, EventHookMode_Pre);
    
    LogDebug("registrando comandos");
    RegAdminCmd("sm_testecmdb", TesteCmdb, ADMFLAG_GENERIC, "comando teste kkk2");
    RegAdminCmd("sm_nickshistory_purge", PurgeHistory, ADMFLAG_GENERIC, "comando teste kkk2");
    
    LogDebug("autoexec");
    AutoExecConfig(true, "nicks-history");
}


public void OnConfigsExecuted() {
    g_bEnabled = GetConVarBool(g_cvarEnabled);
    LogDebug("------- > OnConfigsExecuted");
    
    ConectaDb();
    LogDebug("configurações carregadas");
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
    GetClientAuthId(cliente, AuthId_Steam2, steamid, sizeof(steamid));
    
    char log[100];
    Format(log, sizeof(log), "insere novo nick %s", novoNome);
    LogDebug(log);
    insertUpdateNewNick(steamid, novoNome);
    
    return Plugin_Continue;
}


public void OnClientAuthorized(int client, const char[] auth) {
    
    char texto[255];
    FormatEx(texto, sizeof(texto), "autorizado: %s", auth);
    LogDebug(texto);
    
    char nome[MAX_NAME_LENGTH];
    GetClientName(client, nome, sizeof(nome));
    
    Format(texto, sizeof(texto), "nome conectado: %s", nome);
    LogDebug(texto);
    
    insertUpdateNewNick(auth, nome);
    
    
    LogDebug("OnClientAuthorized");
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


public Action PurgeHistory(int client, int args){
    
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
    
    LogDebug("ConectaDb");
    
    // já conectado?
    if (db != INVALID_HANDLE) {
        LogDebug("já conectado");
        return Plugin_Continue;
    }
    
    char erroDb[255];
    
    db = SQLite_UseDatabase("nicks-history", erroDb, sizeof(erroDb));
    
    // falhou conexão?
    if (db == null) {
        LogDebug("não conectou");
        PrintToServer("Could not connect: %s", erroDb);
        SetFailState(erroDb);
    }
    
    LogDebug("db conectado");
    
    
    if (!SQL_FastQuery(db, createTableQuery)) {
        SQL_GetError(db, erroDb, sizeof(erroDb));
        PrintToServer("Could create table: %s", erroDb);
        SetFailState(erroDb);
    }
    
    LogDebug("tabela criada!");
    
    return Plugin_Handled;
}


public void insertUpdateNewNick(const char[] steamId, char novoNome[MAX_NAME_LENGTH]) {
    
    char escName[MAX_NAME_LENGTH*2+1];
    db.Escape(novoNome, escName, sizeof(escName));
    
    char query[200];
    char texto[255];
    char error[255];
    
    Format(query, sizeof(query), countQuery, steamId, escName);
    DBResultSet rs = SQL_Query(db, query);
    
    if (rs == INVALID_HANDLE || rs == null) {
        SQL_GetError(db, error, sizeof(error));
        PrintToServer("Failed to query (error: %s)", error);
        return;
    }
    
    SQL_FetchRow(rs);
    int count = SQL_FetchInt(rs, 0);
    
    FormatEx(texto, sizeof(texto), "registros encontrados: %i", count);
    LogDebug(texto);
    
    bool execOk;
    
    if (count == 0) {
        LogDebug("INSERE REGISTRO");
        Format(query, sizeof(query), insertQuery, steamId, escName);
        execOk = SQL_FastQuery(db, query);
    }
    else if (count >= 1) {
        LogDebug("ATUALIZA REGISTRO");
        Format(query, sizeof(query), updateQuery, steamId, escName);
        execOk = SQL_FastQuery(db, query);
    }
    
    if (!execOk) {
        SQL_GetError(db, error, sizeof(error));
        PrintToServer("Failed to query (error: %s)", error);
        return;
    }
    
    LogDebug(query);
    LogDebug("ok - fim da função!");
    
}


public void LogDebug(char[] text, any ...) {
    PrintToServer("DEBUGGING! >>> nickshistory >>> %s", text);
}


// AUX METHODS

stock void GetPluginBasename(Handle plugin, char[] buffer,int maxlength)
{
    GetPluginFilename(plugin, buffer, maxlength);

    int check = -1;
    if ((check = FindCharInString(buffer, '/', true)) != -1 ||
        (check = FindCharInString(buffer, '\\', true)) != -1)
    {
        Format(buffer, maxlength, "%s", buffer[check+1]);
    }
}

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


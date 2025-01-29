#pragma semicolon  1
#include <sourcemod>

#pragma newdecls required;

public Plugin myinfo = {
    name = "Nicks History",
    author = "@matheuseduardo",
    description = "List last nicks used by same Steam ID",
    version = "0.2",
    url = "https://bitbucket.org/matheuseduardo/nicks-history/"
};

// global variables
bool g_bEnabled;
Handle g_cvarEnabled;
ConVar g_cvarDebug;
ConVar g_cvarMaxRecords;
Database g_db;

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

// query para excluir e limpar todos
char deleteQuery[] = "DELETE FROM lastnicks WHERE steamid = '%s'";

// query para excluir e limpar registros antigos
char excluiAntigos[] = "DELETE FROM lastnicks WHERE id NOT IN (SELECT id FROM lastnicks WHERE steamid = '%s' ORDER BY lasttime DESC LIMIT %d)";

// query para selecionar os últimos nicks
char listNicksQuery[] = "select id, nick, strftime('%%s','now')-lasttime as tempo from lastnicks where steamid = '%s' order by 3 asc";


public void OnPluginStart(){
    g_cvarDebug = CreateConVar("nickshistory_debug", "0", "Ativar logs de depuração? 1 = Sim, 0 = Não", FCVAR_NONE, true, 0.0, true, 1.0);
    
    if (g_cvarDebug)
        PrintToServer("DEBUG HABILITADO");

    LogDebug("carregando traduções");
    LoadTranslations("common.phrases");
    LoadTranslations("nicks-history.phrases");
    
    LogDebug("definindo convar");
    g_cvarEnabled = CreateConVar("nickshistory_enabled","1","Is Nicks History enabled? 1 = true 0 = false", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvarMaxRecords = CreateConVar("nickshistory_maxrecords", "50", "Número máximo de registros por jogador. Se definido '0', fica sem limites Padrão: 50.", FCVAR_NONE, true, 1.0);
    
    LogDebug("registrando evento");
    HookEvent("player_changename", OnClientChangeName, EventHookMode_Pre);
    
    LogDebug("registrando comandos");
    RegAdminCmd("sm_nickshistory_purge", PurgeHistory, ADMFLAG_GENERIC, "deletar da base algum nick");
    RegAdminCmd("sm_nickshistory_list", NicksHistoryList, ADMFLAG_GENERIC, "lista no console últimos nicks utilizado pela pessoa");
    
    LogDebug("autoexec");
    AutoExecConfig(true, "nicks-history");
}


public void OnConfigsExecuted() {
    g_bEnabled = GetConVarBool(g_cvarEnabled);
    LogDebug("OnConfigsExecuted");
    
    ConectaDb();
    LogDebug("configurações carregadas");
}


public Action OnClientChangeName(Event event, const char[] name, bool dontBroadcast) {
    if(!g_bEnabled)
        return Plugin_Handled;
    
    int cliente = GetClientFromEvent(event);
    
    if (!IsValidPlayer(cliente))
        return Plugin_Handled;
    
    // obtém novo nome
    char novoNome[MAX_NAME_LENGTH], oldName[MAX_NAME_LENGTH];
    event.GetString("newname", novoNome, MAX_NAME_LENGTH);
    event.GetString("oldname", oldName, MAX_NAME_LENGTH);
    
    // obtém steam id
    char steamid[64];
    GetClientAuthId(cliente, AuthId_Steam2, steamid, sizeof(steamid));
    
    insertUpdateNewNick(steamid, oldName);
    insertUpdateNewNick(steamid, novoNome);
    
    return Plugin_Handled;
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


public void OnClientDisconnect(int client) {
    if (!IsValidPlayer(client))
        return;
    
    // obtém novo nome
    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    
    // obtém steam id
    char steamid[64];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
    
    insertUpdateNewNick(steamid, name);
}


public Action NicksHistoryList(int client, int args){
    
    LogDebug("iniciou comando nicks-history-list");
    
    if (args < 1)
	{
		ReplyToCommand(client,"[SM] Usage: sm_nickshistory_list <target>");
		return Plugin_Handled;
	}
    
    char nome[MAX_NAME_LENGTH];
    GetCmdArg(1, nome, sizeof(nome));
    
    int cl1 = FindTarget(client, nome, true);
    
    if (cl1 == -1) {
        ReplyToCommand(client, "Client not found for %s", nome);
        return Plugin_Handled;
    }
    
    char steamId[64];
    GetClientAuthId(cl1, AuthId_Steam2, steamId, sizeof(steamId));
    
    char nameUser[MAX_NAME_LENGTH];
    GetClientName(cl1, nameUser, sizeof(nameUser));
    
    char query[200];
    char error[255];
    
    Format(query, sizeof(query), listNicksQuery, steamId);
    DBResultSet rs = SQL_Query(g_db, query);
    
    LogDebug(query);
    
    if (rs == INVALID_HANDLE || rs == null) {
        LogDebug("deu erro");
        SQL_GetError(g_db, error, sizeof(error));
        PrintToServer("Failed to query (error: %s)", error);
        delete rs;
        return Plugin_Handled;
    }
    
    if (rs.RowCount <= 0) {
        ReplyToCommand(client, "Nenhum registro encontrado para %s", nome);
    } else {
        ReplyToCommand(client, "Abra o console para verificar os registros");
    }
    
    char nick[MAX_NAME_LENGTH];
    int lastTime, count;
    
    count = 0;
    
    while(rs.FetchRow()) {
        count++;
        
        rs.FetchString(1, nick, sizeof(nick));
        lastTime = rs.FetchInt(2);
        
        char quantoTempo[100];
        FormatTimeFromSeconds(lastTime, quantoTempo);
        
        PrintToConsole(client, "%i. %s  --  %s", count, nick, quantoTempo);
    }
    
    delete rs;
    
    return Plugin_Handled;
}


public Action PurgeHistory(int client, int args) {
    LogDebug("iniciou comando nicks-history-purge");

    // Verifica se o plugin está habilitado e se o cliente é válido
    if (!g_bEnabled || !IsValidPlayer(client)) {
        LogDebug("Plugin desabilitado ou usuário inválido");
        ReplyToCommand(client, "[SM] O plugin está desabilitado ou você não é um jogador válido.");
        return Plugin_Handled;
    }

    // Verifica se o comando foi usado corretamente
    if (args < 1) {
        ReplyToCommand(client, "[SM] Uso: sm_nickshistory_purge <target>");
        return Plugin_Handled;
    }

    // Obtém o nome do alvo
    char nome[MAX_NAME_LENGTH];
    GetCmdArg(1, nome, sizeof(nome));

    // Encontra o jogador alvo
    int target = FindTarget(client, nome, true, false);

    if (target == -1) {
        ReplyToCommand(client, "[SM] Jogador não encontrado.");
        return Plugin_Handled;
    }

    // Obtém o Steam ID do jogador alvo
    char steamId[64];
    GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

    // Prepara a query para deletar os registros do jogador
    char query[200];
    char error[255];
    Format(query, sizeof(query), deleteQuery, steamId);

    // Executa a query
    if (!SQL_FastQuery(g_db, query)) {
        SQL_GetError(g_db, error, sizeof(error));
        PrintToServer("Falha ao executar a query (erro: %s)", error);
        ReplyToCommand(client, "[SM] Falha ao limpar o histórico de nicks.");
        return Plugin_Handled;
    }

    // Informa o administrador que o histórico foi limpo
    char nameUser[MAX_NAME_LENGTH];
    GetClientName(target, nameUser, sizeof(nameUser));
    ReplyToCommand(client, "[SM] Histórico de nicks de %s foi limpo com sucesso.", nameUser);

    LogDebug("Histórico de nicks limpo para o Steam ID: %s", steamId);

    return Plugin_Handled;
}


public Action ConectaDb() {
    
    LogDebug("ConectaDb");
    
    // já conectado?
    if (g_db != INVALID_HANDLE) {
        LogDebug("já conectado");
        return Plugin_Continue;
    }
    
    char erroDb[255];
    
    g_db = SQLite_UseDatabase("nicks-history", erroDb, sizeof(erroDb));
    
    // falhou conexão?
    if (g_db == null) {
        LogDebug("não conectou");
        PrintToServer("Could not connect: %s", erroDb);
        SetFailState(erroDb);
    }
    
    LogDebug("db conectado");
    
    
    if (!SQL_FastQuery(g_db, createTableQuery)) {
        SQL_GetError(g_db, erroDb, sizeof(erroDb));
        PrintToServer("Could create table: %s", erroDb);
        SetFailState(erroDb);
    }
    
    LogDebug("tabela criada!");
    
    return Plugin_Handled;
}


public void insertUpdateNewNick(const char[] steamId, char novoNome[MAX_NAME_LENGTH]) {
    
    char escName[MAX_NAME_LENGTH*2+1];
    g_db.Escape(novoNome, escName, sizeof(escName));

    if (strlen(novoNome) == 0) {
        LogDebug("Nome vazio, ignorando inserção.");
        return;
    }
    
    char query[200];
    char texto[255];
    char error[255];
    
    Format(query, sizeof(query), countQuery, steamId, escName);
    DBResultSet rs = SQL_Query(g_db, query);
    
    if (rs == INVALID_HANDLE || rs == null) {
        SQL_GetError(g_db, error, sizeof(error));
        PrintToServer("Failed to query (error: %s)", error);
        return;
    }
    
    SQL_FetchRow(rs);
    int count = SQL_FetchInt(rs, 0);
    
    FormatEx(texto, sizeof(texto), "registros encontrados: %i", count);
    LogDebug(texto);
    
    delete rs;
    
    if (!IsValidSteamID(steamId)) {
        LogDebug("Steam ID inválido: %s", steamId);
        return;
    }
    
    bool execOk;
    
    if (count == 0) {
        LogDebug("INSERE REGISTRO");
        Format(query, sizeof(query), insertQuery, steamId, escName);
        execOk = SQL_FastQuery(g_db, query);
    }
    else if (count >= 1) {
        LogDebug("ATUALIZA REGISTRO");
        Format(query, sizeof(query), updateQuery, steamId, escName);
        execOk = SQL_FastQuery(g_db, query);
    }
    
    if (!execOk) {
        SQL_GetError(g_db, error, sizeof(error));
        PrintToServer("Failed to query (error: %s)", error);
        return;
    }

    int maximoRegistros = GetConVarInt(g_cvarMaxRecords);

    // Verificar e excluir registros antigos
    if (maximoRegistros > 0) {
        Format(query, sizeof(query), excluiAntigos, steamId, maximoRegistros);
        SQL_FastQuery(g_db, query);
    }
    
    
    LogDebug(query);
    LogDebug("ok - fim da função!");
    
}


public void LogDebug(char[] text, any ...) {
    if (!GetConVarBool(g_cvarDebug)) return;
    char buffer[255];
    VFormat(buffer, sizeof(buffer), text, 2);
    PrintToServer("DEBUGGING! >>> nickshistory >>> %s", buffer);
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
    
    return (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client));
}

stock void FormatTimeFromSeconds(int iSeconds, char segundosFormatados[100]) {
    int iDays = iSeconds / 86400;
    int iHours = iSeconds % 86400 / 3600;
    int iMins = iSeconds % 3600 / 60;
    int iSecs = iSeconds % 60;

    if (iDays > 0) {
        Format(segundosFormatados, sizeof(segundosFormatados), "%02d dias, %02d horas, %02d minutos e %02d segundos atrás", iDays, iHours, iMins, iSecs);
    } else if (iHours > 0) {
        Format(segundosFormatados, sizeof(segundosFormatados), "%02d horas, %02d minutos e %02d segundos atrás", iHours, iMins, iSecs);
    } else if (iMins > 0) {
        Format(segundosFormatados, sizeof(segundosFormatados), "%02d minutos e %02d segundos atrás", iMins, iSecs);
    } else {
        Format(segundosFormatados, sizeof(segundosFormatados), "%02d segundos atrás", iSecs);
    }
}

stock bool IsValidSteamID(const char[] steamId) {
    return (strlen(steamId) > 0 && StrContains(steamId, "STEAM_") == 0);
}

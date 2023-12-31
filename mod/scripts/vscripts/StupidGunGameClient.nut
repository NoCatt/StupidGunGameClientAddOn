
// Contains data about a custom scoreboard column data.
global struct ScoreboardColumnData
{
    // The title of the custom scoreboard column.
    string title
    // A valid PlayerGameStat (PGS) constant value (PGS_ASSAULT_SCORE, PGS_KILLS etc.).
    int scoreType
    // The maximum amount of digits this column can hold.  Determines the width of the column.
    int digits
}

global function Shared_GetCustomScoreboardColumns

#if CLIENT
global function Client_CustomScoreboardColumns_Init
#endif

#if SERVER
global function Server_CustomScoreboardColumns_Init
global function Server_AddCustomScoreboardColumn
#endif

// Currently tracked custom scoreboard columns added by the server.
array<ScoreboardColumnData> CustomScoreboardColumns

// Returns the custom scoreboard columns defined by the server.
array<ScoreboardColumnData> function Shared_GetCustomScoreboardColumns()
{
    return CustomScoreboardColumns
}

#if CLIENT
void function Client_CustomScoreboardColumns_Init()
{
    AddServerToClientStringCommandCallback( "AddCustomScoreboardColumn", ServerCallback_AddCustomScoreboardColumn )
    printt("custom colums init")
}

void function ServerCallback_AddCustomScoreboardColumn( array<string> args )
{
    if (args.len() != 3)
    {
        printt(format("Warning: received invalid AddCustomScoreboardColumn command with %i arguments.", args.len()))
        return
    }

    ScoreboardColumnData newColumn = { ... }
    newColumn.title = StringReplace(args[0], "\b", " ", true)
    newColumn.scoreType = args[1].tointeger()
    newColumn.digits = args[2].tointeger()

    CustomScoreboardColumns.append(newColumn)

    GameMode_AddScoreboardColumnData(GAMETYPE, newColumn.title, newColumn.scoreType, newColumn.digits)
}
#endif //CLIENT

#if SERVER
void function Server_CustomScoreboardColumns_Init()
{
    AddCallback_OnClientConnected( SendCustomScoreboardColumnsToPlayer )
}

/**
 * Adds a custom scoreboard column and transmits it to all players.
 * Any player that connects will receive it as well.
 * @param title The title of the custom scoreboard column.
 * @param scoreType A valid PlayerGameStat (PGS) constant value (PGS_ASSAULT_SCORE, PGS_KILLS etc.).
 * @param digits The maximum amount of digits this column can hold. Determines the width of the column.
 */
void function Server_AddCustomScoreboardColumn(string title, int scoreType, int digits)
{
    // Limit of four scoreboard columns, else it'll break it entirely.
    if (GameMode_GetScoreboardColumnTitles(GAMETYPE).len() + CustomScoreboardColumns.len() >= 4)
    {
        throw "Cannot have more than 4 scoreboard columns."
    }

    string sanitized = strip(title)
    if (sanitized.len() == 0)
    {
        throw "Cannot have an empty scoreboard column title."
    }

    // Keep track of the custom scoreboard column for players that join mid-game.
    ScoreboardColumnData newColumn = { ... }
    newColumn.title = sanitized
    newColumn.scoreType = scoreType
    newColumn.digits = digits

    CustomScoreboardColumns.append(newColumn)

    string cmd = BuildScoreboardStringCommand(newColumn)
    printt(cmd)
    foreach(entity player in GetPlayerArray())
    {
        ServerToClientStringCommand(player, cmd)
    }
}

//adds all the registered columns when a player connects
void function SendCustomScoreboardColumnsToPlayer(entity player)
{
    foreach(ScoreboardColumnData data in CustomScoreboardColumns)
    {
        string cmd = BuildScoreboardStringCommand(data)
        ServerToClientStringCommand(player, cmd)
    }
}

// Helper function to build the string command used to send a custom scoreboard column.
string function BuildScoreboardStringCommand(ScoreboardColumnData data)
{
    // Replace spaces with backspaces so they arrive as one argument instead of splitting.
    // Nobody's going to use those anyway, should be fine.
    string sanitizedName = StringReplace(data.title, " ", "\b", true)
    return format("AddCustomScoreboardColumn %s %i %i", sanitizedName, data.scoreType, data.digits)
}
#endif //SERVER
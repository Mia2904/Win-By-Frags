#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <sqlx>

#define VERSION "0.4.2"

new g_firstleader, g_secondleader, g_thirdleader, g_winner;
new g_votemap, g_leaderfrags, g_maxfrags;
new g_connected, g_maxplayers;
new Handle:g_dbtuple, g_totalranked, g_playerrank[33], g_playervictories[33];

new g_playername[32][32]
#define player_name(%0) (g_playername[%0-1])
new cvar_maxfrags, cvar_maxfragsplayers, cvar_enable, cvar_lastfrags, cvar_winnertime, cvar_steal, cvar_suicide;
#define is_player_connected(%0)	(g_connected & (1 << %0-1))
#define ent_is_player(%0,%1) (1 <= %0 <= %1)

enum (+= 111)
{
	TASK_SHOWFRAGS = 987,
	TASK_SHOWLEADER
};

new g_motd[1500], g_music;

new const WIN_MUSIC[][] =
{
	"media/Half-Life03.mp3",
	"media/Half-Life11.mp3",
	"media/Half-Life12.mp3",
	"media/Half-Life13.mp3",
	"media/Half-Life17.mp3"
};

public plugin_precache()
{
	precache_sound("gungame/gg_brass_bell.wav");
	precache_sound("wbf/box_ring.wav");
	
	g_music = random(sizeof WIN_MUSIC);
	precache_generic(WIN_MUSIC[g_music]);
}

public plugin_init()
{
	register_plugin("Win by Frags", VERSION, "Mario AR.");
	
	register_event("DeathMsg", "RegisterDeath", "a");
	
	register_clcmd("say /top", "clcmd_saytop");
	register_clcmd("say_team /top", "clcmd_saytop");
	register_clcmd("say /top10", "clcmd_saytop");
	register_clcmd("say_team /top10", "clcmd_saytop");
	register_clcmd("say /top15", "clcmd_saytop");
	register_clcmd("say_team /top15", "clcmd_saytop");
	register_clcmd("say /rank", "clcmd_sayrank");
	register_clcmd("say_team /rank", "clcmd_sayrank");
	//register_clcmd("say /top15", "clcmd_saytop");
	//register_clcmd("say_team /top15", "clcmd_saytop");
	
	cvar_maxfrags = register_cvar("wbf_max_frags", "20");
	cvar_maxfragsplayers = register_cvar("wbf_max_frags_players", "4");
	cvar_enable = register_cvar("wbf_enable", "1");
	cvar_winnertime = register_cvar("wbf_winner_time", "10");
	cvar_lastfrags = register_cvar("wbf_frags_left_to_vote", "10");
	cvar_steal = register_cvar("wbf_knife_steal", "1");
	cvar_suicide = register_cvar("wbf_penalty", "0");
	
	set_task(3.0, "StartTasks");
	
	g_maxplayers = get_maxplayers();
	
	create_top10();
}

public plugin_cfg()
{
	g_maxfrags = get_pcvar_num(cvar_maxfrags);
}

public clcmd_saytop(id)
{
	show_motd(id, g_motd, "Win by Frags - Top 10");
}

public clcmd_sayrank(id)
{
	colored_print(id, "^x04[WbF]^x01 Tu rank es^x04 %d^x01/^x04%d^x01 con^x03 %d^x01 victorias.", g_playerrank[id], g_totalranked, g_playervictories[id]);
}

create_top10()
{
	new get_type[12];
	SQL_SetAffinity("sqlite");
	SQL_GetAffinity(get_type, sizeof(get_type));

	if (!equali(get_type, "sqlite"))
	{
		set_fail_state("Error en la conexion");
		return;
	}
	
	g_dbtuple = SQL_MakeDbTuple("", "", "", "WinByFrags")
	
	new errcode, error[10], Handle:query, Handle:connection = SQL_Connect(g_dbtuple, errcode, error, charsmax(error))
	
	query = SQL_PrepareQuery(connection, "SELECT COUNT(*) FROM WinByFrags");
	SQL_Execute(query);
	g_totalranked = SQL_ReadResult(query, 0);
	
	query = SQL_PrepareQuery(connection, "SELECT Nombre, Victorias FROM WinByFrags ORDER BY Victorias DESC LIMIT 10");
	SQL_Execute(query);
	
	new num;
	if ((num = SQL_NumResults(query)))
	{
		new len = formatex(g_motd, charsmax(g_motd), "<html><style type=^"text/css^">\
		body {background-color:#000000;}\
		.hea {background-color:#BBDEFA;color:#000000;font-family:Tahoma,Arial;}\
		.top {color:#FFFFFF;font-family:Tahoma,Arial;}\
		</style><body><br><br><table style=top align=center border=1 width=90%%>");
		
		len += formatex(g_motd[len], charsmax(g_motd)-len,
		"<tr><td class=hea width=10%% align=center><strong>Rank</strong></td>\
		<td class=hea width=76%%><strong>Jugador</strong></td>\
		<td class=hea width=14%% align=center><strong>Victorias</strong></td></tr>");
		
		new name[32], victories;
		for (new i = 0; i < num; i++)
		{
			SQL_ReadResult(query, 0, name, 31);
			victories = SQL_ReadResult(query, 1);
			
			len += formatex(g_motd[len], charsmax(g_motd)-len,
			"<tr><td class=top align=center>%d</td>\
			<td class=top>%s</td>\
			<td class=top align=center>%d</td>", i+1, name, victories);
			
			if (i+1 < num)
				SQL_NextRow(query);
		}
	
		add(g_motd, charsmax(g_motd), "</table></body></html>");
	}
	
	SQL_FreeHandle(query)
	SQL_FreeHandle(connection)
}

public client_putinserver(id)
{
	if(!get_pcvar_num(cvar_enable))
		return;
	
	get_user_name(id, player_name(id), 31);
	g_connected |= (1 << id-1)
	
	if(!is_user_bot(id))
	{
		set_task(3.0, "ShowFrags", id + TASK_SHOWFRAGS);
		set_task(3.0, "ShowTheLeader", id + TASK_SHOWLEADER);
	
		static szQuery[80], data[1];
		data[0] = id;
		formatex(szQuery, charsmax(szQuery), "SELECT Victorias AS Wins FROM WinByFrags WHERE Nombre='%s'", player_name(id));
		SQL_ThreadQuery(g_dbtuple, "load_victories", szQuery, data, 1);
	}
}

public load_victories(failstate, Handle:query, error[], errcode, data[], datasize, Float:_time)
{
	new id = data[0];
	if (is_user_connected(id) && SQL_NumResults(query))
	{
		g_playervictories[id] = SQL_ReadResult(query, 0);
		
		static szQuery[80];
		formatex(szQuery, charsmax(szQuery), "SELECT (COUNT(*) + 1) FROM WinByFrags WHERE Victorias > %d", g_playervictories[id]);
		SQL_ThreadQuery(g_dbtuple, "load_rank", szQuery, data, 1);
	}
}

public load_rank(failstate, Handle:query, error[], errcode, data[], datasize, Float:_time)
{
	new id = data[0];
	if (is_user_connected(id) && SQL_NumResults(query))
	{
		g_playerrank[id] = SQL_ReadResult(query, 0);
		set_task(10.0, "welcome_message", id);
	}
}

public welcome_message(id)
{
	if (is_user_connected(id))
	{
		new name[32];
		get_user_name(id, name, 31);
		colored_print(id, "^x04[WbF]^x01 Bienvenido,^x03 %s^x01! Tu rank es^x04 %d^x01/^x04%d^x01 con^x03 %d^x01 victorias.", name, g_playerrank[id], g_totalranked, g_playervictories[id]);	
	}
}

public client_disconnect(id)
{
	if(!get_pcvar_num(cvar_enable))
		return;
	
	if(task_exists(id + TASK_SHOWLEADER))
		remove_task(id + TASK_SHOWLEADER);
		
	if(task_exists(id + TASK_SHOWFRAGS))
		remove_task(id + TASK_SHOWFRAGS);
	
	g_connected &= ~(1 << id-1)
}

public client_infochanged(id)
{
	if (!is_player_connected(id))
		return;
	
	get_user_info(id, "name", player_name(id), 31);
}

public StartTasks()
{
	if(!get_pcvar_num(cvar_enable))
		return;
	
	set_cvar_num("mp_timelimit", 0);
	
	GetTheLeader();
}

public ShowFrags(id)
{
	id -= TASK_SHOWFRAGS
	
	if(!is_player_connected(id))
		return;
	
	static Frags
	Frags = get_user_frags(id);
	
	if(!g_winner)
	{
		set_hudmessage(255, 255, 255, -1.0, 0.84, 0, 0.0, 1.1, 0.0, 0.0, 4);
		show_hudmessage(id, "Tienes %i frags.^nNecesitas %i para ganar.", Frags, g_maxfrags);
	}
	/*else if(g_winner != id)
	{
		set_hudmessage(255, 255, 255, -1.0, 0.43, 0, 0.0, 1.1, 0.0, 0.0, 3);
		show_hudmessage(id, "El ganador es %s!^nSu ultima victima fue %s^nFelicitaciones, %s!^n^nTe faltaron %d frags para ganar.^nMas suerte la proxima vez!^n^nCambio de mapa en %d segundos.",
		player_name(g_winner), player_name(g_secondleader), player_name(g_winner), get_pcvar_num(cvar_maxfrags) - Frags, g_firstleader);
	}*/
	else
	{
		set_hudmessage(255, 255, 255, -1.0, -1.0, 0, 0.0, 1.1, 0.0, 0.0, 3);
		show_hudmessage(id, "Cambio de mapa en %d segundos.", g_firstleader);
	}
	
	set_task(1.0, "ShowFrags", id + TASK_SHOWFRAGS);
}

public GetTheLeader()
{
	if(g_winner)
		return;
	
	static frags[33], i
	
	g_leaderfrags = -99 // BUGFIX
	g_secondleader = g_thirdleader = 0
	
	for(i = 1; i <= g_maxplayers; i++)
	{
		if(!is_player_connected(i)) continue;
		
		frags[i] = get_user_frags(i)
		
		if(frags[i] > g_leaderfrags)
		{
			g_firstleader = i
			g_leaderfrags = frags[i];
		}
	}
	
	for(i = 1; i <= g_maxplayers; i++)
	{
		if(!is_player_connected(i) || i == g_firstleader) continue;
		
		if(frags[i] == g_leaderfrags)
		{
			if(!g_secondleader)
				g_secondleader = i
			else if(!g_thirdleader)
			{
				g_thirdleader = i
				break;
			}
		}
	}
	
	set_task(0.2, "GetTheLeader");
}

public ShowTheLeader(id)
{
	id -= TASK_SHOWLEADER
	
	if(!is_player_connected(id))
		return;
	
	set_hudmessage(255, 255, 255, -1.0, 0.12, 0, 0.0, 1.1, 0.0, 0.0, 3);
		
	static frags; frags = get_user_frags(id);
	
	if(!g_secondleader)
	{
		if(g_firstleader == id)
			show_hudmessage(id, "Eres el unico lider.");
		else
			show_hudmessage(id, "Lider: %s con %d frags.^nEstas a %i frags de alcanzarlo.", player_name(g_firstleader), g_leaderfrags, g_leaderfrags - frags);
	}
	else if(!g_thirdleader)
	{
		if(frags == g_leaderfrags)
			show_hudmessage(id, "Eres el lider y compartes el titulo con:^n%s", player_name((id == g_firstleader) ? g_secondleader : g_firstleader));
		else
			show_hudmessage(id, "Lideres: %s y %s con %d frags.^nEstas a %d frags de alcanzarlos.", player_name(g_firstleader), player_name(g_secondleader), g_leaderfrags, g_leaderfrags - frags);
	}
	else
	{
		if(frags == g_leaderfrags)
		{
			if(id == g_firstleader)
				show_hudmessage(id, "Eres el lider y compartes el titulo con:^n%s y %s", player_name(g_secondleader), player_name(g_thirdleader));
			else if(id == g_secondleader)
				show_hudmessage(id, "Eres el lider y compartes el titulo con:^n%s y %s", player_name(g_firstleader), player_name(g_thirdleader));
			else
				show_hudmessage(id, "Eres el lider y compartes el titulo con:^n%s y %s", player_name(g_firstleader), player_name(g_secondleader));
		}
		else
			show_hudmessage(id, "Lideres: %s, %s y %s con %d frags.^nEstas a %d frags de alcanzarlos.", player_name(g_firstleader), player_name(g_secondleader), player_name(g_thirdleader), g_leaderfrags, g_leaderfrags - frags);
	}
	
	if(!g_winner)
		set_task(1.0, "ShowTheLeader", id + TASK_SHOWLEADER);
}

public RegisterDeath()
{
	if(!get_pcvar_num(cvar_enable) || g_winner)
		return;
	
	static maxfrags, ttnum, ctnum, players[32];
	get_players(players, ttnum, "eh", "TERRORIST");
	get_players(players, ctnum, "eh", "CT");
	maxfrags = (1 + ((ttnum + ctnum - 1) / get_pcvar_num(cvar_maxfragsplayers))) * get_pcvar_num(cvar_maxfrags);
	
	if (maxfrags > g_maxfrags)
		g_maxfrags = maxfrags;
	
	static id, vic;
	id = read_data(1);	
	vic = read_data(2);
	
	static weapon[3], steal, frags;
	
	if(id == vic || !ent_is_player(id, g_maxplayers))
	{
		if ((frags = get_pcvar_num(cvar_suicide)))
		{
			if (frags > 1)
				set_user_frags(vic, get_user_frags(vic)+1-frags);
			
			client_print(vic, print_chat, "Pierdes %d fra%s por suicidio.", frags, frags > 1 ? "gs" : "g");
		}
		else
			set_user_frags(vic, get_user_frags(vic)+1);
		
		return;
	}
	
	read_data(4, weapon, 2);
	frags = get_user_frags(id);
	
	if(weapon[0] == 'k')
	{
		steal = get_pcvar_num(cvar_steal);
		
		if (steal)
		{
			set_user_frags(id, frags + steal);
			set_user_frags(vic, get_user_frags(vic) - steal);
			client_print(id, print_chat, "Robaste %i frag%s de %s por acuchillarle.", steal, steal == 1 ? "" : "s", player_name(vic));
			client_print(vic, print_chat, "%s te robo %i frag%s por acuchillarte.", player_name(id), steal, steal == 1 ? "" : "s");
		}
	}
	else
		steal = 0;
	
	if(!g_votemap && frags + 1 + steal >= g_maxfrags - get_pcvar_num(cvar_lastfrags))
	{
		g_votemap = true
		VoteForMap();
		
		new name[32];
		get_user_name(id, name, 31);
		colored_print(0, "^x04[WbF]^x01 El jugador^x03 %s^x01 esta^x04 a %d frags de ganar^x01, comenzando la votacion para el proximo mapa.", name, get_pcvar_num(cvar_lastfrags));
	}
	
	if(frags + 1 + steal >= g_maxfrags)
	{
		g_winner = id;
		// We'll use these variables so we don't need to create new ones
		g_firstleader = get_pcvar_num(cvar_winnertime);
		g_secondleader = vic;
		
		client_cmd(0, "spk wbf/box_ring.wav");
		
		//message_begin(MSG_ALL,SVC_INTERMISSION);
		//message_end();
		
		PrepareToChangeMap()
		
		new wins;
		
		if (!is_user_bot(g_winner))
		{
			new Handle:dbtuple = SQL_MakeDbTuple( "", "", "", "WinByFrags")
			
			new errcode, error[10], Handle:connection = SQL_Connect(dbtuple, errcode, error, charsmax(error))
			new Handle:query = SQL_PrepareQuery(connection, "SELECT Victorias FROM WinByFrags WHERE Nombre=^"%s^"", player_name(g_winner));
			SQL_Execute(query);
			
			if (SQL_NumResults(query))
			{
				wins = SQL_ReadResult(query, 0) + 1;
				SQL_FreeHandle(query);
				query = SQL_PrepareQuery(connection, "UPDATE WinByFrags SET Victorias='%d' WHERE Nombre=^"%s^"", wins, player_name(g_winner));
				SQL_Execute(query);
				SQL_FreeHandle(query);
			}
			else
			{
				SQL_FreeHandle(query);
				query = SQL_PrepareQuery(connection, "INSERT INTO WinByFrags (Nombre) VALUES (^"%s^")", player_name(g_winner));
				SQL_Execute(query);
				SQL_FreeHandle(query);
				wins = 1;
			}
				
			SQL_FreeHandle(connection)
			SQL_FreeHandle(dbtuple)
		}
		else
			wins = 1;
		
		new len = PrepareWinnerMotd(g_winner, wins);
		
		new nextmap[150], map[32], newlen;
		get_cvar_string("amx_nextmap", map, 31);
		formatex(nextmap, charsmax(nextmap),"<br><p>El proximo mapa sera <font color=FF4C4C>%s<font color=FFFFFF>. Cambiando en %.0f segundos...</font></p>", map, get_pcvar_float(cvar_winnertime));
	
		for(id = 1; id <= g_maxplayers; id++)
		{
			if(!is_player_connected(id) || is_user_bot(id)) continue;
			
			set_user_godmode(id, 1);
			//set_pev(id, pev_flags, pev(id,pev_flags) | FL_FROZEN);
			//strip_user_weapons(id);
			cs_set_user_zoom(id, CS_SET_NO_ZOOM, 0); // Por si tiene un AWP con la mira
			client_cmd(id, "-attack");
			frags = get_user_frags(id);
			
			if (id == g_winner)
				newlen = len + formatex(g_motd[len], charsmax(g_motd)-len, "<p>Felicitaciones! Has ganado en este mapa.<p>Mucha suerte para el proximo!");
			else
			{
				newlen = len + formatex(g_motd[len], charsmax(g_motd)-len, "<p>%s, conseguiste %d frags, te falt%s %d para ganar.<p>\
				Mejor suerte la proxima vez!", player_name(id), frags, g_maxfrags - frags <= 1 ? "o solo" : "aron", g_maxfrags-frags);
			}
			
			copy(g_motd[newlen], charsmax(g_motd)-newlen, nextmap);
			
			show_motd(id, g_motd, "Fin del Juego");
			//set_pev(id, pev_viewmodel2, "");
		}
	}
}
	
public PrepareToChangeMap()
{
	g_firstleader--
	
	if(!g_firstleader)
	{
		new NextMap[65]
		get_cvar_string("amx_nextmap", NextMap, 64);
		server_cmd("changelevel %s", NextMap);
	}
	else
	{
		if (g_firstleader == get_pcvar_num(cvar_winnertime)-2)
			client_cmd(0, "mp3 play ^"%s^"", WIN_MUSIC[g_music]);
		
		set_task(1.0, "PrepareToChangeMap")
	}
}

PrepareWinnerMotd(winner, wins)
{
	new len = formatex(g_motd, charsmax(g_motd),"<meta http-equiv=^"Content-Type^" content=^"text/html;charset=UTF-8^">\
	<body bgcolor=black style=line-height:1;color:white><center><font color=FFFFFF size=7 face=Tahoma><p>Win By Frags");
	len += formatex(g_motd[len], charsmax(g_motd)-len,"<br><p><font color=00CC00 size=6 style=letter-spacing:2px>\
	<font size=4 color=white style=letter-spacing:1px>El ganador es ");
	len += formatex(g_motd[len], charsmax(g_motd)-len, "<p><div style=height:1px;width:80%%;background-color:00CC00;overflow:hidden></div>\
	<font color=00CC00 size=7 style=letter-spacing:2px>%s<div style=height:1px;width:80%%;background-color:00CC00;overflow:hidden></div><p>", player_name(winner));
	
	if (wins > 1)
		len += formatex(g_motd[len], charsmax(g_motd)-len,"<font color=FFFFFF size=4>Con esta victoria,<font color=00CC00> %s <font color=FFFFFF>ahora acumula <font color=FF4C4C>%d <font color=FFFFFF>victorias en total.", player_name(winner), wins);
	else len += formatex(g_motd[len], charsmax(g_motd)-len,"<font color=FFFFFF size=4>Esta es la <font color=FF4C4C>primera victoria<font color=FFFFFF> de <font color=00CC00>%s<font color=FFFFFF>.", player_name(winner));
	
	return len;
}

//Code from GunGame, made by Avalanche.
VoteForMap()
{
	if(find_plugin_byfile("mapchooser.amxx") == INVALID_PLUGIN_ID)
		return;
	
	new oldWinLimit = get_cvar_num("mp_winlimit"), oldMaxRounds = get_cvar_num("mp_maxrounds");
	set_cvar_num("mp_winlimit",0);
	set_cvar_num("mp_maxrounds",-1);
	client_cmd(0, "spk gungame/gg_brass_bell.wav");

	if(callfunc_begin("voteNextmap","mapchooser.amxx") == 1)
		callfunc_end();

	set_cvar_num("mp_winlimit",oldWinLimit);
	set_cvar_num("mp_maxrounds",oldMaxRounds);
}

colored_print(id, text[], any:...)
{
	static msgSayText, msg[190];
	vformat(msg, 189, text, 3);
	
	if (!msgSayText)
		msgSayText = get_user_msgid("SayText");
	
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSayText, .player = id);
	write_byte(33);
	write_string(msg);
	message_end();
}

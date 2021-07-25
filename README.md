# Win By Frags - AMXX

Este plugin cambia el modo del juego: en cada ronda (mapa) habrá un ganador, quien sera el primero que logre llegar al límite de frags.

### Informacion
* Los jugadores tendrán un contador de frags (HUD) en la parte de abajo, y en la parte de arriba verán el nombre (o los nombres) del líder (el que va en primer lugar).
* Cuando un jugador esté a X frags de ganar (cambiable por cvar), empezará el votemap. (Y sonará una campana, como en GunGame)
* Cuando un jugador gane, todos se paralizarán, sonara una campana de match win y verán en forma MOTD el nombre del ganador, la última víctima y alguna otra información durante X segundos (cambiable por cvar) luego de eso el mapa cambiará.
* Puedes robar frags matando con cuchillo (ver cvars).

### Cvars
* wbf_enable <1|0> - Activa o desactiva el plugin.
* wbf_max_frags <#> - Numero de frags necesarios para ganar.
* wbf_frags_left_to_vote <#> - Cuantos votos le deben faltar al puntero para que inicie la votacion del proximo mapa.
* wbf_winner_time <#> - Tiempo desde que alguien gano hasta que cambie el mapa en segundos, es el tiempo en que los jugadores verán el nombre del ganador.
* wbf_knife_steal <#> - Numero de frags que se roban al matar con cuchillo.
* wbf_penalty <#> - Cuántos frags se pierden por suicidarse. Recomiendo dejarlo en 0 si se usa con CSDM, ya que es posible que algún jugador aparezca muerto sin querer y se considere como un suicidio.

### Changelog
* v0.3 - Feb 10, 2014
Publicación del plugin.
Agregado: Hud con informacion sobre el ganador, al terminar.

* v0.4 - Jan 06, 2016
Agregado: Guardado de victorias y Top 10.
Agregado: Motd con información sobre el ganador, al terminar.
Agregado: Reproducción de sonido cuando termina el juego.
Agregado: cvar wbf_penalty
Agregado: comandos /top y /top10 para mostrar el top de jugadores.

### Instalación
* Compilar WinByFrags.sma, copiar los recursos en la carpeta cstrike y activar el módulo SQLite.
* El plugin funciona con el mapchooser original de AMXX. Si se usa otro mapchooser, editar la función VoteForMap() con el comando necesario. Por ejemplo, para Galileo, basta reemplazar la función entera por la línea: server_cmd("gal_startvote").

### Soporte
* AM-ES: https://amxmodx-es.com/showthread.php?tid=1020
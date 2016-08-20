MAX_TORRENTS = 10

TORRENT_ACTION_ADD 	    	= 1
TORRENT_ACTION_START		= 2
TORRENT_ACTION_PAUSE		= 3
TORRENT_ACTION_REMOVE   	= 4
TORRENT_ACTION_SHOW 		= 5
TORRENT_ACTION_SHOW_ALL 	= 6
TORRENT_ACTION_QUIT     	= 7

TORRENT_STATE_NEW			= 1


struct torrent_info
	torrent_pointer     dd ?  ;pointer to torrent struct
	torrent_state   	dd ?  ;current state of torrent
	torrent_id 		    dd ?  ;unique id of torrent
ends
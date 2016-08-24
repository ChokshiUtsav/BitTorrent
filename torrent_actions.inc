;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    Copyright (C) 2016 Utsav Chokshi (Utsav_Chokshi)
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Constants
MAX_TORRENTS = 10

;Torrent Actions
TORRENT_ACTION_ADD 	    	= 1
TORRENT_ACTION_START		= 2
TORRENT_ACTION_PAUSE		= 3
TORRENT_ACTION_REMOVE   	= 4
TORRENT_ACTION_SHOW 		= 5
TORRENT_ACTION_SHOW_ALL 	= 6
TORRENT_ACTION_QUIT     	= 7

;Torrent states
TORRENT_STATE_NEW			= 1

struct torrent_info
	torrent_pointer     dd ?  ;pointer to torrent struct
	torrent_state   	dd ?  ;current state of torrent
	torrent_id 		    dd ?  ;unique id of torrent
ends

;Messages
Avl_Torrents_Msg        db 'Following Torrents have been added :',0
Torrent_Index_Msg       db 'Torrent :',0
Seperator_Str			db '--------------',0
Torrent_ID_Msg          db 'ID : ',0
Torrent_Name_Msg        db 'Name : ', 0
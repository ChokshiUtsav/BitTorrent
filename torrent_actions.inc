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
TORRENT_STATE_RUNNING		= 2
TORRENT_STATE_NOT_ACTIVE	= 3
TORRENT_STATE_PAUSED        = 4

struct torrent_info
	torrent_pointer     dd ?  ;pointer to torrent struct
	torrent_state   	dd ?  ;current state of torrent
	torrent_id 		    dd ?  ;unique id of torrent
ends

;Messages
Avl_Torrents_Msg              db '>>>>Following Torrents have been added :',0
Torrent_Index_Msg             db '>>>>Torrent :',0
Seperator_Str			      db '    ----------',10,0
Torrent_ID_Msg                db '    ID     : ',0
Torrent_Name_Msg              db '    Name   : ', 0
Torrent_State_Msg		      db '    Status : ', 0
Torrent_New_State_Msg	      db 'Added but Not Started', 0
Torrent_Running_State_Msg     db 'Active and Running', 0
Torrent_Not_Active_State_Msg  db 'Not active', 0
Torrent_Paused_State_Msg      db 'Paused', 0
Torrent_Details_Msg           db '>>>>Torrent Details : ',10,0
Seperator_2_Str				  db '    -------------------'
Torrent_Downloaded_Msg        db '    Downloaded : ', 0
Torrent_Uploaded_Msg          db '    Uploaded : ', 0
Torrent_Pieces_Msg            db '    Number of pieces : ', 0
Torrent_Files_Msg             db '    Number of files : ', 0
Torrent_Peers_Msg             db '    Number of peers : ', 0
Torrent_Size_Msg              db '    Total size of torrent : ',0
Torrent_Hash_Msg              db '    Info Hash : ', 0
Torrent_Tracker_Msg           db '    Tracker URL : ',0
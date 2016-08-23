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

;Error Codes
BT_ERROR_NOT_ENOUGH_MEMORY    = 1
BT_ERROR_INSUFF_HD_SPACE      = 2
BT_ERROR_INVALID_TORRENT_FILE = 3
BT_ERROR_MAX_TORRENT_EXCEED   = 4

;Error Strings
Not_Enough_Memory_Str 		  db 'Not enough memory for torrent processing',10,0
Insuff_Hd_Space_Str           db 'Insufficient hard drive space',10,0
Invalid_Torrent_File_Str      db 'Invalid torrent file',10,0
Max_Torrent_Exceed_Str    db 'Maximum number of torrents, that can be processed, is exceeded',10,0
Torrent_Add_Suc_Str           db 'Torrent has been added successfully ',10,0
Invalid_Cmd_Str           	  db 'Torrent command not supported', 10, 0
No_Torrent_Added_Str          db 'No torrent is added yet', 10, 0
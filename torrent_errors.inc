;Error Codes
BT_ERROR_NOT_ENOUGH_MEMORY    = 1
BT_ERROR_INSUFF_HD_SPACE      = 2
BT_ERROR_INVALID_TORRENT_FILE = 3
BT_ERROR_MAX_TORRENT_EXCEED   = 4

;Error Strings
Not_Enough_Memory_Str 		  db 'Not enough memory for torrent processing',10,0
Insuff_Hd_Space_Str           db 'Insufficient hard drive space',10,0
Invalid_Torrent_File_Str      db 'Invalid torrent file',10,0
Max_Torrent_Exceed_Str        db 'Maximum number torrent, that can be processed, is exceeded',10,0
Torrent_Add_Suc_Str           db 'Torrent has been added successfully ',10,0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods that chnages torrent's state
;It mainly changes values at torrent_arr.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Procedure Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc  : adds new torrent
;Input : location of .torrent file, download location 
;Outcome : if success -> eax = torrent_id
;          if error   -> eax = -1
;                        ebx = errorcode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc backend_actions.torrent_add _torrentfile, _downloadloc
    
            DEBUGF 2, "INFO : In backend_actions.torrent_add\n"

            push    ecx edx esi edi

            ;checking whether torrent can be added
            cmp     [num_torrents], MAX_TORRENTS
            jle     @f
            DEBUGF 3, "ERROR : Maximum number of torrent is already running\n"
            mov     ebx, BT_ERROR_MAX_TORRENT_EXCEED
            jmp     .error


            ;adding new torrent
    @@:     invoke   torrent.new, BT_NEW_FILE, [_torrentfile], [_downloadloc]
            cmp      eax, -1
            jne      @f
            DEBUGF 3, "ERROR : Problem with torrent.new\n"
            jmp      .error

            ;adding torrent to torrent_arr
    @@:     mov      edi, [num_torrents]
            imul     edi, sizeof.torrent_info
            add      edi, [torrent_arr]
            lodsd                       ;setting torrent_pointer
            mov      eax, TORRENT_STATE_NEW
            lodsd                       ;setting torrent_state
            mcall    26, 9
            lodsd                       ;setting torrent_id
            inc      [num_torrents]

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            mov     eax, -1
            pop     edi esi edx ecx
            ret

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
            pop     edi esi edx ecx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc  : sends details about torrent in string format
;Input : torrent_id 
;Outcome : if success -> eax = torrent_id
;          if error   -> eax = -1
;                        ebx = errorcode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc backend_actions.torrent_show _torrentid

endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc  : sends details about all torrent in string format
;Input : none 
;Outcome : if success -> eax = torrent_id
;          if error   -> eax = -1
;                        ebx = errorcode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc backend_actions.torrent_show_all

endp

proc backend_actions.torrent_start
endp

proc backend_actions.torrent_pause
endp

proc backend_actions.torrent_remove
endp

proc backend_actions.torrent_show_all
endp

proc backend_actions.torrent_quit
endp


proc prepare_torrent_details _torrentid
endp
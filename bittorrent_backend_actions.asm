;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods that chnages torrent's state
;It mainly changes values at torrent_arr.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Procedure Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Copies a null terminated string
;Input   : source string pointer, destination string pointer
;Outcome : eax = number of bytes copied
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc  copy_strs _dest, _src
            
            push ecx esi edi

            mov  esi, [_src]
            mov  edi, [_dest]
            mov  ecx, 0

    .loop:  cmp  byte[esi], 0x00
            je   .quit
            movsb
            inc  ecx
            jmp  .loop

    .quit:  mov  byte[edi], 0x00
            mov  eax, ecx
            pop  edi esi ecx
            ret
endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc  : adds new torrent
;Input : location of .torrent file, download location 
;Outcome : if success -> eax = torrent_id
;          if error   -> eax = -1
;                        ebx = errorcode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc backend_actions.torrent_add _msg, _sendbuffer
            DEBUGF 2, "INFO : In backend_actions.torrent_add\n"

            push    ecx edx esi edi

            ;checking whether torrent can be added
            cmp     [num_torrents], MAX_TORRENTS
            jle     @f
            DEBUGF 3, "ERROR : Maximum number of torrent is already running\n"
            mov     ebx, BT_ERROR_MAX_TORRENT_EXCEED
            jmp     .error

    @@:     mov     esi, [_msg]
            ;copy torrent file location
            mov     edi, torrent_filename
    .loop1: cmp     byte[esi], '#'
            je      @f
            movsb
            jmp     .loop1

            ;copy download location
    @@:     dec     edi
            mov     byte[edi], 0x00
            inc     esi
            mov     edi, download_location
    .loop2: cmp     byte[esi], '#'
            je      @f
            movsb
            jmp     .loop2

     @@:    dec     edi
            mov     byte[edi], 0x00

            ;adding new torrent
    @@:     invoke   torrent.new, BT_NEW_FILE, torrent_filename, download_location
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
            stdcall  copy_strs, [_sendbuffer], Torrent_Add_Suc_Str
            jmp      .quit

    .error: cmp      ebx, BT_ERROR_NOT_ENOUGH_MEMORY
            jne      @f
            stdcall  copy_strs, [_sendbuffer], Not_Enough_Memory_Str
            jmp      .quit
    
    @@:     cmp      ebx, BT_ERROR_INSUFF_HD_SPACE
            jne      @f
            stdcall  copy_strs, [_sendbuffer], Insuff_Hd_Space_Str
            jmp      .quit

    @@:     cmp      ebx, BT_ERROR_INVALID_TORRENT_FILE
            jne      @f
            stdcall  copy_strs, [_sendbuffer], Invalid_Torrent_File_Str
            jmp      .quit

    @@:     cmp      ebx, BT_ERROR_MAX_TORRENT_EXCEED 
            jne      @f
            stdcall  copy_strs, [_sendbuffer], Max_Torrent_Exceed_Str

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
            pop      edi esi edx ecx
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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Data Area ;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

torrent_filename     rb 512
download_location    rb 512
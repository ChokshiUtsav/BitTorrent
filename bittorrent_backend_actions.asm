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
;Input   : destination string pointer, source string pointer
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Converts number to string
;Input   : number, destination string pointer
;Outcome : Non-Null terminated string representation of number
;Output  : eax = length of string
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc  num_to_str _num, _dest
            
            push ebx ecx edx esi edi

            locals
                temp_str rb 16
            endl

            mov  ebx, 10
            mov  ecx, 0
            lea  edi, [temp_str]
            mov  eax, [_num]

    .loop1: mov  edx, 0
            div  ebx
            add  dl, 48
            push eax
            mov  eax, edx
            stosb
            pop  eax
            inc  ecx
            cmp  eax, 0
            je   @f
            jmp  .loop1

    @@:     mov  ebx, ecx
            dec  edi
            mov  esi, [_dest]

    .loop2: cmp  ecx, 0
            je   .quit
            mov  al, byte[edi]
            mov  byte[esi], al
            dec  ecx
            dec  edi
            inc  esi
            jmp  .loop2 

    .quit:  mov  eax, ebx
            pop edi esi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Converts null-terminated string to number
;Input   : source string pointer
;Output  : eax = number
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc  str_to_num _src
            
            push ebx ecx edx esi edi

            mov  esi, [_src]
            mov  ecx, 0
                    
    .loop : cmp  byte[esi], 0x00
            je   .quit
            cmp  byte[esi], 0x0A
            je   .quit
            cmp  byte[esi], '#'
            je   .quit
            lodsb
            sub   eax, '0'
            imul  ecx, 10
            add   ecx, eax
            jmp  .loop

    .quit:  mov  eax, ecx
            pop  edi esi edx ecx ebx
            ret
endp 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : adds new torrent
;Input   : message from frontend [torrent-file loc + download loc], pointer to send buffer  
;Output  : eax = length of message to be sent
;Outcome : Adds torrent in torrent_arr
;          Puts an appropriate message at send buffer 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc backend_actions_add _msg, _sendbuffer
            DEBUGF 2, "INFO : In backend_actions.torrent_add\n"

            push    ebx ecx edx esi edi

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

    @@:     dec     edi
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
            stosd                       ;setting torrent_pointer
            mov      eax, TORRENT_STATE_NEW
            stosd                       ;setting torrent_state
            mcall    26, 9
            stosd                       ;setting torrent_id
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
            pop      edi esi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc  : sends details about torrent in string format
;Input : message from frontend [torrent-id]
;Outcome : if success -> eax = torrent_id
;          if error   -> eax = -1
;                        ebx = errorcode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc backend_actions_show _msg, _sendbuffer
            
            DEBUGF 2, "INFO : In backend_actions.torrent_show\n"
            
            push    ebx ecx edx esi edi

            cmp     [num_torrents], 0
            je      .no_torrent

            stdcall  str_to_num, [_msg] 
            mov      ebx, eax
            mov      ecx, 0

    .loop:  cmp     ecx, [num_torrents]
            je      .no_torrent
            mov     esi, ecx
            imul    esi, sizeof.torrent_info
            add     esi, [torrent_arr]
            cmp     ebx, [esi + torrent_info.torrent_id]
            jne     .next

            ;prints torrent details msg
            mov     edi, [_sendbuffer]
            stdcall copy_strs, edi, Torrent_Details_Msg
            add     edi, eax
            stdcall copy_strs, edi, Seperator_Str
            add     edi, eax

            mov     ebx, [esi + torrent_info.torrent_pointer]

            ;prints name msg
            stdcall copy_strs, edi, Torrent_Name_Msg
            add     edi, eax
            lea     esi, [ebx + torrent.name]
            stdcall copy_strs, edi, esi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi

            ;prints files msg
            stdcall copy_strs, edi, Torrent_Files_Msg
            add     edi, eax
            mov     eax, [ebx + torrent.files_cnt]
            stdcall num_to_str, eax, edi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi

            ;prints pieces msg
            stdcall copy_strs, edi, Torrent_Pieces_Msg
            add     edi, eax
            mov     eax, [ebx + torrent.pieces_cnt]
            stdcall num_to_str, eax, edi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi

            ;prints downloaded msg
            stdcall copy_strs, edi, Torrent_Downloaded_Msg
            add     edi, eax
            mov     eax, [ebx + torrent.downloaded]
            stdcall num_to_str, eax, edi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi

            ;prints uploaded msg
            stdcall copy_strs, edi, Torrent_Uploaded_Msg
            add     edi, eax
            mov     eax, [ebx + torrent.uploaded]
            stdcall num_to_str, eax, edi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi

            ;prints tracker msg
            stdcall copy_strs, edi, Torrent_Tracker_Msg
            add     edi, eax
            mov     eax, [ebx + torrent.trackers]
            lea     esi, [eax + tracker.announce]
            stdcall copy_strs, edi, esi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi

            ;prints peers msg
            stdcall copy_strs, edi, Torrent_Peers_Msg
            add     edi, eax
            mov     eax, [ebx + torrent.peers_cnt]
            stdcall num_to_str, eax, edi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi

            ;prints total size msg
            stdcall copy_strs, edi, Torrent_Size_Msg
            add     edi, eax
            mov     ecx, [ebx + torrent.pieces_cnt]
            mov     eax, [ebx + torrent.piece_length]
            imul    eax, ecx
            stdcall num_to_str, eax, edi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi

            mov     byte[edi], 0x00         
            jmp     .quit           

    .next:  inc     ecx
            jmp     .loop

    .no_torrent:
            stdcall  copy_strs, [_sendbuffer], No_Matching_Torrent_Str                              
    .quit:  
            pop     edi esi edx ecx ebx
            ret
endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : sends details (id+name) about all torrent in string format
;Input   : pointer to send buffer
;Output  : eax = length of message to be sent
;Outcome : Puts an appropriate message at send buffer 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc backend_actions_show_all  _sendbuffer
            
            DEBUGF 2, "INFO : In backend_actions.torrent_show_all\n"

            push    ebx ecx edx esi edi

            cmp     [num_torrents], 0
            je      .no_torrent

            mov     ecx, 0
            mov      edi, [_sendbuffer]

            ;prepares message
            ;prints available torrent message
            stdcall  copy_strs, edi, Avl_Torrents_Msg
            add      edi, eax
            mov      byte[edi], 0x0A
            inc      edi
        
    .loop:  cmp     ecx, [num_torrents]
            je      .calc_length
            mov     esi, ecx
            imul    esi, sizeof.torrent_info
            add     esi, [torrent_arr]

            ;prints torrent-index message
            stdcall  copy_strs, edi, Torrent_Index_Msg
            add      edi, eax

            ;prints torrent-index
            stdcall  num_to_str, ecx, edi
            add      edi, eax
            mov      byte[edi], 0x0A
            inc      edi

            ;prints seperator
            stdcall  copy_strs, edi, Seperator_Str
            add      edi, eax
            mov      byte[edi], 0x0A
            inc      edi

            ;prints torrent-id message
            stdcall   copy_strs, edi, Torrent_ID_Msg
            add       edi, eax

            ;prints torrent-id
            mov     eax, [esi + torrent_info.torrent_id]
            stdcall num_to_str, eax, edi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi

            ;prints torrent-id message
            stdcall   copy_strs, edi, Torrent_State_Msg
            add       edi, eax

            ;prints torrent-state
            cmp     [esi + torrent_info.torrent_state], TORRENT_STATE_NEW
            jne     @f
            stdcall copy_strs, edi, Torrent_New_State_Msg
            jmp     .next

    @@:     cmp     [esi + torrent_info.torrent_state], TORRENT_STATE_RUNNING
            jne     @f
            stdcall copy_strs, edi, Torrent_Running_State_Msg
            jmp     .next

    @@:     cmp     [esi + torrent_info.torrent_state], TORRENT_STATE_NOT_ACTIVE
            jne     @f
            stdcall copy_strs, edi, Torrent_Not_Active_State_Msg
            jmp     .next

            stdcall copy_strs, edi, Torrent_Paused_State_Msg        

    .next:  add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi         

            ;prints name message
            stdcall   copy_strs, edi, Torrent_Name_Msg
            add       edi, eax

            ;prints name
            mov     eax, [esi + torrent_info.torrent_pointer]
            lea     esi, [eax + torrent.name]
            stdcall copy_strs, edi, esi
            add     edi, eax
            mov     byte[edi], 0x0A
            inc     edi
            mov     byte[edi], 0x0A
            inc     edi

            inc     ecx
            jmp     .loop

    .calc_length:
            mov     byte[edi], 0x00
            mov     eax, edi
            sub     eax, [_sendbuffer]
            jmp     .quit

    .no_torrent:
            stdcall  copy_strs, [_sendbuffer], No_Torrent_Added_Str
            jmp      .quit

    .quit:  
            pop     edi esi edx ecx ebx
            ret
endp

proc backend_actions_start
endp

proc backend_actions_pause
endp

proc backend_actions_remove
endp

proc backend_actions_quit
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Data Area ;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

torrent_filename     rb 512
download_location    rb 512
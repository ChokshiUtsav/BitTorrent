;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    Copyright (C) 2015 Ivan Baravy (dunkaist)
;    Modified by Utsav Chokshi (Utsav_Chokshi)
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains method that prepares get request for tracker and helps to decode response from tracker.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Procedure Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Prepares get request for Tracker server with different tracker.protocols
;Input     : pointer to torrent data structure, tracker 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


proc torrent._.tracker_get _torrent, _tracker
        
            push    ebx

            DEBUGF 2, "INFO: In torrent._.tracker_get\n"

            mov     ebx, [_tracker]
            mov     eax, [ebx + tracker.protocol]
    .next_protocol:
            stdcall [tracker_get_by_protocol + eax*4], [_torrent], [_tracker]
            test    eax, eax
            jz      .quit

            cmp     eax, BT_TRACKER_ERROR_NOT_SUPPORTED
            jnz     .error

            DEBUGF 2,'ERROR : Protocol %d is not supported by tracker\n',[ebx + tracker.protocol]
            dec     [ebx + tracker.protocol]
            jnc     .next_protocol
            jmp     .error

    .error: DEBUGF 3, "ERROR : Procedure ended with error.\n"
            mov     eax, -1
            pop     ebx
            ret
    
    .quit:  mcall   26, 9
            mov     ebx, [_tracker]
            mov     [ebx + tracker.last_seen], eax
            DEBUGF 2, "INFO : Procedure ended successfully.\n"
            mov     eax, 0
            pop     ebx
            ret  
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Prepares get request for Tracker server with tracker.protocol = TCP
;Input     : pointer to torrent data structure, tracker 
;Outcome   : Prepares HTTP get request and processes HTTP response
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc tracker._.get_tcp _torrent, _tracker
        
            locals
                identifier      dd ?
            endl
            push    ebx esi edi

            DEBUGF 2, "INFO : In tracker._.get_tcp\n"

            mov     ebx, [_tracker]
            stdcall torrent._.tracker_fill_params, [_torrent], [_tracker]

            mov     edi, [_tracker]
            add     edi, [edi + tracker.announce_len]
            add     edi, tracker.announce
            DEBUGF 2,'INFO : Params: %s\n',edi

            lea     edi, [ebx + tracker.announce]
            DEBUGF 2,'INFO : Url: %s\n',edi

            invoke  http.get, edi, 0, 0, 0
            test    eax, eax
            jz      .error
            mov     [identifier], eax

    @@:     invoke  http.receive, [identifier]
            test    eax, eax
            jnz     @b

            mov     ebx, [identifier]
            mov     eax, [ebx + http_msg.content_received]
            mov     [final_size], eax
            mov     ebx, [ebx + http_msg.content_ptr]
            mov     [final_buffer], ebx
            ;mcall   70, fileinfo

            mov     esi, [final_buffer]
            mov     eax, esi
            inc     esi
            add     eax, [final_size]
            stdcall torrent._.bdecode_dict, [_torrent], eax, keys_tracker_response0

            invoke  http.free, [identifier]
            jmp     .quit

  .error:   DEBUGF 3,'ERROR: %d\n',eax
  
  .quit:    DEBUGF 2, "INFO : Procedure ended successfully.\n"
            xor     eax, eax
            pop     edi esi ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Prepares get request for Tracker server with tracker.protocol = UDP
;Input     : pointer to torrent data structure, tracker 
;Note      : It is remaining to implement
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc tracker._.get_udp _torrent, _tracker
        mov     eax, BT_TRACKER_ERROR_NOT_SUPPORTED
        ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Prepares announce URL for connecting with HTTP Tracker server
;Input     : pointer to torrent data structure, tracker 
;Outcome   : Fills tracker.announce parameter
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent._.tracker_fill_params _torrent, _tracker
            push    ebx esi edi

            DEBUGF 2, "INFO : In tracker._.tracker_fill_params\n"

            mov     ebx, [_torrent]
            mov     edi, [_tracker]
            add     edi, [edi + tracker.announce_len]
            add     edi, tracker.announce

            ;Preparing Parameters

            ;Writing info_hash
            mov     eax, '?inf'
            stosd
            mov     eax, 'o_ha'
            stosd
            mov     eax, 'sh= '
            stosd
            dec     edi
            lea     eax, [ebx + torrent.info_hash]
            stdcall torrent._.percent_encode, eax, [SHA1_LEN]

            ;Writing peer_id
            mov     eax, '&   '
            stosb
            mov     eax, 'peer'
            stosd
            mov     eax, '_id='
            stosd
            lea     esi, [ebx + torrent.peer_id]
            mov     ecx, 20
            rep movsb

            ;Writing port
            mov     eax, '&   '
            stosb
            mov     eax, 'port'
            stosd
            mov     eax, '=   '
            stosb
            stdcall torrent._.print_num, [ebx + torrent.port]

            ;Writing uploaded
            mov     eax, '&   '
            stosb
            mov     eax, 'uplo'
            stosd
            mov     eax, 'aded'
            stosd
            mov     eax, '=   '
            stosb
            stdcall torrent._.print_num, [ebx + torrent.uploaded]

            ;Writing downloaded
            mov     eax, '&   '
            stosb
            mov     eax, 'down'
            stosd
            mov     eax, 'load'
            stosd
            mov     eax, 'ed= '
            stosd
            dec     edi
            stdcall torrent._.print_num, [ebx + torrent.downloaded]
            
            ;Writing left
            mov     eax, '&   '
            stosb
            mov     eax, 'left'
            stosd
            mov     eax, '=   '
            stosb
            stdcall torrent._.print_num, [ebx + torrent.left]
            DEBUGF 2, "Torrent Left : %d\n",[ebx + torrent.left]

            ;Writing compact
            mov     eax, '&   '
            stosb
            mov     eax, 'comp'
            stosd
            mov     eax, 'act='
            stosd
            mov     eax, '1   '
            stosb

            xor     eax, eax
            stosb

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully.\n"
            pop     edi esi ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Data Area ;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

tracker_get_by_protocol dd tracker._.get_tcp
                        dd tracker._.get_udp
SHA1_LEN                dd 20
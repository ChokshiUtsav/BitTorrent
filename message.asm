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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods for creating and verifying messages of bittorrent protocol.
;In bittorrent protocol, communication between clients happen using 11 different kind of messages.
;All of the remaining messages in the protocol take the form of <length prefix><message ID><payload>. The length prefix is a four byte big-endian value. The message ID is a single decimal byte. The payload is message dependent.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Procedure Area ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Prepares handshake message
;Input     : pointer to torrent data structure, peer data structure and pointer to location to store handshake message
;Outcome   : Prepares handshake message and stores at _msg
;Note      : Handshake msg (68Bytes): 19BitTorrent protocol00000000<20byte-info-hash><peerid>
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc message._.prep_handshake_msg _torrent, _peer, _msg
        
                DEBUGF 2, "INFO : In message._.prepare_handshake\n"
                
                push    ebx edx ecx esi edi

                locals
                        protocol_string_len     db 19
                        protocol_string         db 'BitTorrent protocol'
                endl

                mov     edi, [_msg]
                movzx   eax, [protocol_string_len]
                stosb
                lea     esi, [protocol_string]
                movzx   ecx, [protocol_string_len]
                rep     movsb
                mov     eax, 0
                mov     ecx, 8
                rep     stosb

                mov     ebx, [_torrent]
                lea     esi, [ebx+torrent.info_hash]
                mov     ecx, 20
                rep     movsb
                lea     esi, [ebx+torrent.peer_id]
                mov     ecx, 20
                rep     movsb
        
        .quit : DEBUGF 2, "INFO : Procedure ended successfully.\n"
                pop     edi esi ecx edx ebx
                ret
endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Verifies handshake message
;Input     : pointer to torrent data structure, peer data structure and handshake message
;Outcome   : Verifies handshake message and stores peer.peer_id
;ErrorCode : eax = 0  -> success (verfied)
;            eax = -1 -> error   (verification failed)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc message._.ver_handshake_msg _torrent, _peer, _msg

                DEBUGF 2, "INFO : In message._.verify_handshake\n"
                
                push    ebx edx ecx esi edi

                locals
                        protocol_string_len     db 19
                        protocol_string         db 'BitTorrent protocol'
                endl

                mov     esi, [_msg]
                mov     al, byte [esi]
                cmp     al, [protocol_string_len]
                jne     .error

                inc     esi
                lea     edi, [protocol_string]
                movzx   ecx, [protocol_string_len]
                repe    cmpsb
                cmp     ecx, 0
                jne     .error

                add     esi, 8  ;Ignoring 8 bytes reserved for protocol extension

            @@: mov     ebx, [_torrent]
                lea     edi, [ebx+torrent.info_hash]
                mov     ecx, 20
                repe    cmpsb
                cmp     ecx, 0
                jne     .error

                mov     ebx, [_peer]                
                lea     edi, [ebx + peer.peer_id]
                mov     ecx, 20
                cmp     [ebx + peer.peer_id_present],1
                je      .compare_peerid
                rep     movsb           ;otherwise store peer-id
                jmp     .quit

        .compare_peerid:
                rep     cmpsb
                cmp     ecx,0
                jne     .error

        .error: DEBUGF 3, "ERROR : Procedure ended with error.\n"
                mov        eax,-1
                pop        edi esi ecx edx ebx
                ret

        .quit:  DEBUGF 2, "INFO : Procedure ended successfully.\n"
                mov        eax, 0
                pop        edi esi ecx edx ebx
                ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Prepares message without payload (i.e. interested, non-interested, choke, unchoke)
;Input     : pointer to location where message to be stored , message type
;Outcome   : 5 byte message stored at _msg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc message._.prep_nopayload_msg _msg, _type
                
                push   edi

                mov    edi, [_msg]
                mov    eax, 0x01000000 ; length = 1
                stosd
                mov    eax, [_type]    ; message type
                stosb

                pop    edi
                ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Processes and verifies bitfield message 
;Input     : pointer to torrent structure, peer structure, message, length
;Outcome   : Verifies length of bitfield message and stores it at peer.bitfield 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc message._.process_bitfield_msg _torrent, _peer, _msg, _len
                
                locals
                    byte_constant   dd 8
                endl


                DEBUGF 2, "INFO : In message._.process_bitfield_msg\n"
                push    ebx ecx edx esi edi

                mov     ebx, [_torrent]
                mov     eax, [ebx + torrent.pieces_cnt]
                mov     edx, 0
                div     [byte_constant]     
                cmp     edx, 0
                je      @f
                inc     eax

            @@: cmp     eax, [_len]
                jne     .error
                mov     esi, [_msg]
                mov     ebx, [_peer]
                lea     edi, [ebx + peer.bitfield]
                mov     ecx, [_len]
                rep     movsb
                jmp     .quit       


        .error: DEBUGF 3, "ERROR : Bitfield message verification failed\n"
                mov     eax, -1     
                pop     edi esi edx ecx ebx
                ret

        .quit : DEBUGF 2, "INFO : Bitfield message verified and stored\n"
                mov     eax, 0      
                pop     edi esi edx ecx ebx
                ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Processes have message 
;Input     : pointer to peer structure, piece-index
;Outcome   : Sets corresponding bit in peer's bit-field. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc message._.process_have_msg _peer, _index
                
                DEBUGF 2, "INFO : In message._.process_have_msg\n"

                push    ebx esi

                mov     ebx, [_peer]
                lea     esi, [ebx + peer.bitfield]
                stdcall bitfield._.set_bit, esi, [_index]
                
                pop     esi ebx
                ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Verifies and processes piece message 
;Input     : pointer to torrent structure, peer structure, message, current length of data recieved, total length of data expected to arrive, pointer to buffer
;Outcome   : Verfies _len against block length
;         Receives complete block and performs cleaning task if downloaded block is the last one.
;Note      : Usually data packet size is limited to 1500 bytes and block length is usually larger than 1500 bytes , so piece message is transfered as stream of data packets.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc message._.process_piece_msg _torrent, _peer, _msg, _curlen, _len ,_buffer

             locals
                    socketnum   dd ?
                    filedesc    dd ?
             endl
            
             DEBUGF 2, "INFO : In message._.process_piece_msg\n"
            
             push     ebx ecx edx esi edi

             ;verification
             mov      esi, [_msg]
             mov      ebx, [_peer]

             ;verifying piece index
             mov      edx, [ebx + peer.cur_piece]
             lodsd
             bswap    eax
             cmp      eax, edx
             je       @f
             DEBUGF 3, "INFO : Piece Index do not match\n"
             jmp      .error

             ;verifying block offset
         @@: sub      [_len], 4
             sub      [_curlen], 4
             mov      edx, [ebx + peer.cur_block]
             imul     edx, BLOCKLENGTH
             lodsd
             bswap    eax
             cmp      eax, edx
             je       @f
             DEBUGF 3, "INFO : Block offset do not match\n"
             jmp      .error

             ;verifying message length
         @@: sub      [_len], 4
             sub      [_curlen], 4
             cmp      [_len], BLOCKLENGTH
             je       @f
             DEBUGF 3, "INFO : Block length and message length do not match\n"
             jmp      .error

             ;move first set of data to memory
         @@: DEBUGF 2, "INFO : first set of data\n"
             mov      edi, [ebx + peer.cur_block]
             imul     edi, BLOCKLENGTH
             add      edi, [ebx + peer.piece_location]
             mov      ecx, [_curlen]
             sub      [_len], ecx
             rep      movsb   
             mov      eax, [ebx + peer.sock_num]
             mov      [socketnum], eax
             
    .recieve_loop:
             cmp      [_len], 0
             je       .prepare_data 
             stdcall torrent._.nonblocking_recv,[socketnum], RECV_TIMEOUT, [_buffer], BUFFERSIZE 
             cmp      eax, -1
             jnz      @f
             DEBUGF 3, "ERROR : recv %d.\n",ebx
             jmp      .error 

        @@:  mov      ecx, eax
             sub      [_len], ecx
             mov      esi,[_buffer]
             rep      movsb
             jmp      .recieve_loop

    .prepare_data:         
             ;preparing data for next request message
             inc     [ebx + peer.cur_block]
             mov     eax, [ebx + peer.cur_piece]
             mov     ecx, [ebx + peer.cur_block]
             DEBUGF 2, "INFO : Piece %d : Block %d\n",eax, ecx
             stdcall piece._.set_num_blocks, [_torrent], eax,  ecx
             mov     eax, [_torrent]
             cmp     ecx, [eax + torrent.num_blocks]
             je      .piece_download_comp
             jmp     .quit

    .piece_download_comp:

             ;verifying piece hash
             mov     edx, [_torrent]
             mov     eax, [edx + torrent.piece_length]
             mov     esi, [ebx + peer.piece_location]
             stdcall torrent._.generate_hash, esi, eax, cur_piece_hash
             mov     eax, [ebx + peer.cur_piece]
             stdcall piece._.verify_hash, [_torrent], eax, cur_piece_hash
             cmp     eax, -1
             je      .error

             ;writing piece to file
             mov     eax, [ebx + peer.cur_piece]
             mov     esi, [ebx + peer.piece_location]
             stdcall piece._.set_piece, [_torrent], eax, esi
             cmp     eax, -1
             je      .error

             ;changing piece status
             mov     eax, [ebx + peer.cur_piece]
             stdcall piece._.set_status, [_torrent], eax, BT_PIECE_DOWNLOAD_COMPLETE

             ;setting torrent bitfield
             mov     ecx, [ebx + peer.cur_piece]
             mov     eax, [_torrent]
             lea     edx, [eax + torrent.bitfield]
             stdcall bitfield._.set_bit, edx, ecx

             ;changing piece memory status
             mov     eax, [ebx + peer.cur_piece]
             stdcall torrent._.set_piece_mem_status, [_torrent], eax, MEM_LOCATION_FILLED 

             ;setting torrent downloaded and left
             mov     ebx, [_torrent]
             mov     eax, [ebx + torrent.piece_length]
             sub     [ebx + torrent.left], eax
             add     [ebx + torrent.downloaded], eax

             ;preparing data for next piece
             mov      ebx, [_peer]
             mov      [ebx + peer.cur_piece], -1
             jmp      .quit
        
    .error:  DEBUGF 3, "ERROR : Procedure ended with error\n"
             pop      edi esi edx ecx ebx
             mov      eax, -1
             ret

    .quit:   DEBUGF 2, "INFO : Procedure ended successfully\n"
             pop      edi esi edx ecx ebx
             mov      eax, 0
             ret            
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Prepares request message
;Input     : pointer to torrent structure, peer structure, message
;Outcome   : Finds index of available piece and memory location for the same.
;            Stores prepared message at _msg.
;ErrorCode : eax = 0  -> success (prepared)
;            eax = -1 -> error   (failed to prepare)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc message._.prep_request_msg _torrent, _peer, _msg

            DEBUGF 2, "INFO : In message._.prep_request_msg\n"

            push     ebx ecx edx esi edi
            
            mov      ebx, [_peer]
            cmp      [ebx + peer.cur_piece], -1
            jne     .prepare_msg
            stdcall  bitfield._.find_first_avl_piece, [_torrent], [_peer]
            cmp      eax, -1
            jne      @f
            DEBUGF 3, "ERROR : No piece available\n"
            jmp      .error

        @@: mov      [ebx + peer.cur_piece], eax
            mov      [ebx + peer.cur_block], 0
            stdcall  torrent._.get_mem_loc, [_torrent], eax, MEM_LOCATION_EMPTY
            cmp       eax, -1
            jne       @f
            DEBUGF 3, "ERROR : No empty location found\n"

            mov      eax, [ebx + peer.cur_piece]
            stdcall  torrent._.get_mem_loc, [_torrent], eax , MEM_LOCATION_FILLED
            cmp      eax, -1
            jne      @f
            stdcall  torrent._.print_piece_mem_status, [_torrent]
            DEBUGF 3, "ERROR : No location found for torrent downloading\n"
            jmp      .error         

        @@: mov      [ebx + peer.piece_location], eax

    .prepare_msg:
            mov      edi, [_msg]
            mov      eax, 0x0D000000               ; length = 13
            stosd
            mov      eax, BT_PEER_MSG_REQUEST      ; message type
            stosb
            mov      eax, [ebx+peer.cur_piece]     ; piece index
            bswap    eax
            stosd
            mov      eax, [ebx+peer.cur_block]     ; byte offset for block
            imul     eax, BLOCKLENGTH
            bswap    eax
            stosd
            mov      eax, BLOCKLENGTH
            bswap    eax
            stosd
            jmp      .quit
            
    .error:  DEBUGF 3, "ERROR : Procedure ended with error\n"
             pop      edi esi edx ecx ebx
             mov      eax, -1
             ret

    .quit:   DEBUGF 2, "INFO : Procedure ended successfully\n"
             pop      edi esi edx ecx ebx
             mov      eax, 0
             ret

endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Data Area;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cur_piece_hash  rb  20
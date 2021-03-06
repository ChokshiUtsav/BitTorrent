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

;This file contains methods for communicating with peers.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Procedure Area ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Finds all active peers and sets socket numbers for them
;Input   : pointer to torrent data structure 
;Outcome : eax = number of active peers 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent._.prep_active_peers _torrent
            
            locals
                    num_active_peers dd ?
            endl

            DEBUGF 2, "INFO : In torrent._.prep_active_peers\n"

            push        ebx ecx edx esi edi

            mov         [num_active_peers],0
            mov         ebx, [_torrent]
            mov         ecx, [ebx + torrent.peers_cnt]
            mov         edx, [ebx + torrent.peers]
     .loop:    
            jecxz       .quit
            stdcall     peer._.handshake, [_torrent], edx
            cmp         eax, -1
            je          @f
            inc         [num_active_peers]

        @@: add         edx, sizeof.peer
            dec         ecx
            jmp         .loop

    .quit:  DEBUGF 2,   "INFO : Procedure ended successfully\n"
            mov         eax, [num_active_peers]     
            pop         edi edi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Communicates with all active peers for torrent downloading
;Input   : pointer to torrent data structure 
;Note    : active peers are the ones not having -1 as sock_num 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent._.communicate_active_peers _torrent
            
            DEBUGF 2, "INFO : In torrent._.communicate_active_peers\n"

            push        ebx ecx edx esi edi

            mov         ebx, [_torrent]
            mov         ecx, [ebx + torrent.peers_cnt]
            mov         edx, [ebx + torrent.peers]
     
     .loop: jecxz       .quit
            cmp         [edx + peer.sock_num], -1   ;Indicates peer refused to connect(inactive)
            je           @f
            stdcall     peer._.communicate, [_torrent], edx

        @@: add         edx, sizeof.peer
            dec         ecx
            jmp         .loop

     .quit: pop         edi esi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc       : Performs handshake and intial message passing(i.e. sending interested msg)
;Input      : pointer to torrent data structure and peer data structure
;Outcome    : Sets details for peer data-structure like sock_num, last_seen 
;ErrorCodes : eax = 0  -> success
;             eax = -1 -> error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc peer._.handshake _torrent, _peer

            locals
                socketnum       dd ?
            endl
            
            DEBUGF 2, "INFO : In peer._.handshake\n"   

            push        ebx edx ecx esi edi

            mcall       40, EVM_STACK

            ;Preparing socket structure
            mov     ebx, [_peer]
            mov     eax, [ebx+peer.port]
            xchg    al , ah                   ;convert port number to network byte order
            mov     [sockaddr_peer.port],ax
            mov     eax, [ebx+peer.ipv4]
            mov     [sockaddr_peer.ip],eax

            ;For testing
            ;mov        ax, [port]
            ;xchg       al, ah
            ;mov        [sockaddr_peer.port],ax
            ;mov        eax, [ipaddress]
            ;mov        [sockaddr_peer.ip],eax
            
            ;Opening a socket
            mcall   socket, AF_INET4, SOCK_STREAM, 0
            cmp     eax, -1
            jnz     @f
            DEBUGF 3, "ERROR : Open socket : %d\n",ebx
            jmp     .error

            ;Connecting with peer
        @@: mov     [socketnum], eax
            mcall   connect, [socketnum], sockaddr_peer, sockaddr_peer.length
            cmp     eax, -1
            jnz     @f
            DEBUGF 3, "ERROR : Connect %d\n",ebx
            jmp     .error          

            ;Preparing handshake message
        @@: stdcall  message._.prep_handshake_msg, [_torrent], [_peer], handshake_msg
            lea      edi, [handshake_msg]
            DEBUGF 2, "INFO : Source Handshake Message : %s\n", edi            

            ;Sending handshake message to peer
            mcall    send, [socketnum], handshake_msg, HANDSHAKE_MSGLEN
            cmp      eax, -1
            jnz      @f
            DEBUGF 3, "ERROR: send %d\n",ebx
            jmp     .error

        @@: DEBUGF 2, "INFO : Number of bytes copied : %d\n",eax
            
            ;receving response from peer
            stdcall    torrent._.nonblocking_recv, [socketnum], RECV_TIMEOUT, recv_buffer, BUFFERSIZE
            cmp      eax, -1
            jnz      @f
            DEBUGF 3, "ERROR : recv %d.\n",ebx
            jmp     .error

        @@: lea     esi, [recv_buffer]
            DEBUGF 2, "INFO : Dest Handshake Message : %s\n", esi

            ;Verifying handshake response
            stdcall  message._.ver_handshake_msg, [_torrent], [_peer], recv_buffer
            cmp      eax, -1
            jne      .handshake_done
            DEBUGF 3, "ERROR : Handshake message verification failed\n"
            jmp      .error
    
    .handshake_done:        
            DEBUGF 2, "INFO : Handshake message verified.\n"

            ;preparing interested message
            stdcall  message._.prep_nopayload_msg, nopayload_msg, BT_PEER_MSG_INTERESTED
            mcall    send, [socketnum], nopayload_msg, NOPAYLOAD_MSGLEN
            cmp      eax, -1
            jne      .interested_sent
            DEBUGF 3, "ERROR: send %d\n",ebx
            mov      ebx, [_peer]
            mov      [ebx+peer.am_interested], 0
            jmp      .error
    
    .interested_sent:        
            mov      ebx, [_peer]
            mov      [ebx+peer.am_interested], 1
            DEBUGF 2, "INFO : Interested message sent.\n"

            mov       eax, [socketnum]
            mov       [ebx+peer.sock_num], eax
            mcall     26, 9
            mov       [ebx + peer.last_seen], eax
            jmp       .quit

    .error: DEBUGF 3, "ERROR : Procedure ended with error.\n"
            mcall      close, [socketnum]
            mov        ebx, [_peer]
            mov        [ebx + peer.sock_num], -1
            mov        eax,-1
            pop        edi esi ecx edx ebx
            ret

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully.\n"
            mov        eax, 0
            pop        edi esi ecx edx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc       : Performs message passing
;Input      : pointer to torrent data structure and peer data structure
;Outcome    : Sets details for peer data-structure like sock_num, last_seen, is_choking 
;ErrorCodes : eax = 0  -> success
;              eax = -1 -> error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Performs message passsing
proc peer._.communicate _torrent, _peer
            
            locals
                timeout         dd ?
                socketnum       dd ?
                length          dd ? ;message length
                type            db ? ;message type
            endl

            DEBUGF 2, "INFO : In peer._.communicate\n"
            push    ebx ecx edx esi edi

            ;filling socketnum
            mov     ebx, [_peer]
            mov     eax, [ebx+peer.sock_num]
            mov     [socketnum], eax

            ;checking keep-alive time limit exceeded?
            mcall   26, 9
            sub     eax, [ebx + peer.last_seen]
            cmp     eax, KEEPALIVE_TIME
            jge     .close

            ;preparing time for time-out
            mcall   26, 9
            add     eax, PEER_TIMEOUT*100
            mov     [timeout], eax

    .timer_loop:
            mcall   26, 9
            cmp     eax, [timeout]
            jge     .quit_timeout

            stdcall torrent._.nonblocking_recv, [socketnum], RECV_TIMEOUT, recv_buffer, BUFFERSIZE
            cmp      eax, -1
            jnz      @f
            DEBUGF 3, "ERROR : recv %d.\n",ebx
            jmp     .error

        @@: mov     ecx, eax                  ;number of bytes
            lea     esi, [recv_buffer]

    .buffer_loop:
            cmp     ecx, 0
            je      .send_msg 
            lodsd
            bswap   eax           
            mov     [length], eax             ;length of message
            sub     ecx, 4
            lodsb
            mov     [type], al                ;type of message
            dec     ecx

            ;keep-alive message
            cmp     [length], 0
            jne      @f
            DEBUGF 2, "INFO : Keep-alive msg\n"
            jmp     .quit

    @@:     dec     [length]                  ;as type of message is included in total length

            ;Bitfield message
            cmp     [type], BT_PEER_MSG_BITFIELD
            jne     @f
            DEBUGF 2, "INFO : Bitfield Message(%x)\n",[type]
            stdcall message._.process_bitfield_msg, [_torrent], [_peer], esi, [length]
            cmp     eax, -1
            je      .error
            jmp     .common

            ;Choke message
        @@: cmp     [type], BT_PEER_MSG_CHOKE
            jne     @f
            DEBUGF 2, "INFO : Choke Message(%x)\n",[type]
            mov      ebx, [_peer]
            mov     [ebx + peer.is_choking], 1
            jmp     .common 

            ;Unchoke message
        @@: cmp     [type], BT_PEER_MSG_UNCHOKE
            jne     @f    
            DEBUGF 2, "INFO : Unchoke Message(%x)\n",[type]
            mov      ebx, [_peer]
            mov     [ebx + peer.is_choking], 0            
            jmp     .common

            ;Have message
        @@: cmp     [type], BT_PEER_MSG_HAVE
            jne     @f
            DEBUGF 2, "INFO : Have Message(%d)\n", [type]
            stdcall message._.process_have_msg, [_peer], esi
            jmp     .common

            ;Piece message
        @@: cmp     [type], BT_PEER_MSG_PIECE
            jne     @f
            DEBUGF 2, "INFO : Piece Message(%x)\n", [type]
            stdcall  message._.process_piece_msg,[_torrent], [_peer], esi, ecx, [length], recv_buffer
            cmp      eax, -1
            je       .error
            jmp      .send_msg

    .common:
            sub      ecx, [length]
            jmp      .buffer_loop

    .send_msg:
            mov      ebx, [_peer]        
            cmp     [ebx + peer.is_choking], 0
            jne     .timer_loop    
            stdcall  message._.prep_request_msg, [_torrent], [_peer], request_msg
            cmp      eax, -1
            jne      @f
            DEBUGF 3, "INFO : Problem with request message\n"
            jmp      .error

        @@: mcall    send, [socketnum], request_msg, REQUEST_MSGLEN
            cmp      eax, -1
            jne      .timer_loop
            DEBUGF 3, "ERROR: send %d\n",ebx
            jmp      .error


    .close: mcall    close, [socketnum]
            mov      [ebx + peer.sock_num], -1
            DEBUGF 3, "ERROR : keep-alive timeout\n"

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            mov     eax, -1
            pop     edi esi edx ecx ebx
            ret

    .quit_timeout:
            DEBUGF 3, "ERROR : Timeout for peer\n"                    

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
            mcall   26, 9
            mov     [ebx + peer.last_seen], eax
            pop     edi esi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Data Area ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Data for handshake
sockaddr_peer:  
                        dw AF_INET4
        .port           dw 0       
        .ip             dd 0
                        rb 10
        .length         =  $ - sockaddr_peer

handshake_msg           rb HANDSHAKE_MSGLEN

;Data for communication
nopayload_msg           rb NOPAYLOAD_MSGLEN
request_msg             rb REQUEST_MSGLEN
recv_buffer             rb BUFFERSIZE
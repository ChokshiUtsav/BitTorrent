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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods which perform general operations

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Procedure Area ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Converts string of digits to number
;Input   : pointer to number
;outcome : Stores number to location pointed by EDI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent._.print_num _num
        push    ebx

        DEBUGF 2,"INFO : In torrent._.print_num\n"
        mov     eax, [_num]
        mov     ebx, 10
        xor     ecx, ecx

    @@:
        xor     edx, edx
        div     ebx
        push    edx
        inc     ecx
        test    eax, eax
        jnz     @b

    @@:
        pop     eax
        add     eax, '0'
        stosb
        dec     ecx
        jnz     @b


        DEBUGF 2,"INFO : Procedure ended successfully\n"
        pop     ebx
        ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Time-out based implementation of non-blocking receive
;Input   : Socket number, time for timeout, pointer to buffer, length of buffer
;outcome : eax = number of bytes recieved (incase , we recieve data)
;          eax = -1 -> recv fails
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent._.nonblocking_recv _socknum, _seconds, _buffer, _bufferlen

            locals
                timeout     dd ?
            endl

            push    ebx ecx edx esi edi

            mov     ebx,[_seconds]
            imul    ebx,100
            mcall   26,9 
            add     eax, ebx
            mov     [timeout], eax
    .recv_loop:
            mcall   23, 50
            cmp     eax, [timeout]
            jge     .error_timeout
            mcall   recv,[_socknum],[_buffer],[_bufferlen],MSG_DONTWAIT
            cmp     eax, -1
            jne     .quit
            cmp     ebx, EWOULDBLOCK
            jne     .error_socket
            jmp     .recv_loop

    .error_timeout:
            DEBUGF 3, "ERROR : Recv : Timed Out\n"
            mov     eax, -1
            pop     ebx
            ret

    .error_socket:
            DEBUGF 3, "ERROR : Recv : Socket Error\n"
            mov     eax, -1
            pop     edi esi edx ecx ebx
            ret            

    .quit:  DEBUGF 2, "INFO : Number of bytes recieved : %d\n", eax
            pop     edi esi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Desc  : Prints torrent details
; Input : Pointer to torrent data structure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Printing torrent details
proc torrent._.print_torrent _torrent
        push    ebx esi edi
        DEBUGF 2,'Print torrent at %x\n',[_torrent]
        mov     ebx, [_torrent]
        DEBUGF 2,'  trackers_cnt: %d\n',[ebx + torrent.trackers_cnt]
        DEBUGF 2,'  trackers:\n'
        xor     ecx, ecx
        mov     edx, [ebx + torrent.trackers]
  .next_tracker:
        cmp     ecx, [ebx + torrent.trackers_cnt]
        jz      .trackers_done
        lea     eax, [edx + tracker.announce]
        push    ebx
        mov     ebx, [edx + tracker.announce_len]
        DEBUGF 2,'    %s\n',eax:ebx
        pop     ebx
        add     edx, sizeof.tracker
        inc     ecx
        jmp     .next_tracker
  .trackers_done:
        DEBUGF 2,'  peers_cnt: %d\n',[ebx + torrent.peers_cnt]
        DEBUGF 2,'  peers:\n'
        mov     ecx, [ebx + torrent.peers_cnt]
        mov     edx, [ebx + torrent.peers]
  .next_peer:
        jecxz   .peers_done
        stdcall torrent._.print_peer, edx
    @@: add     edx, sizeof.peer
        dec     ecx
        jmp     .next_peer
  .peers_done:
        DEBUGF 2,'  pieces_length: %d\n',[ebx + torrent.piece_length]
        DEBUGF 2,'  pieces_cnt: %d\n',[ebx + torrent.pieces_cnt]
        DEBUGF 2,'  files_cnt: %d\n',[ebx + torrent.files_cnt]
        DEBUGF 2,'  files:\n'
        mov     ecx, [ebx + torrent.files_cnt]
        mov     edx, [ebx + torrent.files]
  .next_file:
        jecxz   .files_done
        lea     eax, [edx + 4]
        DEBUGF 2,'    %d %s\n',[edx],eax
        add     edx, 0x1000
        dec     ecx
        jmp     .next_file
  .files_done:
        pop     edi esi ebx
        ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Desc  : Prints peer details
; Input : Pointer to peer data structure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent._.print_peer _peer
        push    ebx esi edi
        DEBUGF 2,'  print peer at %x\n',[_peer]
        mov     ebx, [_peer]
        mov     eax, [ebx + peer.ipv4]
        DEBUGF 2,'    ipv4: %u.%u.%u.%u\n', \
        [ebx + peer.ipv4 + 0]:1, [ebx + peer.ipv4 + 1]:1, \
        [ebx + peer.ipv4 + 2]:1, [ebx + peer.ipv4 + 3]:1

        mov     eax, dword[ebx + peer.ipv6 + 0x0]
        DEBUGF 2,'    ipv6: %x',eax
        mov     eax, dword[ebx + peer.ipv6 + 0x4]
        DEBUGF 2,' %x',eax
        mov     eax, dword[ebx + peer.ipv6 + 0x8]
        DEBUGF 2,' %x',eax
        mov     eax, dword[ebx + peer.ipv6 + 0xc]
        DEBUGF 2,' %x\n',eax
        mov     eax, [ebx + peer.port]
        DEBUGF 2,'    port: %u\n',eax
        lea   eax, [ebx + peer.peer_id]
        DEBUGF 2,'    id: %s\n',eax:20
        lea     eax, [ebx + peer.url]
        DEBUGF 2,'    url: %s\n',eax
        movzx   eax, [ebx + peer.am_choking]
        DEBUGF 2,'    am_choking: %d\n',eax
        movzx   eax, [ebx + peer.am_interested]
        DEBUGF 2,'    am_interested: %d\n',eax
        movzx   eax, [ebx + peer.is_choking]
        DEBUGF 2,'    is_choking: %d\n',eax
        movzx   eax, [ebx + peer.is_interested]
        DEBUGF 2,'    is_interested: %d\n',eax
        movzx   eax, [ebx + peer.protocol]
        DEBUGF 2,'    protocol: %d\n',eax
        pop     edi esi ebx
        ret
endp
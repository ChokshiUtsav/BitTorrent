;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Procedure Area ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc peer._.handshake _torrent, _peer
	
			push ebx edx ecx esi edi

			DEBUGF 2, "INFO : In peer._.handshake\n"

			mcall   40, EVM_STACK

			;Preparing socket structure
			mov		ebx, [_peer]
			mov		eax, [ebx+peer.port]
			xchg	al , ah					  ;convert port number to network byte order
			mov		[sockaddr_peer.port],ax
			mov		eax, [ebx+peer.ipv4]
			mov		[sockaddr_peer.ip],eax

			;Preparing handshake message
			lea		edi, [handshake_msg]
			movzx   eax, [protocol_string_len]
			stosb
			lea		esi, [protocol_string]
			movzx	ecx, [protocol_string_len]
			rep     movsb
			mov     eax, 0
			mov     ecx, 8
			rep     stosb

			mov     ebx, [_torrent]
			lea		esi, [ebx+torrent.info_hash]
			mov     ecx, 20
			rep     movsb
			lea     esi, [ebx+torrent.peer_id]
			mov     ecx, 20
			rep     movsb

			lea     edi, [handshake_msg]
    		DEBUGF 2, "INFO : Source Handshake Message : %s\n", edi
			
			;Opening a socket
			mcall   socket, AF_INET4, SOCK_STREAM, 0
			cmp     eax, -1
		    jnz     @f
		    DEBUGF 3, "ERROR : Open socket : %d\n",ebx
		    jmp		.error

		    ;Connecting with peer
	@@:	    mov   	[socketnum], eax
			mcall   connect, [socketnum], sockaddr_peer, sockaddr_peer.length
			cmp		eax, -1
        	jnz     @f
			DEBUGF 3, "ERROR : Connect %d\n",ebx
		    jmp		.error        	

		    ;Sending handshake message to peer
    @@:    	mcall   send, [socketnum], handshake_msg, handshake_msg.length
    		cmp		eax, -1
    		jnz		@f
    		DEBUGF 3, "ERROR: send %d\n",ebx
    		jmp		.error

    @@:		DEBUGF 2, "INFO : Number of bytes copied : %d\n",eax
    		;receving response from peer
    		mcall   recv, [socketnum], buffer, buffer.length, 0
    		cmp     eax, -1
        	jnz      @f
        	DEBUGF 3, "ERROR : Connection terminated.\n"
        	jmp		.error

    @@:		lea     edi, [buffer]
    		DEBUGF 2, "INFO : Dest Handshake Message : %s\n", edi

    		;Verifying handshake response
    		mov     al, byte [edi]
    		cmp		al, byte [protocol_string_len]
    		jne		.close

    		inc     edi
    		lea		esi, [protocol_string]
    		movzx   ecx, [protocol_string_len]
    		repe    cmpsb
    		cmp     ecx, 0
    		jne		.close

    		add     edi, 8	;Ignoring 8 bytes reserved for protocol extension

    @@:     mov     ebx, [_torrent]
    		lea		esi, [ebx+torrent.info_hash]
    		mov     ecx, 20
    		repe    cmpsb
    		cmp     ecx, 0
    		jne     .close

    		mov     ebx, [_peer]				;Copying peer_id
    		lea     esi, [ebx + peer.peer_id]
    		mov     ecx, 20
    		rep     movsb
    		cmp     ecx, 0
    		jne     .close
    		lea		esi,[ebx + peer.peer_id]
    		DEBUGF 2, "INFO : Peer Id : %s.\n",esi
    		DEBUGF 2, "INFO : Handshake message verfied.\n"
    		jmp 	.quit

    .close:	DEBUGF 3, "ERROR : Closing connection as handshake verification failed"
    		mcall	close, [socketnum]	

	.error: DEBUGF 2, "INFO : Procedure ended with error.\n"
			mcall	close, [socketnum]
			mov 	eax,-1
			pop edi esi ecx edx ebx
		    ret

	.quit:	DEBUGF 2, "INFO : Procedure ended successfully.\n"
			mov		eax, socketnum     
			pop edi esi ecx edx ebx
		    ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Data Area ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

socketnum       	dd 0

sockaddr_peer:	
					dw AF_INET4
		.port   	dw 0       
		.ip     	dd 0
        			rb 10
		.length 	=  $ - sockaddr_peer

MSGLEN				 = 68

buffer          	rb MSGLEN
.length				 = MSGLEN

protocol_string_len db 19
protocol_string		db 'BitTorrent protocol'

handshake_msg		rb MSGLEN
.length				=  MSGLEN
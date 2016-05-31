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
			mov     eax, protocol_string_len
			stosb 
			lea		esi, [protocol_string]
			mov		ecx, 19
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
			
			;Opening a socket
			mcall   socket, AF_INET4, SOCK_STREAM, 0
			cmp     eax, -1
		    jnz     @f
		    DEBUGF 3, "ERROR : Open socket : %d\n",ebx
		    jmp		.error

		    ;Connecting with peer
	@@:		mov   	[socketnum], eax
			mcall   connect, [socketnum], sockaddr_peer, sockaddr_peer.length
			cmp		eax, -1
        	jnz     @f
			DEBUGF 3, "ERROR : Connect %d\n",ebx
		    jmp		.error        	

		    ;Sending handshake message to peer
    @@:		mcall   send, [socketnum], handshake_msg, handshake_msg.length
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
    		DEBUGF 2, "INFO : Message : %s\n", edi

    		;Verifying handshake response
    		mov     al, byte [edi]
    		cmp		al, [protocol_string_len]
    		jne		.close
    		inc     edi
    		lea		esi, [protocol_string]
    		mov     ecx, protocol_string_len
    		repe    cmpsb
    		cmp     ecx, 0
    		jne		.close
    		mov     ecx, 0
    .loop:	cmp     byte [edi], 0
    		jne 	.close
    		inc 	edi
    		inc     ecx
    		cmp     ecx, 8
    		je 		@f
    		jmp     .loop
    
    @@:     mov     ebx, [_torrent]
    		lea		esi, [ebx+torrent.info_hash]
    		mov     ecx, 20
    		repe    cmpsb
    		cmp     ecx, 0
    		jne     .close

    		mov     ebx, [_peer]
    		lea     esi, [ebx+peer.peer_id]
    		mov     ecx, 20
    		repe    cmpsb
    		cmp     ecx, 0
    		jne     .close
    		DEBUGF 2, "INFO : Handshake message verfied.\n"
    		jmp 	.quit

    .close:	DEBUGF 2, "ERROR : Closing connection as verification failed"
    		mcall	close, [socketnum]	

	.error: DEBUGF 2, "INFO : Procedure ended with error.\n"
			mov 	eax,-1
			pop edi esi ecx edx ebx
		    ret

	.quit:	DEBUGF 2, "INFO : Procedure ended successfully.\n"
			;mov		eax, socketnum
			mov   	 eax, 0     
			pop edi esi ecx edx ebx
		    ret
endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Data Area ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

socketnum       dd 0

sockaddr_peer:	
				dw AF_INET4
		.port   dw 0       
		.ip     dd 0
        		rb 10
		.length = $ - sockaddr_peer

MSGLEN			= 68

hello   		db 'Hello world!',0
.length 		= $ - hello

buffer          rb MSGLEN
.length			 = MSGLEN

protocol_string_len db 19
protocol_string		db 'BitTorrent protocol'

handshake_msg	rb MSGLEN
.length			=  MSGLEN
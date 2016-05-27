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
			lea		esi, [protocol_string]
			mov		ecx, 29
			rep     movsb
			mov     ebx, [_torrent]
			lea		esi, [ebx+torrent.info_hash]
			mov     ecx, 20
			rep     movsb
			lea     esi, [ebx+torrent.peer_id]
			mov     ecx, 20
			rep     movsb

			DEBUGF 2, "INFO : Hanshake message : %s\n", handshake_msg

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

    @@:		;mov     esi, buffer
    		;DEBUGF 2, "INFO : Message : %s\n", esi
    		jmp 	.quit	

	.error: DEBUGF 2, "INFO : Procedure ended with error.\n"
			mov 	eax,-1
			pop edi esi ecx edx ebx
		    ret

	.quit:	DEBUGF 2, "INFO : Procedure ended successfully.\n"
			mov		eax, 0
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

BUFFERSIZE      = 1500
MSGLEN			= 69

hello   		db 'Hello world!',0
.length 		= $ - hello

buffer          rb BUFFERSIZE
.length			 = BUFFERSIZE

protocol_string	db '19BitTorrent protocol00000000'

handshake_msg	rb MSGLEN
.length			=  MSGLEN

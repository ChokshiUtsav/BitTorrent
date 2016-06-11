;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Procedure Area ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc peer._.handshake _torrent, _peer
	
			push ebx edx ecx esi edi

			DEBUGF 2, "INFO : In peer._.handshake\n"

			mcall   40, EVM_STACK

			;Preparing socket structure
			;mov		ebx, [_peer]
			;mov		eax, [ebx+peer.port]
			;xchg	    al , ah					  ;convert port number to network byte order
			;mov		[sockaddr_peer.port],ax
			;mov		eax, [ebx+peer.ipv4]
			;mov		[sockaddr_peer.ip],eax

			;For testing
			 mov        ax, [port]
			 xchg       al, ah
			 mov        [sockaddr_peer.port],ax
			 mov        eax, [ipaddress]
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
    		mcall   recv, [socketnum], handshake_buffer, handshake_buffer.length, 0
    		cmp     eax, -1
        	jnz      @f
        	DEBUGF 3, "ERROR : recv %d.\n",ebx
        	jmp		.error

    @@:		lea     edi, [handshake_buffer]
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
			mov		eax, [socketnum]   
			pop edi esi ecx edx ebx
		    ret
endp

proc peer._.communicate _torrent, _peer,_socketnum
	
			push 	ebx edx ecx esi edi
			DEBUGF 2, "INFO : In peer._.communicate\n"

			;Sending interested message
			mcall 	send, [_socketnum], interested_msg, interested_msg.length
			cmp		eax, -1
    		jnz		.loop
    		DEBUGF 3, "ERROR: send %d\n",ebx
    		jmp		.error
    		mov  	ebx, [_peer]
        	mov     [ebx+peer.am_interested], 0

	 .loop: mcall   recv, [_socketnum], communication_buffer, communication_buffer.length, 0
			cmp     eax, -1
        	jnz      @f
        	DEBUGF 3, "ERROR : recv %d\n",ebx
        	jmp		.error	

        @@: DEBUGF 2, "INFO : Bytes copied %d\n",eax
        	lea		esi, [communication_buffer]
        	mov     eax, dword [esi] 			;length of message
        	add     esi, 4
        	movzx   ebx, byte [esi]				;type of message
        	inc     esi

        	;ignore extended type of messages
        	cmp     ebx, BT_PEER_MSG_EXTENDED
        	jne     @f
        	DEBUGF 2, "INFO : Extended Message (%d)\n", ebx
        	jmp     .loop

        	;ignore interested type of messages
        @@: cmp     ebx, BT_PEER_MSG_INTERESTED
        	jne     @f
        	DEBUGF 2, "INFO : Interested Message (%d)\n", ebx
        	jmp     .loop

        	;ignore not-interested type of messages
        @@: cmp     ebx, BT_PEER_MSG_NOT_INTERESTED
        	jne     @f
        	DEBUGF 2, "INFO : Not-Interested Message (%d)\n", ebx
        	jmp     .loop

        	;Unchoke message
        @@:	cmp 	ebx, BT_PEER_MSG_UNCHOKE
        	jne     @f
        	DEBUGF 2, "INFO : Unchoke Message (%d)\n", ebx
        	mov  	ebx, [_peer]
        	mov     [ebx+peer.is_choking], 0
        	jmp     .unchoked

        	;Choke message
        @@:	cmp 	ebx, BT_PEER_MSG_CHOKE
        	jne     @f
        	DEBUGF 2, "INFO : Choke Message (%d)\n", ebx
        	jmp     .loop

        	;Bitfield message
        @@:	cmp 	ebx, BT_PEER_MSG_BITFIELD
        	jne     @f
        	DEBUGF 2, "INFO : Bitfield Message (%d)\n", ebx
        	jmp     .bitfield_verified
        	mov     ebx, [_peer]
        	sub     eax, 1
        	mov     ebx, [ebx+peer.bit_field]
        	mov     [ebx+ bit_field.size],eax
        	lea 	edi, [ebx+bit_field.bytes]
        	mov     ecx, eax
        	rep     movsb
        	cmp     ecx, 0
        	je      .bitfield_verified
        	DEBUGF 3, "ERROR : Corrupted bitfield message.\n"
        	jmp     .error

    .bitfield_verified:
    		mov     ebx, [_peer]
        	cmp 	[ebx+peer.is_choking], 0
        	je      .unchoked
        	jmp     .loop


        	;Have message
        @@:	cmp 	ebx, BT_PEER_MSG_HAVE
        	jne 	@f
        	DEBUGF 2, "INFO : Have Message (%d)\n", ebx
        	;logic for setting corresponding bit in bit-field
        	mov     ebx, [_peer]
        	cmp 	[ebx+peer.is_choking], 0
        	je      .unchoked
        	jmp     .loop

        	;Piece message
        @@: cmp     ebx, BT_PEER_MSG_PIECE
        	jne     .loop
        	DEBUGF 2, "INFO : Piece Message (%d)\n", ebx
        	;write logic for copying to file
        	jmp     .quit     

 	.unchoked:
 			;preparing a message for requesting a piece
 			 mcall  send, [_socketnum], sample_request_msg, sample_request_msg.length
 			 jnz		.loop
    		 DEBUGF 3, "ERROR: send %d\n",ebx
    		 jmp		.error


	.error: DEBUGF 2, "INFO : Procedure ended with error.\n"
			mcall	close, [_socketnum]
			mov 	eax,-1
			pop edi esi ecx edx ebx
		    ret		

	.quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
			mcall	close, [_socketnum]
			mov 	eax,0
			pop 	ebx edx ecx esi edi
			ret			

endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Data Area ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Data for handshake
socketnum       		dd 0
sockaddr_peer:	
						dw AF_INET4
		.port   		dw 0       
		.ip     		dd 0
        				rb 10
		.length 		=  $ - sockaddr_peer

MSGLEN				 	= 68
handshake_buffer     	rb MSGLEN
.length					 = MSGLEN

protocol_string_len 	db 19
protocol_string			db 'BitTorrent protocol'

handshake_msg			rb MSGLEN
.length					=  MSGLEN

;Data for file transfer and communication
communication_buffer  	rb 4096
.length					=  $-communication_buffer

interested_msg:
		.len        	dd 0x01000000
		.id         	db BT_PEER_MSG_INTERESTED
.length             	=  $-interested_msg

sample_request_msg:
		.len        	dd 0x0d000000
		.id         	db BT_PEER_MSG_REQUEST
		.piece_index	dd 0x00000000
		.begin_offset   dd 0x00000000
		.block_length   dd 0x00400000
.length                 =  $-sample_request_msg


ipaddress:
					db 80 
					db 71
					db 131
					db 244

port                dw 51413
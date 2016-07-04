;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;Header Area;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

format binary as ""

;standard header
use32
        org     0x0
        db      'MENUET01'      ; signature
        dd      0x01            ; header version
        dd      START           ; entry point
        dd      I_END           ; initialized size
        dd      E_END   		; required memory
        dd      E_END		    ; stack pointer
        dd      0		        ; parameters
        dd      0               ; path

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1
BUFFERSIZE		= 1500


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;Include Area;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

include 'struct.inc'
include 'proc32.inc'
include 'macros.inc'
include 'config.inc'
include 'network.inc'
include 'debug-fdo.inc'
include 'dll.inc'
include 'libio.inc'
include 'torrent.inc'
include 'torrent_actions.inc'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;Code Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

START:
			;init heap
		    mcall   68, 11
		    test    eax, eax
		    jnz		@f
		    DEBUGF 3, "ERROR : Problem allocating heap space.\n"
		    jz      .error

			;load libraries
	@@:	    stdcall dll.Load, @IMPORT
		    test    eax, eax
		    jz 		@f
		    DEBUGF 3, "ERROR : Problem loading libraries.\n"
		    jmp     .error


		    ;Start listening on port 50000 for incoming requests from frontend
	@@: 	mcall   40, EVM_STACK

			mcall   socket, AF_INET4, SOCK_STREAM, 0
    	    cmp     eax, -1
        	je      .sock_err
        	mov     [socketnum], eax

        	mcall   bind, [socketnum], sockaddr, sockaddr.length
        	cmp     eax, -1
        	je      .bind_err

        	mcall   listen, [socketnum], 10 ; Backlog = 10
        	cmp     eax, -1
        	je      .listen_err

    .accept_connection:
    		DEBUGF 2, "INFO : Listening for incoming connection\n"    	
    		mcall   accept, [socketnum], sockaddr, sockaddr.length
        	cmp     eax, -1
        	je      .accept_err
        	mov     [socketnum2], eax


        	DEBUGF 2, "INFO : Connection accepted\n"
        	mcall   send, [socketnum2], handshake_msg, handshake_msg.length
        	mcall	close, [socketnum2]
        	DEBUGF 2, "INFO : Connection closed\n"
	        jmp		.accept_connection

  	.loop:
        	mcall   recv, [socketnum2], buffer, buffer.length, 0
        	cmp     eax, -1
        	je      .loop
		
        	mov     byte[buffer+eax], 0			;eax contains number of bytes copied

        	; protocol : <msg-length><msg-type><msg-payload>
        	lea		esi, [buffer]
        	movzx   eax, word[esi]
        	mov     [length_of_msg], ax
        	add     esi, 2

        	cmp     byte[esi], TORRENT_ADD
        	je		.torrent_add

			cmp     byte[esi], TORRENT_START
        	je		.torrent_start

			cmp     byte[esi], TORRENT_PAUSE
        	je		.torrent_pause

			cmp     byte[esi], TORRENT_REMOVE
        	je		.torrent_remove
			
			cmp     byte[esi], TORRENT_SHOW
        	je		.torrent_show

        	cmp     byte[esi], TORRENT_QUIT
        	je		.torrent_quit

    .torrent_add:
	        mcall	close, [socketnum2]
	        jmp		.accept_connection

	.torrent_start:
			mcall	close, [socketnum2]
			jmp		.accept_connection

	.torrent_pause:
			mcall	close, [socketnum2]
			jmp		.accept_connection

	.torrent_remove:
			mcall	close, [socketnum2]
			jmp		.accept_connection

	.torrent_show:
			mcall	close, [socketnum2]
			jmp		.accept_connection

	.torrent_quit:
			mcall	close, [socketnum2]
			jmp		.accept_connection

	.sock_err:
			DEBUGF 3, "ERROR : Could not open socket.\n"
			jmp		.error

	.bind_err:
			DEBUGF 3, "ERROR : Bind error.\n"
			jmp		.error

	.listen_err:
			DEBUGF 3, "ERROR : Listen error.\n"
			jmp		.error

	.accept_err:
			DEBUGF 3, "ERROR : Accept error.\n"
			jmp		.error		

	.error: DEBUGF 3, "ERROR : Program ended with error.\n"


	.exit:  DEBUGF 2, "INFO : Program exited successfully.\n"    


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Import Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 16
@IMPORT:

library	\
        libio,   'libio.obj',\
        torrent, 'torrent.obj'

import 	libio,\
        libio.init, 'lib_init'  ,   \
        file.open , 'file_open' ,   \
        file.read , 'file_read' ,   \
        file.write , 'file_write' , \
        file.seek, 'file_seek',     \
        file.close, 'file_close',   \
        file.size,	'file_size'

import torrent,\
	   lib_init, 	 'lib_init',    \
	   torrent.new,  'new',         \
       torrent.start,'start'    

include_debug_strings

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Data Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

sockaddr:
        		dw AF_INET4
		.port   dw 0x50C3             ; port 50000 = 0xC350 -in network byte order
		.ip     dd 0
        		rb 10
		.length = $ - sockaddr

handshake_msg	db 'Kolibrios_Bittorrent_Client',0
.length			=  $ - handshake_msg

length_of_msg	dw	0
type_of_msg		db  0
torrent_id		dd  0

torrent_filename1 db '/usbhd0/1/test.torrent',0
torrent_filename  rb 512

I_END:

socketnum		dd 0
socketnum2		dd 0
buffer          rb BUFFERSIZE
.length 		=  BUFFERSIZE

align 4
rb 0x1000      	; stack

E_END:
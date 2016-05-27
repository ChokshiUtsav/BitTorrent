;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;    libbmfnt -- torrent library
;
;    Copyright (C) 2015 Ivan Baravy (dunkaist)
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

format MS COFF

public @EXPORT as 'EXPORTS'

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;Include Area;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

include 'struct.inc'
include 'proc32.inc'
include 'macros.inc'
include 'libio.inc'
include 'debug-fdo.inc'
include 'struct.inc'
include 'torrent.inc'
include 'libcrash.inc'
include 'network.inc'
include 'http.inc'

purge section,mov,add,sub

include 'bencode.asm'
include 'tracker.asm'
include 'percent.asm'
include 'peer.asm'

virtual at 0
        http_msg http_msg
end virtual

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;Code Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section '.flat' code readable align 16

;Initializing library
proc lib_init
          mov     [mem.alloc], eax
          mov     [mem.free], ebx
          mov     [mem.realloc], ecx
          mov     [dll.load], edx
              
          invoke  dll.load, @IMPORT
          or  eax, eax
          jz  .libsok

          DEBUGF 3, "ERROR : Problem Initializing libraries.\n"
          xor eax, eax
          inc eax
          ret

 .libsok: DEBUGF 2, "INFO : Library Initialized Successfully.\n"
          xor eax,eax
          ret
endp

;Adding new torrent
proc torrent.new _bt_new_type, _src

			push    ebx esi edi

			DEBUGF 2, "INFO : In torrent.new\n"

			invoke  mem.alloc, sizeof.torrent
			test	eax, eax
			jnz 	@f
			DEBUGF 3, "ERROR : Not enough memory for new torrent\n"
			jmp 	.error

	@@:		mov 	ebx,eax
			invoke	mem.alloc, sizeof.ipc_buffer
			test	eax, eax
			jnz		@f
			DEBUGF 3, "ERROR : Not enough memory for ipc buffer\n"
			jmp 	.error

	@@:		mov     [ebx + torrent.ipc_buf], eax
        	mov     [ebx + torrent.uploaded], 0
        	mov     [ebx + torrent.downloaded], 0
        	mov     [ebx + torrent.left], 0
        	mov     [ebx + torrent.pid], 0

        	cmp     [ebx + torrent.trackers], 0
        	jnz     .trackers_allocated	 
        	invoke  mem.alloc, 0x2000
        	test    eax, eax
        	jnz     @f
        	DEBUGF 3, "ERROR: Not enough memory for trackers\n"
        	jmp     .error
    
    @@:    	mov		[ebx + torrent.trackers], eax

	.trackers_allocated:
			cmp     [ebx + torrent.peers], 0
			jnz		.peers_allocated
			invoke  mem.alloc, (MAX_PEERS_PER_TORRENT * sizeof.peer)
        	test    eax, eax
        	jnz     @f
        	DEBUGF 3,'ERROR: Not enough memory for peers\n'
        	jmp     .error

    @@:		mov     [ebx + torrent.peers], eax

    .peers_allocated:
    		lea     edi, [ebx + torrent.peer_id]
        	mov     esi, def_peer_id
        	mov     ecx, 20
        	rep 	movsb
        	mov     [ebx + torrent.port], def_port_num

        	cmp     [_bt_new_type], BT_NEW_FILE
        	jnz		.magnet

			stdcall torrent._.load_file, ebx, [_src]
			cmp		eax, -1
			jnz		.quit
			DEBUGF 3,"ERROR : Problem loading file\n"
			jmp		.error

    .magnet:
    		DEBUGF 3, "ERROR : Magnet links are not supported yet\n"    	
    		jmp		.error

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
			mov		eax, -1
			pop		edi esi ebx
			ret

	.quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
			mov   	eax, ebx
			pop		edi esi ebx	
			ret
endp


;Starting a torrent
proc torrent.start _torrent
	        push    ebx esi edi

	        DEBUGF 2, "INFO : In torrent.start\n"

	        mov     ebx, [_torrent]
	        invoke  mem.alloc, TORRENT_STACK_SIZE
	        test    eax, eax
	        jnz     @f
	        DEBUGF 3,'ERROR: Not enough memory for child stack\n'
	        jmp     .error
	
	@@:		mov     [ebx + torrent.stack], eax
	        invoke  mem.alloc, sizeof.ipc_buffer
	        test    eax, eax
	        jnz     @f
	        DEBUGF 3,'ERROR: Not enough memory for child ipc buffer\n'
	        jmp     .error

	@@:		mov     [ebx + torrent.ipc_buf], eax
	        mov     edx, [ebx + torrent.trackers]
	        stdcall torrent._.tracker_get, [_torrent], edx
	        cmp		eax,-1
	        jnz		@f
	        DEBUGF 3, "ERROR: Problem with connecting tracker.\n"
	        jmp		.error

	@@:     stdcall torrent._.print_torrent, [_torrent]
			jmp 	.quit


    .error:	DEBUGF 3, "ERROR: Procedure ended with error\n"
    		mov     eax, -1
    		pop 	edi esi ebx
	
	.quit:	DEBUGF 2, "INFO: Procedure ended successfully\n"
			mov     eax, 0
	        pop     edi esi ebx
	        ret
endp


;Loading torrent file
proc torrent._.load_file _torrent, _file
			
			push    ebx esi edi

			locals
	            filedesc dd ?
	            filebuf  dd ?
	            filesize dd ?
	        endl

			DEBUGF 2, "INFO : In torrent._.load_file\n"

			invoke  file.size, [_file]
			cmp     ebx, -1
			jnz		@f
			DEBUGF 3, "ERROR: file.size\n"
			jmp 	.error

	@@:		mov 	[filesize], ebx	
			invoke	mem.alloc, [filesize]
			test	eax,eax
			jnz		@f
			DEBUGF 3, "ERROR: Not enough memory for file\n"
			jmp		.error

	@@:		mov   	[filebuf], eax
			invoke	file.open, [_file], O_READ
			test	eax, eax
			jnz     @f
        	DEBUGF 3,"ERROR: file.open\n"
        	jmp      .error

    @@:		mov    	[filedesc], eax
    		invoke	file.read, [filedesc], [filebuf], [filesize]
    		cmp		eax, -1			
    		jnz     @f
        	DEBUGF 3,"ERROR: file.read\n"
        	jmp      .error

    @@:		invoke	file.close, [filedesc]
    		cmp		eax, -1
    		jnz		@f
    		DEBUGF 3,"ERROR: file.close\n"
    		jmp		.error

    @@:		mov  	esi, [filebuf]
    		mov 	eax, esi
    		inc 	esi
    		add 	eax, [filesize]
    		DEBUGF 2,"INFO : Intial content of torrent file %s\n",[filebuf]
    		DEBUGF 2,"INFO : Size of torrent file %d bytes\n",[filesize]

    		stdcall torrent._.bdecode_dict, [_torrent], eax, known_keys_0
    		DEBUGF 2,"INFO : Ben-decoding done successfully.\n"
    		jmp		.quit
	
    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
			mov		eax, -1
			pop		edi esi ebx
			ret	

	.quit:	DEBUGF 2, "INFO : Procedure ended successfully\n"
			mov   	eax, 0
			pop		edi esi ebx	
			ret
endp

;Prints a number at location pointed by EDI
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


        stdcall peer._.handshake,[_torrent],edx
        

        add     edx, sizeof.peer
        dec     ecx
        jmp     .next_peer
  .peers_done:
        DEBUGF 2,'  pieces_length: %d\n',[ebx + torrent.piece_length]
        DEBUGF 2,'  pieces_cnt: %d\n',[ebx + torrent.pieces_cnt]
;        DEBUGF 2,'  pieces:\n'
;        mov     ecx, [ebx + torrent.pieces_cnt]
;        mov     edx, [ebx + torrent.pieces]
;  .next_piece:
;        DEBUGF 2,'    %x%x%x%x%x\n',[edx+0x0],[edx+0x4],[edx+0x8],[edx+0xc],[edx+0x10]
;        add     edx, 20
;        dec     ecx
;        jnz     .next_piece
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

proc torrent._.print_peer _peer
        push    ebx esi edi
        DEBUGF 2,'  print peer at %x\n',[_peer]
        mov     ebx, [_peer]
        mov     eax, [ebx + peer.ipv4]
;        DEBUGF 2,'    ipv4: %x\n',eax
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




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;Import & Export Area;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

align 16
@EXPORT:

export                                      \
        lib_init           , 'lib_init'   , \
        torrent.new        , 'new'		  , \
        torrent.start      , 'start'

align 16
@IMPORT:

library                            \
		network,   'network.obj' , \
        lib_http,  'http.obj'    , \
        libio,     'libio.obj',	   \
        libcrash,  'libcrash.obj'

import network,                       \
        getaddrinfo,  'getaddrinfo' , \
        freeaddrinfo, 'freeaddrinfo', \
        inet_ntoa,    'inet_ntoa'

import lib_http                , \
        http.get,     'get'    , \
        http.free,    'free'   , \
        http.receive, 'receive'

import  libio                    , \
        libio.init, 'lib_init'  , \
        file.size , 'file_size' , \
        file.open , 'file_open' , \
        file.read , 'file_read' , \
        file.close, 'file_close',\
        file.seek, 'file_seek'

import libcrash			        , \
	libcrash.init  , 'lib_init'	, \
	crash.hash     , 'crash_hash'	, \
	crash.bin2hex  , 'crash_bin2hex'



include_debug_strings


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Data Area ;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section '.data' data readable writable align 16

mem.alloc       dd ?
mem.free        dd ?
mem.realloc     dd ?
dll.load        dd ?
def_peer_id 	db '-KS0001-123456654321'     ;KS for KolibriOS
def_port_num    dd 60001
fileinfo        dd 2, 0, 0
final_size      dd 0
final_buffer    dd 0
                db 0
                dd fname_buf
fname_buf       db '/usbhd0/1/get.out',0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;    libbmfnt -- torrent library
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

format MS COFF

public @EXPORT as 'EXPORTS'

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;Include Area;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

include 'includes/struct.inc'
include 'includes/proc32.inc'
include 'includes/macros.inc'
include 'includes/libio.inc'
include 'includes/debug-fdo.inc'
include 'includes/struct.inc'
include 'torrent.inc'
include 'torrent_errors.inc'
include 'includes/libcrash.inc'
include 'includes/network.inc'
include 'includes/http.inc'

purge section,mov,add,sub

include 'includes/sha1.asm'
include 'hash.asm'
include 'piece.asm'
include 'fileops.asm'
include 'memops.asm'
include 'genops.asm'
include 'bitfield.asm'
include 'bencode.asm'
include 'tracker.asm'
include 'percent.asm'
include 'message.asm'
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Fills torrent structure for new torrent
;Input     : torrent source type, torrent file location, download location
;Outcome   : array of pieces filled with details
;ErrorCode : if successs -> eax = pointer to torrent structure
;            if error    -> eax = -1  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Adding new torrent
proc torrent.new _bt_new_type, _src, _downloadlocation

            push    ebx esi edi

            DEBUGF 2, "INFO : In torrent.new\n"

            invoke  mem.alloc, sizeof.torrent
            test    eax, eax
            jnz     @f
            DEBUGF 3, "ERROR : Not enough memory for new torrent\n"
            jmp     .error

    @@:     mov     ebx,eax
            invoke  mem.alloc, sizeof.ipc_buffer
            test    eax, eax
            jnz     @f
            DEBUGF 3, "ERROR : Not enough memory for ipc buffer\n"
            mov     ebx, BT_ERROR_NOT_ENOUGH_MEMORY
            jmp     .error

    @@:     mov     [ebx + torrent.ipc_buf], eax
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
            mov     ebx, BT_ERROR_NOT_ENOUGH_MEMORY
            jmp     .error
    
    @@:     mov     [ebx + torrent.trackers], eax

    .trackers_allocated:
            cmp     [ebx + torrent.peers], 0
            jnz     .peers_allocated
            invoke  mem.alloc, (MAX_PEERS_PER_TORRENT * sizeof.peer)
            test    eax, eax
            jnz     @f
            DEBUGF 3,'ERROR: Not enough memory for peers\n'
            mov     ebx, BT_ERROR_NOT_ENOUGH_MEMORY
            jmp     .error

    @@:     mov     [ebx + torrent.peers], eax

    .peers_allocated:
            lea     edi, [ebx + torrent.peer_id]
            mov     esi, def_peer_id
            mov     ecx, 20
            rep     movsb
            mov     eax, [def_port_num]
            mov     [ebx + torrent.port], eax 

            cmp     [_bt_new_type], BT_NEW_FILE
            jnz     .magnet

            stdcall torrent._.load_file, ebx, [_src]
            cmp     eax, -1
            jne     .bencoding_done
            DEBUGF 3,"ERROR : Problem loading file\n"
            mov     ebx, BT_ERROR_INVALID_TORRENT_FILE
            jmp     .error

    .bencoding_done:
            lea     esi, [ebx + torrent.name]
            DEBUGF 2, "INFO : name %s\n", esi
            stdcall torrent._.allocate_file_space, ebx, [_downloadlocation] 
            cmp     eax, -1
            jne     .file_space_alloc_done        
            DEBUGF 3, "ERROR : Problem allocating file space\n"
            mov     ebx, BT_ERROR_INSUFF_HD_SPACE
            jmp     .error

    .file_space_alloc_done:
            stdcall torrent._.allocate_mem_space, ebx
            cmp     eax, -1
            jne     .quit
            DEBUGF 3, "ERROR : Insufficient memory for torrent downloading\n"
            mov     ebx, BT_ERROR_NOT_ENOUGH_MEMORY
            jmp     .error

    .magnet:
            DEBUGF 3, "ERROR : Magnet links are not supported yet\n"        
            jmp     .error

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            mov     eax, -1
            pop     edi esi
            ret

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
            mov     eax, ebx
            pop     edi esi 
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
    
    @@:     mov     [ebx + torrent.stack], eax
            invoke  mem.alloc, sizeof.ipc_buffer
            test    eax, eax
            jnz     @f
            DEBUGF 3,'ERROR: Not enough memory for child ipc buffer\n'
            jmp     .error

    @@:     mov     [ebx + torrent.ipc_buf], eax
            mov     edx, [ebx + torrent.trackers]
            stdcall torrent._.tracker_get, [_torrent], edx
            cmp     eax,-1
            jnz     @f
            DEBUGF 3, "ERROR: Problem with connecting tracker.\n"
            jmp     .error

    @@:     stdcall  torrent._.prep_active_peers, [_torrent]
            cmp      eax, 0
            jne      @f
            DEBUGF 3, "ERROR: No active peers found.\n"
            jmp      .error

    @@:     stdcall  torrent._.communicate_active_peers, [_torrent]
                            
            ;stdcall torrent._.print_torrent, [_torrent]
            jmp     .quit


    .error: DEBUGF 3, "ERROR: Procedure ended with error\n"
            mov     eax, -1
            pop     edi esi ebx
    
    .quit:  DEBUGF 2, "INFO: Procedure ended successfully\n"
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
            jnz     @f
            DEBUGF 3, "ERROR: file.size\n"
            jmp     .error

    @@:     mov     [filesize], ebx 
            invoke  mem.alloc, [filesize]
            test    eax,eax
            jnz     @f
            DEBUGF 3, "ERROR: Not enough memory for file\n"
            jmp     .error

    @@:     mov     [filebuf], eax
            invoke  file.open, [_file], O_READ
            test    eax, eax
            jnz     @f
            DEBUGF 3,"ERROR: file.open\n"
            jmp      .error

    @@:     mov     [filedesc], eax
            invoke  file.read, [filedesc], [filebuf], [filesize]
            cmp     eax, -1         
            jnz     @f
            DEBUGF 3,"ERROR: file.read\n"
            jmp      .error

    @@:     invoke  file.close, [filedesc]
            cmp     eax, -1
            jnz     @f
            DEBUGF 3,"ERROR: file.close\n"
            jmp     .error

    @@:     mov     esi, [filebuf]
            mov     eax, esi
            inc     esi
            add     eax, [filesize]
            stdcall torrent._.bdecode_dict, [_torrent], eax, known_keys_0
            DEBUGF 2,"INFO : Ben-decoding done successfully.\n"
            jmp     .quit
    
    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            mov     eax, -1
            pop     edi esi ebx
            ret 

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
            mov     eax, 0
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
        torrent.new        , 'new'        , \
        torrent.start      , 'start'

align 16
@IMPORT:

library                            \
        network,   'network.obj' , \
        lib_http,  'http.obj'    , \
        libio,     'libio.obj',    \
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
        file.write , 'file_write' , \
        file.close, 'file_close',\
        file.seek, 'file_seek'

import libcrash                 , \
    libcrash.init  , 'lib_init' , \
    crash.hash     , 'crash_hash'   , \
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
def_peer_id     db '-KS0001-123456654321'     ;KS for KolibriOS
def_port_num    dd 60001
fileinfo        dd 2, 0, 0
final_size      dd 0
final_buffer    dd 0
                db 0
                dd fname_buf
fname_buf       db '/usbhd0/1/get.out',0
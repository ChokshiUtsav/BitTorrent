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

format MS COFF

public @EXPORT as 'EXPORTS'

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1

include '../../../struct.inc'
include '../../../proc32.inc'
include '../../../macros.inc'
include '../../../config.inc'
include '../../../network.inc'
include '../../../dll.inc'
include '../../../develop/libraries/http/http.inc'
;include '../../../develop/libraries/libs-dev/libini/libini.inc'
include '../../../develop/libraries/libs-dev/libio/libio.inc'
;include '../../../libio.inc'
include '../../../develop/libraries/libcrash/trunk/libcrash.inc'

include 'torrent.inc'

purge section,mov,add,sub
section '.flat' code readable align 16

include '../../../debug-fdo.inc'
include 'tracker.asm'
include 'peer.asm'
include 'bencode.asm'
include 'percent.asm'

virtual at 0
        http_msg http_msg
end virtual


proc lib_init
        mov     [mem.alloc], eax
        mov     [mem.free], ebx
        mov     [mem.realloc], ecx
        mov     [dll.load], edx

	invoke  dll.load, @IMPORT
	or	eax, eax
	jnz	.error
    
  .error:
  .quit:
        ret
endp

proc torrent.start _torrent
        push    ebx esi edi
        mov     ebx, [_torrent]

        invoke  mem.alloc, TORRENT_STACK_SIZE
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: not enough memory for child stack\n'
        jmp     .error
    @@:
        mov     [ebx + torrent.stack], eax

        invoke  mem.alloc, sizeof.ipc_buffer
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: not enough memory for child ipc buffer\n'
        jmp     .error
    @@:
        mov     [ebx + torrent.ipc_buf], eax


        mov     edx, [ebx + torrent.trackers]
        stdcall torrent.tracker_get, [_torrent], edx

        mov     eax, [_torrent]
        mov     edx, [eax + torrent.stack]
        add     edx, TORRENT_STACK_SIZE
        sub     edx, 4
        mov     [edx], eax
        mcall   51, 1, child_start, 
  .error:
  .quit:
        pop     edi esi ebx
        ret
endp


proc torrent.stop _torrent

        ret
endp


child_start:
        pop     eax
;        mov     [fs:0x100], eax
        lea     ebx, [eax + torrent.proc_info]
        push    eax
        mcall   9, , -1
        pop     ebx
        mov     eax, [ebx + torrent.proc_info.PID]
        mov     [ebx + torrent.pid], eax
        mov     ecx, [ebx + torrent.ipc_buf]
        push    ebx
        mcall   60, 1, , sizeof.ipc_buffer
        pop     ebx
        mov     eax, [ebx + torrent.pid]
        mov     [ebx + torrent.ipc_msg.pid], eax
        mov     [ebx + torrent.ipc_msg.length], 12
        lea     edx, [ebx + torrent.ipc_msg.bytes]
        mov     [edx], ebx
DEBUGF 2,'### [%u] Run process for torrent at %x\n',[ebx + torrent.pid], ebx

;        stdcall torrent._.print_torrent, ebx

  .still:
;DEBUGF 2,'@@:'
;mov eax, [fs:0]
;DEBUGF 2,' %x',eax
;mov eax, [fs:4]
;DEBUGF 2,' %x',eax
;mov eax, [fs:8]
;DEBUGF 2,' %x',eax
;mov eax, [fs:12]
;DEBUGF 2,' %x',eax
;mov eax, [fs:16]
;DEBUGF 2,' %x',eax
;mov eax, [fs:20]
;DEBUGF 2,' %x',eax
;mov eax, [fs:24]
;DEBUGF 2,' %x',eax
;mov eax, [fs:28]
;DEBUGF 2,' %x',eax
;mov eax, [fs:32]
;DEBUGF 2,' %x',eax
;mov eax, [fs:36]
;DEBUGF 2,' %x',eax
;mov eax, [fs:0x100]
;DEBUGF 2,' %x',eax
;DEBUGF 2,'\n'
        inc     [ebx + torrent.stub]
DEBUGF 2,'### [%u] Incremented stub is: %d\n',[ebx + torrent.pid], [ebx + torrent.stub]
        mov     ecx, [ebx + torrent.parent_pid]
        lea     edx, [ebx + torrent.ipc_msg]
        push    ebx
        mcall   60, 2, , , 12
        pop     ebx
DEBUGF 2,'### [%u] Sent IPC to PID %u, status: %d\n',[ebx + torrent.pid], [ebx + torrent.parent_pid], eax
        push    ebx
        mcall   5, 1000
        pop     ebx

        jmp     .still


proc torrent.new _bt_new_type, _src
        push    ebx esi edi

        DEBUGF 2, "PROC : Torrent.New\n"
        invoke  mem.alloc, sizeof.torrent
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: not enough memory for new torrent\n'
        jmp     .error
    @@:
        mov     ebx, eax

        invoke  mem.alloc, sizeof.ipc_buffer
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: not enough memory for ipc_buf\n'
        jmp     .error
    @@:
        DEBUGF 2, "PROGRESS : Memory for Torrent and IPC Buffer allocated\n"
        mov     [ebx + torrent.ipc_buf], eax
        mov     [ebx + torrent.uploaded], 0
        mov     [ebx + torrent.downloaded], 0
        mov     [ebx + torrent.left], 0
        mov     [ebx + torrent.pid], 0

        cmp     [ebx + torrent.trackers], 0
        jnz     .trackers_allocated
        invoke  mem.alloc, 0x2000
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: torrent.new announe alloc\n'
        jmp     .error
    @@:
        mov     [ebx + torrent.trackers], eax
  .trackers_allocated:
        DEBUGF 2, "PROGRESS : Trackers allocated\n"
        cmp     [ebx + torrent.peers], 0
        jnz     .peers_allocated
        invoke  mem.alloc, (MAX_PEERS_PER_TORRENT * sizeof.peer)
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: torrent.new peers alloc\n'
        jmp     .error
    @@:
        mov     [ebx + torrent.peers], eax
  .peers_allocated:
        DEBUGF 2, "PROGRESS : Trackers allocated\n"
        lea     edi, [ebx + torrent.peer_id]
        mov     esi, def_peer_id
        mov     ecx, 20
        rep movsb
        mov     [ebx + torrent.port], 60001

        cmp     [_bt_new_type], BT_NEW_FILE
        jnz     .magnet
        DEBUGF 2, "PROGRESS : Loading a file\n"
        stdcall torrent._.load_file, ebx, [_src]
        jmp     .quit
  .magnet:
        DEBUGF 4,'NOT IMPLEMENTED: magnet links\n'
        jmp     .quit

  .error:
  .quit:
        DEBUGF 2, "Torrent Address : %d",ebx
        mov     eax, ebx
        pop     edi esi ebx
        ret
endp


proc torrent.delete _torrent


        ret
endp


proc torrent._.load_file _torrent, _file
        locals
                fd       dd ?
                filebuf  dd ?
                filesize dd ?
        endl

        push    ebx esi edi
        DEBUGF 2, "PROGRESS : Getting file size %s\n",[_file]
        int3
        invoke  file.size, [_file]
        DEBUGF 2, "File sie is %d\n", ebx
        cmp     ebx, -1
        jnz     @f
        DEBUGF 3,'ERROR: file.size\n'
        jmp     .error
    @@:
        mov     [filesize], ebx
        DEBUGF 2, "PROGRESS : Allocating memory for file size\n"
        invoke  mem.alloc, [filesize]
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: mem.alloc\n'
        jmp      .error
    @@:
        DEBUGF 2, "PROGRESS : Opening a file\n"
        mov     [filebuf], eax
        mov     ebx, [_torrent]
        invoke  file.open, [_file], O_READ
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: file.open\n'
        jmp      .error
    @@:
        DEBUGF 2, "PROGRESS : Reading a file\n"
        mov     [fd], eax
        mov     eax, [filebuf]
        invoke  file.read, [fd], eax, [filesize]
        cmp     eax, -1
        jnz     @f
        DEBUGF 3,'ERROR: file.read\n'
        jmp      .error
    @@:
        DEBUGF 2, "PROGRESS : Closing a file\n"
        invoke  file.close, [fd]

        mov     esi, [filebuf]
        mov     eax, esi
        inc     esi
        add     eax, [filesize]
        DEBUGF 2, "PROGRESS : Bendecoding a file\n"
        stdcall torrent._.bdecode_dict, [_torrent], eax, known_keys_0
        jmp     .quit
  .error:
        mov     eax, -1
  .quit:
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
;        stdcall torrent._.print_peer, edx
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


proc torrent._.tracker_fill_params _torrent, _tracker
        push    ebx esi edi

        mov     ebx, [_torrent]
        mov     edi, [_tracker]
        add     edi, [edi + tracker.announce_len]
        add     edi, tracker.announce

        mov     eax, '?inf'
        stosd
        mov     eax, 'o_ha'
        stosd
        mov     eax, 'sh= '
        stosd
        dec     edi
        lea     eax, [ebx + torrent.info_hash]
        stdcall percent_encode, eax, 20         ; sha1 length
        mov     eax, '&   '
        stosb
        mov     eax, 'peer'
        stosd
        mov     eax, '_id='
        stosd
        lea     esi, [ebx + torrent.peer_id]
        mov     ecx, 20
        rep movsb
        mov     eax, '&   '
        stosb
        mov     eax, 'port'
        stosd
        mov     eax, '=   '
        stosb
        stdcall torrent._.print_num, [ebx + torrent.port]
        mov     eax, '&   '
        stosb
        mov     eax, 'uplo'
        stosd
        mov     eax, 'aded'
        stosd
        mov     eax, '=   '
        stosb
        stdcall torrent._.print_num, [ebx + torrent.uploaded]
        mov     eax, '&   '
        stosb
        mov     eax, 'down'
        stosd
        mov     eax, 'load'
        stosd
        mov     eax, 'ed= '
        stosd
        dec     edi
        stdcall torrent._.print_num, [ebx + torrent.downloaded]
        mov     eax, '&   '
        stosb
        mov     eax, 'left'
        stosd
        mov     eax, '=   '
        stosb
        stdcall torrent._.print_num, [ebx + torrent.left]
        mov     eax, '&   '
        stosb
        mov     eax, 'comp'
        stosd
        mov     eax, 'act='
        stosd
        mov     eax, '0   '
        stosb

        xor     eax, eax
        stosb

  .error:
  .quit:
        pop     edi esi ebx
        ret
endp


proc torrent._.print_num _num
        push    ebx

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

        pop     ebx
        ret
endp


align 16
@EXPORT:

export                                      \
        lib_init           , 'lib_init'   , \
        torrent.tracker_get, 'tracker_get', \
        torrent.start,       'start'      , \
        torrent.stop,        'stop '      , \
        torrent.new,         'new'

align 16
@IMPORT:

library                            \
        network,   'network.obj' , \
        lib_http,  'http.obj'    , \
        libcrash,  'libcrash.obj', \
        libio,     'libio.obj'


import network,                       \
        getaddrinfo,  'getaddrinfo' , \
        freeaddrinfo, 'freeaddrinfo', \
        inet_ntoa,    'inet_ntoa'

import lib_http                , \
        http.get,     'get'    , \
        http.free,    'free'   , \
        http.receive, 'receive'

import libcrash			        , \
	libcrash.init  , 'lib_init'	, \
	crash.hash     , 'crash_hash'	, \
	crash.bin2hex  , 'crash_bin2hex'

import libio                    , \
        libio.init, 'lib_init'  , \
        file.size , 'file_size' , \
        file.open , 'file_open' , \
        file.read , 'file_read' , \
        file.close, 'file_close',\
        file.seek, 'file_seek'

include_debug_strings

section '.data' data readable writable align 16

mem.alloc       dd ?
mem.free        dd ?
mem.realloc     dd ?
dll.load        dd ?

;---------------------------------------------------------------------
fileinfo        dd 2, 0, 0
final_size      dd 0
final_buffer    dd 0
                db 0
                dd fname_buf
fname_buf       db '/hd0/1/get.out',0
;---------------------------------------------------------------------

def_peer_id db '-KS0001-123456654321'     ; KS for KolibriOS

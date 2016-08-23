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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;Header Area;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

format binary as ""

use32
        org     0x0
        db      'MENUET01'      ; signature
        dd      0x01            ; header version
        dd      START           ; entry point
        dd      I_END           ; initialized size
        dd      E_END           ; required memory
        dd      E_END           ; stack pointer
        dd      0               ; parameters
        dd      0               ; path

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;Include Area;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

include 'includes/struct.inc'
include 'includes/proc32.inc'
include 'includes/macros.inc'
include 'includes/config.inc'
include 'includes/network.inc'
include 'includes/debug-fdo.inc'
include 'includes/dll.inc'
include 'includes/libio.inc'
include 'torrent.inc'
include 'torrent_actions.inc'
include 'torrent_errors.inc'
include 'bittorrent_backend_actions.asm'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;Code Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;entry point of main thread

START:
            ;init heap
            mcall   68, 11
            test    eax, eax
            jnz     @f
            DEBUGF 3, "ERROR : Problem allocating heap space.\n"
            jz      .error

            ;load libraries
    @@:     stdcall dll.Load, @IMPORT
            test    eax, eax
            jz      @f
            DEBUGF 3, "ERROR : Problem loading libraries.\n"
            jmp     .error

            ;allocating memory for torrent_info
    @@:     stdcall  mem.Alloc, (MAX_TORRENTS*sizeof.torrent_info)
            test     eax, eax
            jnz      @f
            DEBUGF 3, "INFO : Not enough memory for torrent_info\n"
            jmp      .error

            ;setting torrent_arr
    @@:     mov      [torrent_arr], eax
            mov      [num_torrents], 0

            ;current thread will handle the connection from front-end
            ;new thread will handle torrent downloading

    @@:     mcall    51, 1, THREAD2_START, [thread_stack]
            cmp      eax, -1
            jne      @f
            DEBUGF 3, "ERROR : Not able to create thread\n"
            jmp      .error

            ;Start listening on port 50000 for incoming requests from front-end
    @@:     mcall   40, EVM_STACK

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

    .loop:
            mcall   recv, [socketnum2], recv_buffer, recv_buffer.length, 0
            cmp     eax, -1
            je      .loop
        
            mov     byte[recv_buffer+eax], 0            ;eax contains number of bytes copied

            ;protocol : <msg-length><msg-type><msg-payload>
            mov     esi, recv_buffer
            lodsd
            mov     [length_of_msg], eax
            lodsb
            mov     [type_of_msg], al

            cmp     al, TORRENT_ACTION_ADD
            je      .torrent_add

            cmp     al, TORRENT_ACTION_SHOW
            je      .torrent_show

            cmp     al, TORRENT_ACTION_SHOW_ALL
            je      .torrent_show_all

            cmp     al, TORRENT_ACTION_START
            je      .torrent_start

            cmp     al, TORRENT_ACTION_PAUSE
            je      .torrent_pause

            cmp     al, TORRENT_ACTION_REMOVE
            je      .torrent_remove
                        
            cmp     al, TORRENT_ACTION_QUIT
            je      .torrent_quit

            mcall   send, [socketnum2], Invalid_Cmd_Str
            mcall   close, [socketnum2]
            jmp     .accept_connection

    .torrent_add:
            stdcall backend_actions_add, esi, send_buffer
            mcall   send, [socketnum2], send_buffer, eax
            mcall   close, [socketnum2]
            jmp     .accept_connection

    .torrent_show:
            stdcall backend_actions_show, esi, send_buffer
            mcall   send, [socketnum2], send_buffer, eax
            mcall   close, [socketnum2]
            jmp     .accept_connection

    .torrent_show_all: 
            stdcall backend_actions_show_all , send_buffer
            mcall   send, [socketnum2], send_buffer, eax       
            mcall   close, [socketnum2]
            jmp     .accept_connection

    .torrent_start:
            mcall   close, [socketnum2]
            jmp     .accept_connection

    .torrent_pause:
            mcall   close, [socketnum2]
            jmp     .accept_connection

    .torrent_remove:
            mcall   close, [socketnum2]
            jmp     .accept_connection

    .torrent_quit:
            mcall   close, [socketnum2]
            jmp     .accept_connection

    .sock_err:
            DEBUGF 3, "ERROR : Could not open socket.\n"
            jmp     .error

    .bind_err:
            DEBUGF 3, "ERROR : Bind error.\n"
            jmp     .error

    .listen_err:
            DEBUGF 3, "ERROR : Listen error.\n"
            jmp     .error

    .accept_err:
            DEBUGF 3, "ERROR : Accept error.\n"
            jmp     .error  

    .error: DEBUGF 3, "ERROR : Program ended with error.\n"
            mcall   -1

    .exit:  DEBUGF 2, "INFO : Program exited successfully.\n"    
            mcall   -1

THREAD2_START:
            DEBUGF 2, "INFO : I am at thread 2\n"
            mcall    -1    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Import Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 16
@IMPORT:

library \
        libio,   'libio.obj',\
        torrent, 'torrent.obj'

import  libio,\
        libio.init, 'lib_init'  ,   \
        file.open , 'file_open' ,   \
        file.read , 'file_read' ,   \
        file.write , 'file_write' , \
        file.seek, 'file_seek',     \
        file.close, 'file_close',   \
        file.size,  'file_size'

import torrent,\
       lib_init,     'lib_init',    \
       torrent.new,  'new',         \
       torrent.start,'start',       \
       torrent.resume,'resume'   

include_debug_strings

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Data Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Data for all torrents
torrent_arr          dd ?
num_torrents         dd 0
torrent_filename1    db '/usbhd0/1/test.torrent',0
download_location1   db '/tmp0/1',0
torrent1             dd ?
torrent_add_fail     db 'Torrent added with failure', 0
.length              =  $ - torrent_add_fail
torrent_add_suc      db 'Torrent added successfully', 0
.length              =  $ - torrent_add_suc


;Data for connection
socketnum            dd ?
socketnum2           dd ?
recv_buffer          rb BUFFERSIZE
.length               = BUFFERSIZE
send_buffer          rb BUFFERSIZE
.length               = BUFFERSIZE
length_of_msg        dd ?
type_of_msg          db ?

sockaddr:
                     dw AF_INET4
        .port        dw 23 shl 8             ; port 50000 = 0xC350 -in network byte order
        .ip          dd 0
                     rb 10
        .length      = $ - sockaddr



;Data for thread
thread_stack    dd 0x1000
thread_id       dd ?


I_END:
    rb 0x1000                   ; stack
E_END:
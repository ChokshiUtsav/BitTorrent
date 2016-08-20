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
        dd      E_END           ; required memory
        dd      E_END           ; stack pointer
        dd      0               ; parameters
        dd      0               ; path

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1
BUFFERSIZE      = 1500


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
            ;create  thread to handle torrent downloading

            mcall    51, 1, THREAD2_START, [thread_stack]
            cmp      eax, -1
            jne      @f
            DEBUGF 3, "ERROR : Not able to create thread\n"
            jmp      .error

            ;Start listening on port 50000 for incoming requests from frontend
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

            DEBUGF 2, "INFO : Connection accepted\n"

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

            cmp     al, TORRENT_ACTION_ADD
            je      .torrent_add

            cmp     al, TORRENT_ACTION_START
            je      .torrent_start

            cmp     al, TORRENT_ACTION_PAUSE
            je      .torrent_pause

            cmp     al, TORRENT_ACTION_REMOVE
            je      .torrent_remove
            
            cmp     al, TORRENT_ACTION_SHOW
            je      .torrent_show

            cmp     al, TORRENT_ACTION_SHOW_ALL
            je      .torrent_show
            
            cmp     al, TORRENT_ACTION_QUIT
            je      .torrent_quit

    .torrent_add:

            ;copy torrent file location
            mov     edi, torrent_filename
    .loop1: cmp     byte[esi], '#'
            je      @f
            movsb
            jmp     .loop1

            ;copy download location
    @@:     mov     byte[edi], 0x00
            inc     esi
            mov     edi, download_location
    .loop2: cmp     byte[esi], '#'
            je      @f
            movsb
            jmp     .loop2

    @@:     mov     byte[edi], 0x00

            stdcall backend_actions.torrent_add, torrent_filename, download_location
            cmp     eax, -1
            je      @f
            mcall   send, [socketnum2], torrent_add_suc, torrent_add_suc.length
            mcall   close, [socketnum2]
            jmp     .accept_connection

    @@:     mcall   send, [socketnum2], torrent_add_fail, torrent_add_fail.length
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

    .torrent_show:
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
            mcall    -1

    .exit:  DEBUGF 2, "INFO : Program exited successfully.\n"    
            mcall    -1

THREAD2_START:
            DEBUGF 2, "INFO : I am at thread 2\n"
            mcall    -1    
            
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Import Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 16
@IMPORT:

library \
        torrent, 'torrent.obj'

import torrent,\
       lib_init,     'lib_init',    \
       torrent.new,  'new',         \
       torrent.start,'start'    

include_debug_strings

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Data Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

sockaddr:
                dw AF_INET4
        .port   dw 23 shl 8             ; port 50000 = 0xC350 -in network byte order
        .ip     dd 0
                rb 10
        .length = $ - sockaddr

handshake_msg   db 'Kolibrios_Bittorrent_Client',0
.length         =  $ - handshake_msg

torrent_add_suc db 'Torrent added successfully', 0
.length         =  $ - torrent_add_suc

torrent_add_fail db 'Torrent added with failure', 0
.length          =  $ - torrent_add_fail


length_of_msg   dd  ?
type_of_msg     db  0
torrent_id      dd  0

torrent_arr     dd ?
num_torrents    dd 0
thread_stack    dd 0x1000
thread_id       dd ?

I_END:

socketnum            dd 0
socketnum2           dd 0
recv_buffer          rb BUFFERSIZE
.length               = BUFFERSIZE
send_buffer          rb BUFFERSIZE
.length               = BUFFERSIZE

torrent_filename     rb 1024
download_location    rb 1024

align 4
rb 0x1000       ; stack

E_END:
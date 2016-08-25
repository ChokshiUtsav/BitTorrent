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

;standard header
use32
        org     0x0
        db      'MENUET01'      ; signature
        dd      0x01            ; header version
        dd      START           ; entry point
        dd      I_END           ; initialized size
        dd      E_END+0x1000    ; required memory
        dd      E_END+0x1000    ; stack pointer
        dd      params          ; parameters
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
include 'torrent_actions.inc'

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

            ;initialize console
    @@:     invoke  con_start, 1
            invoke  con_init, 80, 25, 80, 25, title
            invoke  con_write_asciiz, welcome_str
            invoke  con_write_asciiz, avl_cmd_str
            invoke  con_write_asciiz, download_cmd_str
            invoke  con_write_asciiz, show_cmd_str
            invoke  con_write_asciiz, show_all_cmd_str
            invoke  con_write_asciiz, show_menu_str

    .input_loop:        
            ;user input
            invoke  con_write_asciiz, prompt_str
            invoke  con_gets, params, 1024

            stdcall compare_strs, params, download_cmd_str
            cmp     eax, -1
            je      @f
            stdcall torrent_add
            jmp     .input_loop
            
        @@: stdcall compare_strs, params, show_cmd_str
            cmp     eax, -1
            je      @f

        @@: stdcall compare_strs, params, show_all_cmd_str
            cmp     eax, -1
            je      @f
            stdcall torrent_show_all
            jmp     .input_loop

        @@: stdcall compare_strs, params, show_menu_str
            cmp     eax, -1
            je      @f
            stdcall show_menu
            jmp     .input_loop

        @@: invoke  con_write_asciiz, Invalid_Cmd_Str
            jmp     .input_loop     

            ;close  console
            invoke  con_get_flags
            test    eax, 0x200                      ; con window closed?
            je      .exit

    .error: DEBUGF 3, "ERROR : Program ended with error.\n"
            mcall    -1

    .exit:  DEBUGF 2, "INFO : Program exited successfully.\n"    
            mcall    -1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Compares two null terminated strings
;Input   : source string pointer, destination string pointer
;Outcome : if success => eax = 0 (matches)
;          if error => eax = -1 (does not match)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc compare_strs _src, _dest
            
            push esi edi

            mov  esi, [_src]
            mov  edi, [_dest]

    .loop:  mov  al, byte[edi]
            cmp  byte[esi], al
            jne  .error
            cmp  byte[esi], 0x00
            je   .quit
            inc  esi
            inc  edi
            jmp  .loop

    .error: mov  eax, -1        
            pop  edi esi
            ret

    .quit:  mov  eax, 0
            pop  edi esi
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Copies a null terminated string
;Input   : source string pointer, destination string pointer
;Outcome : eax = number of bytes copied
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc  copy_strs _src, _dest
            
            push ecx esi edi

            mov  esi, [_src]
            mov  edi, [_dest]
            mov  ecx, 0

    .loop:  cmp  byte[esi], 0x00
            je   .quit
            movsb
            inc  ecx
            jmp  .loop

    .quit:  mov  eax, ecx
            pop  edi esi ecx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc     : Connects with backend, takes request from send_buffer and stores response at recv_buffer
;Outcome  : if success -> eax = 0   (connected to server)
;           if error   -> eax = -1  (not able to connect to server)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc  connect_backend

            push  ebx ecx edx esi edi

             mcall   40, EVM_STACK

             mov     eax, [localhost_ip]
             mov     [sockaddr_server.ip],eax

            ;Opening a socket
             mcall   socket, AF_INET4, SOCK_STREAM, 0
             cmp     eax, -1
             jnz     @f
             DEBUGF 3, "ERROR : Open socket : %d\n",ebx
             jmp     .error

             ;Connecting with tcp-server
        @@:  mov     [socketnum], eax
             mcall   connect, [socketnum], sockaddr_server, sockaddr_server.length
             cmp     eax, -1
             jnz     @f
             DEBUGF 3, "ERROR : Connect %d\n",ebx
             jmp     .error

             ;sending message
        @@:  invoke  con_write_asciiz, connected_backend_str
             mcall   send, [socketnum], send_buffer, send_msg_len
             cmp     eax, -1
             jnz     @f
             DEBUGF 3, "ERROR: send %d\n",ebx
             jmp     .error

             ;receving message
        @@:  mcall   recv, [socketnum], recv_buffer, 1500, 0
             cmp     eax, -1
             jne     .quit
             DEBUGF 3, "ERROR : recv %d\n",ebx
             jmp     .error  

    .error: mcall   close, [socketnum]
            mov  eax, -1        
            pop  edi esi edx ecx ebx
            ret

    .quit:  mcall   close, [socketnum]
            mov  eax, 0
            pop  edi esi edx ecx ebx
            ret         
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Handles torrent download command
;Outcome : It prints on the console whether torrent is added or not.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent_add

            push    ebx ecx edx esi edi

            ;prepares message
            mov     ecx, 0
            mov     edi, send_buffer
            add     edi, 4
            mov     eax, TORRENT_ACTION_ADD
            stosb

            ;asks user for torrent file location
            invoke  con_write_asciiz, torrent_file_str
            invoke  con_gets, params, 1024
            stdcall copy_strs, params, edi
            add     ecx, eax
            add     edi, eax
            mov     byte[edi], '#'
            inc     ecx
            inc     edi

            ;asks user for torrent download location
            invoke  con_write_asciiz, download_loc_str
            invoke  con_gets, params, 1024
            stdcall copy_strs, params, edi
            add     ecx, eax
            add     edi, eax
            mov     byte[edi], '#'
            inc     ecx
            inc     edi

            ;loads message length
            mov     edi, send_buffer
            mov     eax, ecx
            stosd

            ;connecting to backend
            invoke  con_write_asciiz, connect_backend_str
            add     ecx, 5
            mov     [send_msg_len], ecx
            stdcall connect_backend
            cmp     eax, -1
            jne     @f
            invoke  con_write_asciiz, problem_backend_str
            jmp     .quit

    @@:     invoke  con_write_asciiz, recv_buffer   

    .quit:  pop  edi esi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Handles torrent show all command
;Outcome : It prints on the console all added torrents
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent_show_all

            push    ebx ecx edx esi edi

            ;prepares message
            mov     eax, 0
            mov     ecx, 0
            mov     edi, send_buffer
            stosd
            mov     eax, TORRENT_ACTION_SHOW_ALL
            stosb

            ;connecting to backend
            invoke  con_write_asciiz, connect_backend_str
            add     ecx, 5
            mov     [send_msg_len], ecx
            stdcall connect_backend
            cmp     eax, -1
            jne     @f
            invoke  con_write_asciiz, problem_backend_str
            jmp     .quit

    @@:     DEBUGF 2, "INFO : %s\n", recv_buffer
            invoke  con_write_asciiz, recv_buffer   

    .quit:  pop     edi esi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Prints list of available commands
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc  show_menu
            invoke  con_write_asciiz, avl_cmd_str
            invoke  con_write_asciiz, download_cmd_str
            invoke  con_write_asciiz, show_cmd_str
            invoke  con_write_asciiz, show_all_cmd_str
            invoke  con_write_asciiz, show_menu_str 
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Import Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 16
@IMPORT:

library console, 'console.obj'

import  console,        \
        con_start,      'START',        \
        con_init,       'con_init',     \
        con_write_asciiz,       'con_write_asciiz',     \
        con_exit,       'con_exit',     \
        con_gets,       'con_gets',\
        con_cls,        'con_cls',\
        con_printf,     'con_printf',\
        con_getch2,     'con_getch2',\
        con_set_cursor_pos, 'con_set_cursor_pos',\
        con_get_flags,  'con_get_flags'

include_debug_strings

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Data Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;console strings
title               db      'Bittorrent Client v1.0',0
welcome_str         db      'Welcome to Bittorrent Client v1.0 ... ',10,0
avl_cmd_str         db      'Following commands are available :',10,0
download_cmd_str    db      'download_torrent',10,0
show_cmd_str        db      'show_torrent',10,0
show_all_cmd_str    db      'show_all_torrent',10,0
show_menu_str       db      'show_all_cmd',10,0
torrent_file_str    db      '>>>>Enter torrent file location :', 10,0
download_loc_str    db      '>>>>Enter download location :', 10,0
connect_backend_str db      '>>>>Connecting to backend...',10,0
connected_backend_str db    '>>>>Connected and waiting...',10,0
problem_backend_str db      '>>>>Problem connecting with backend...',10,0
prompt_str          db       10,'>> ',0
Invalid_Cmd_Str     db      'Torrent command not supported', 10, 0

;Data for connecting with backend
sockaddr_server:  
                        dw AF_INET4
    .port               dw 23 shl 8             ; port 50000 = 0xC350 -in network byte order     
    .ip                 dd 0
                        rb 10
    .length             =  $ - sockaddr_server

localhost_ip:
                        db 127
                        db 0
                        db 0
                        db 1

socketnum               dd 0

send_msg_len            dd ?

I_END:

send_buffer         rb      1500
recv_buffer         rb      1500
params              rb      1024

E_END:
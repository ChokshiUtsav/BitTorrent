;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                 ;;
;; Copyright (C) KolibriOS team 2010-2015. All rights reserved.    ;;
;; Distributed under terms of the GNU General Public License       ;;
;;                                                                 ;;
;;  udpserv.asm - UDP demo program for KolibriOS                   ;;
;;                                                                 ;;
;;  Written by hidnplayr@kolibrios.org                             ;;
;;  Modified by Utsav_Chokshi                                      ;;
;;                                                                 ;;
;;          GNU GENERAL PUBLIC LICENSE                             ;;
;;             Version 2, June 1991                                ;;
;;                                                                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

format binary as ""

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1

BUFFERSIZE      = 1500

use32
; standard header
        db      'MENUET01'      ; signature
        dd      1               ; header version
        dd      start           ; entry point
        dd      i_end           ; initialized size
        dd      mem             ; required memory
        dd      mem             ; stack pointer
        dd      0               ; parameters
        dd      0               ; path


include 'macros.inc'
purge mov,add,sub
include 'proc32.inc'
include 'dll.inc'
include 'network.inc'


; entry point
start:
; load libraries
        stdcall dll.Load, @IMPORT
        test    eax, eax
        jnz     exit

; initialize console
        invoke  con_start, 1
        invoke  con_init, 80, 25, 80, 25, title

        mcall   40, EVM_STACK

        invoke  con_write_asciiz, str1

        mcall   socket, AF_INET4, SOCK_DGRAM, 0
        cmp     eax, -1
        je      sock_err
        mov     [socketnum], eax

; This socket option is not implemented in kernel yet.
;        mcall   setsockopt, [socketnum], SOL_SOCKET, SO_REUSEADDR, &yes,
;        cmp     eax, -1
;        je      opt_err

        mcall   bind, [socketnum], sockaddr1, sockaddr1.length
        cmp     eax, -1
        je      bind_err


        ;mcall   listen, [socketnum], 10 ; Backlog = 10
        ;cmp     eax, -1
        ;je      listen_err

        ;invoke  con_write_asciiz, str2

        ;mcall   accept, [socketnum], sockaddr1, sockaddr1.length
        ;cmp     eax, -1
        ;je      acpt_err
        ;mov     [socketnum2], eax

        ;mcall   send, [socketnum2], hello, hello.length

  .loop: mcall   recv, [socketnum], buffer, buffer.length, 0
         cmp     eax, -1
         je      .loop

        mov     byte[buffer+eax], 0
        invoke  con_write_asciiz, buffer

        mcall   send, [socketnum], hello, hello.length
        cmp     eax, -1
        je      send_err
        jmp     .loop

acpt_err:
        invoke  con_write_asciiz, str8
        jmp     done

send_err:
        invoke  con_write_asciiz, str7
        jmp     done        

listen_err:
        invoke  con_write_asciiz, str3
        jmp     done

bind_err:
        invoke  con_write_asciiz, str4
        jmp     done

sock_err:
        invoke  con_write_asciiz, str6
        jmp     done

done:
        invoke  con_getch2      ; Wait for user input
        invoke  con_exit, 1
exit:
        cmp     [socketnum], 0
        je      @f
        mcall   close, [socketnum]
  @@:
        cmp     [socketnum2], 0
        je      @f
        mcall   close, [socketnum2]
  @@:
        mcall   -1



; data
title   db      'UDP stream server demo',0
str1    db      'Opening socket',10, 0
str2    db      'Listening for incoming connections...',10,0
str3    db      'Listen error',10,10,0
str4    db      'Bind error',10,10,0
str5    db      'Setsockopt error',10,10,0
str6    db      'Could not open socket',10,10,0
str7    db      'Send error',10,10,0
str8    db      'Error accepting connection',10,10,0

hello   db      'Hello client!',0
.length = $ - hello

sockaddr1:
        dw AF_INET4
.port   dw 90 shl 8             ; port 69 - network byte order
.ip     dd 0
        rb 10
.length = $ - sockaddr1

; import
align 4
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
        con_set_cursor_pos, 'con_set_cursor_pos'


i_end:

socketnum       dd 0
socketnum2      dd 0
buffer          rb BUFFERSIZE
.length = BUFFERSIZE

align   4
rb      4096    ; stack
mem:

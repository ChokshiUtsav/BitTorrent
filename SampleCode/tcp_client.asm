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
        dd      0			    ; path

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;Include Area;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

include 'struct.inc'
include 'proc32.inc'
include 'macros.inc'
include 'config.inc'
include 'network.inc'
include 'debug-fdo.inc'
include 'dll.inc'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;Code Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

START:
      ;init heap
      mcall   68, 11
      test    eax, eax
      jnz   @f
      DEBUGF 3, "ERROR : Problem allocating heap space.\n"
      jz      .error

      ;load libraries
  @@: stdcall dll.Load, @IMPORT
      test    eax, eax
      jz    @f
      DEBUGF 3, "ERROR : Problem loading libraries.\n"
      jmp     .error

  @@: mcall	  40, EVM_STACK

      mov     eax, [localhost_ip]
      mov     [sockaddr_server.ip],eax

      ;Opening a socket
      mcall   socket, AF_INET4, SOCK_STREAM, 0
      cmp     eax, -1
      jnz     @f
      DEBUGF 3, "ERROR : Open socket : %d\n",ebx
      jmp     .error

     ;Connecting with tcp-server
  @@: mov     [socketnum], eax
      mcall   connect, [socketnum], sockaddr_server, sockaddr_server.length
      cmp     eax, -1
      jnz     @f
      DEBUGF 3, "ERROR : Connect %d\n",ebx
      jmp     .error

  @@: jmp     .exit
      mcall   recv, [socketnum], buffer, buffer.length, 0
      cmp     eax, -1
      jnz      @f
      DEBUGF 3, "ERROR : recv %d.\n",ebx
      jmp     .error

  @@: mov     byte[buffer+eax], 0 
      lea     edi, [buffer]
      DEBUGF 2, "INFO : Message : %s\n", edi
      jmp     .exit


.error: 
	  DEBUGF 3, "ERROR : Procedure ended with an error.\n"
      mcall   close, [socketnum]
      mcall   -1

.exit:  
	  DEBUGF 2, "INFO : Procedure ended successfully.\n"
      mcall   close, [socketnum]
      mcall   -1
      

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Import Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 4
@IMPORT:

library       \
        libini,  'libini.obj' , \
        libio,   'libio.obj'

import libini                               , \
        ini.get_shortcut, 'ini_get_shortcut'

import libio                    , \
        libio.init, 'lib_init'  , \
        file.size , 'file_size' , \
        file.open , 'file_open' , \
        file.read , 'file_read' , \
        file.close, 'file_close'

include_debug_strings

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Data Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Data for connecting with backend
sockaddr_server:  
                        dw AF_INET4
    .port               dw 23 shl 8     
    .ip                 dd 0
                        rb 10
    .length             =  $ - sockaddr_server

localhost_ip:
                        db 127
                        db 0
                        db 0
                        db 1

socketnum               dd 0

buffer                  rb 512
.length                 =  512


I_END:
rb 0x1000             ; stack
E_END:
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

include 'struct.inc'
include 'proc32.inc'
include 'macros.inc'
include 'config.inc'
include 'network.inc'
include 'debug-fdo.inc'
include 'dll.inc'
include 'libio.inc'
include 'torrent.inc'
;include 'libcrash.inc'


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

            ;Add new torrent
    @@:     DEBUGF 2, "INFO : Calling torrent.new\n"
            invoke  torrent.new, BT_NEW_FILE, torrent_filename1, download_location
            cmp     eax, -1
            jne     @f
            DEBUGF 3, "ERROR : Problem with torrent.new\n"
            jmp     .error 

    @@:     DEBUGF 2, "INFO : Successfully returned from torrent.new\n"
            DEBUGF 2, "INFO : Calling torrent.start\n"
            invoke  torrent.start, eax
            cmp     eax, -1
            jnz     @f
            DEBUGF 3, "ERROR : Problem with torrent.start\n"
            jmp     .error            

    @@:     DEBUGF 2, "INFO : Successfully returned from torrent.start\n"
            jmp .exit

    .error: DEBUGF 3, "ERROR : Program ended with error.\n"
            mcall   -1

    .exit:  DEBUGF 2, "INFO : Program exited successfully.\n"    
            mcall   -1

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
       torrent.start,'start'    

include_debug_strings

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Data Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

torrent_filename1 db '/usbhd0/1/test.torrent',0
download_location db '/tmp0/1',0

I_END:
    rb 0x1000                   ; stack
E_END:
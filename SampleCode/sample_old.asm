format binary as ""

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

include 'struct.inc'
include 'proc32.inc'
include 'macros.inc'
include 'config.inc'
include 'network.inc'
include 'debug-fdo.inc'
include 'dll.inc'
include 'libio.inc'
include 'torrent.inc'


START:
	;init heap
    mcall   68, 11
    test    eax, eax
    jz      .exit

	;load libraries
    stdcall dll.Load, @IMPORT
    test    eax, eax
    jnz     .exit

    ;Creating a new torrent
.bp1:
    DEBUGF 2, "Calling file size"
    invoke  file.size, torrent_filename1
    DEBUGF 2, "file size %d\n", ebx
    DEBUGF 2, "Adding a new torrent\n"
    invoke torrent.test, torrent_filename1
    DEBUGF 2, "Torrent Address #1: %d",eax
    test eax,eax
    jnz .exit
    DEBUGF 3, 'ERROR: Failed to add new torrent\n'

.exit:
    DEBUGF 2, "Torrent Address #2: %d",eax
	DEBUGF 2, "SUCCESS : Exiting a program."


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;IMPORT AREA;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
	   lib_init, 'lib_init',       \
	   torrent.test, 'test'

include_debug_strings

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;DATA AREA;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
torrent_filename1 db '/usbhd0/1/test.torrent',0


I_END:
	rb 0x1000      				; stack
E_END:
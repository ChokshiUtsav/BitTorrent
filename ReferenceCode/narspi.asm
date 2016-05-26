use32
    org 0x0
    db  'MENUET01'
    dd  0x01,start,i_end,e_end,e_end,0,0

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1


include '../../../struct.inc'
include '../../../proc32.inc'
include '../../../macros.inc'
include '../../../config.inc'
include '../../../network.inc'
include '../../../debug-fdo.inc'
include '../../../dll.inc'


start:
	mcall	68, 11          ; heap

	stdcall dll.Load, @IMPORT
	or	eax, eax
        jz      .libs_ok
        DEBUGF 3,'ERROR: load libraries\n'
	jmp	.error
  .libs_ok:


        mcall   70, fileinfo


  .still:
	mcall	10
	dec	eax
	jz	.redraw
	dec	eax
	jz	.key

  .button:
	mcall	17
	shr	eax, 8

	cmp	eax, 1
	jz	.quit
	jmp	.still

  .redraw:
	mcall	12, 1
	mcall	0, <300,315>, <300,200>, 0x34000000, 0x80000000, window_title

        mcall   8, <10,70>, <10,20>, 0x00addadd, 0x00dddddd

	mcall	12, 2
	jmp	.still

  .key:
	mcall	2

;        cmp	ah, 0xB3			; right
	jmp	.still





  .error:
  .quit:
        mcall   -1




window_title    db 'Narspi',0


fileinfo:
                dd 7, 0, 0, 0, 0
                db '/hd0/1/sabaxar',0

align 4
@IMPORT:

library				\
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


i_end:

        rb 0x1000       ; stack
e_end:

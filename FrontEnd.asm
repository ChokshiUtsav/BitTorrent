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
        dd      E_END   		    ; required memory
        dd      E_END		        ; stack pointer
        dd      0		            ; parameters
        dd      cur_dir_path    ; path

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
include 'box_lib.mac'
include 'load_lib.mac'
@use_library              ;use load lib macros

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;Code Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

START:
        ;init heap
        mcall   68, 11
        test    eax, eax
        jnz   @f
        DEBUGF 3, "ERROR : Problem allocating heap space.\n"
        jz      error

        ;load libraries
  @@:   stdcall dll.Load, @IMPORT
        test    eax, eax
        jz    @f
        DEBUGF 3, "ERROR : Problem loading libraries.\n"
        jmp     error

        ;load boxlib  
  @@:   sys_load_library  library_name, cur_dir_path, library_path, system_path, \
        err_message_found_lib, head_f_l, myimport, err_message_import, head_f_i
        cmp     ax, -1
        jnz     @f
        DEBUGF  3, "ERROR: Problem loading boxlib.\n"
        jmp     error

        ;drawing window and main event loop
  @@:   call    draw_window      

  event_wait:
        mcall   10

        cmp     eax, 1
        jz      .redraw

        cmp     eax, 2
        jz      .key

        cmp     eax, 3
        jz      .button

        push    dword edit_torrent_path
        call    [edit_box_mouse]

        jmp     event_wait

  .redraw:
        call    draw_window
        jmp     event_wait

  .key: mcall   2
         push    dword edit_torrent_path
         call    [edit_box_key]
        jmp     event_wait

  .button:      
        mcall   17
        cmp     ah, 1
        jne     event_wait
        jmp     exit
       
  error:
        DEBUGF 3, "ERROR : Program ended with error.\n"
        mcall   -1 
    
  exit:
        DEBUGF 2, "INFO : Program exited successfully.\n"  
        mcall   -1 
         

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Static Window Definition & Draw ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

draw_window:
      mcall     12, 1       ;Start of windowdraw

      ;Drawing the window : xstart, xsize, ystart, ysize, work-area color, grab-area color, title

      mcall     0, <300,350>, <300,300>, 0x34000000, 0x80000000, window_title 

      push      dword edit_torrent_path
      call      [edit_box_draw]

      mcall     8, <10,70>, <40,20>, 0x00addadd, 0x00dddddd

      mcall     8, <90,70>, <40,20>, 0x00addadd, 0x00dddddd

      mcall     12, 2       ;End of windowdraw

      ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Import Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Data Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

window_title             db 'BitTorrent Clinet v1.0',0

;Data for buttons

button_path_identifier   dd 0x00000005
button_add_identifier    dd 0x00000006

;Data for loading BoxLib
system_path              db '/sys/lib/'
library_name             db 'box_lib.obj',0
err_message_found_lib    db 'Sorry I cannot load library box_lib.obj',0
head_f_i:
head_f_l                 db 'System error',0
err_message_import       db 'Error on load import library box_lib.obj',0

myimport:

edit_box_draw           dd aEdit_box_draw
edit_box_key            dd aEdit_box_key
edit_box_mouse          dd aEdit_box_mouse
version_ed              dd aVersion_ed
                        dd 0
                        dd 0
aEdit_box_draw          db 'edit_box',0
aEdit_box_key           db 'edit_box_key',0
aEdit_box_mouse         db 'edit_box_mouse',0
aVersion_ed             db 'version_ed',0


;Data for edit box
edit_torrent_path edit_box 200,10,10,0xffffff,0x6f9480,0,0xAABBCC,0,308,hed,mouse_dd,ed_focus,hed_end-hed-1,hed_end-hed-1

hed                     db 'Insert new torrent path here',0
hed_end:

mouse_dd                rd 1
p_info                  process_information

cur_dir_path            rb 4096
library_path            rb 4096

I_END:
	rb 0x1000      				; stack
E_END:
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
  @@: stdcall dll.Load, @IMPORT
      test    eax, eax
      jz    @f
      DEBUGF 3, "ERROR : Problem loading libraries.\n"
      jmp     error

      ;load boxlib  
  @@: sys_load_library  boxlib_library_name, cur_dir_path, library_path, system_path_boxlib, \
      err_message_found_boxlib, head_f_l_boxlib, boxlib_import, err_message_import_boxlib, head_f_i_boxlib
      cmp     ax, -1
      jnz     @f
      DEBUGF  3, "ERROR: Problem loading boxlib.\n"
      jmp     error

      ;load proclib
  @@: sys_load_library   proclib_library_name, cur_dir_path, library_path, system_path_proclib, \
      err_message_found_proclib, head_f_l_proclib, proclib_import, err_message_import_proclib, head_f_i_proclib
      cmp     ax, -1
      jnz     @f
      DEBUGF  3, "ERROR: Problem loading proclib.\n"
      jmp     error

     ;OpenDialog initialisation
  @@: push    dword OpenDialog_data
      call    [OpenDialog_Init]

      ;drawing window and main event loop
  @@: call    draw_window      

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
        je      exit
        cmp     ah, 5
        je      .open_button
        cmp     ah, 6
        je      .add_button
        jmp     event_wait  
  
  .open_button:
        call    open_dlg
        jmp     event_wait

  .add_button:
        jmp     event_wait  

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

      mcall     0, <300,350>, <300,300>, 0x34eeeeee, 0x80000000, window_title 

      push      dword edit_torrent_path
      call      [edit_box_draw]

      mcall     8, <10,70>, <40,20>,[button_open_identifier], 0x00dddddd
      mov       ebx, 15 shl 16
      mov       bx,  44
      mcall     4,,0,button_open_string,button_open_string.length 

      mcall     8, <90,70>, <40,20>,[button_add_identifier], 0x00dddddd
      mov       ebx, 95 shl 16
      mov       bx,  44
      mcall     4,,0,button_add_string,button_add_string.length       

      mcall     12, 2       ;End of windowdraw

      ret


open_dlg:
      pushad
      copy_path open_dialog_name,communication_area_default_pach,library_path,0
      mov       [OpenDialog_data.type],0
      
      push      dword OpenDialog_data
      call      [OpenDialog_Start]
      
      cmp       [OpenDialog_data.status],2    ; OpenDialog does not start
      je        @f
      cmp       [OpenDialog_data.status],1
      jne       @f                            ; User asked to cancel

      mov       esi,[OpenDialog_data.openfile_pach]
      mov       edi,dword [edit_torrent_path.text]
      mov       ebx, edi
      call      copy_str
      sub       edi, ebx
      dec       edi
      mov       [edit_torrent_path.size],edi        ;edi = strlen(edit_torrent_path.text)
      mov       [edit_torrent_path.pos],edi

      push      dword edit_torrent_path
      call      dword [edit_box_draw]

  @@: popad
      ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;Procedure Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

copy_str:
      xor       eax,eax
      cld
  @@: lodsb
      stosb
      test      eax,eax
      jnz @b
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

;Data for window
window_title             db 'BitTorrent Clinet v1.0',0

;Data for buttons

button_open_identifier   dd 5
button_add_identifier    dd 6
button_open_string       db 'Open File',0
.length                  =  $ - button_open_string
button_add_string        db 'Add Torrent',0
.length                  =  $ - button_add_string

;Data for loading BoxLib and ProcLib
system_path_boxlib          db '/sys/lib/'
boxlib_library_name         db 'box_lib.obj',0
err_message_found_boxlib    db 'Sorry I cannot load library box_lib.obj',0
head_f_i_boxlib:
head_f_l_boxlib             db 'System error',0
err_message_import_boxlib   db 'Error on load import library box_lib.obj',0

system_path_proclib         db '/sys/lib/'
proclib_library_name        db 'proc_lib.obj',0
err_message_found_proclib   db 'Sorry I cannot load library proc_lib.obj',0
head_f_i_proclib:
head_f_l_proclib            db 'System error',0
err_message_import_proclib  db 'Error on load import library proc_lib.obj',0


boxlib_import:

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


proclib_import:

OpenDialog_Init         dd aOpenDialog_Init
OpenDialog_Start        dd aOpenDialog_Start
OpenDialog__Version     dd aOpenDialog_Version
                        dd 0
                        dd 0
aOpenDialog_Init        db 'OpenDialog_init',0
aOpenDialog_Start       db 'OpenDialog_start',0
aOpenDialog_Version     db 'Version_OpenDialog',0


;Data for edit box
edit_torrent_path edit_box 200,10,10,0xffffff,0x6f9480,0,0xAABBCC,0,308,hed,mouse_dd,ed_focus,hed_end-hed-1,hed_end-hed-1

hed                     db 'Insert new torrent path here',0
hed_end:

mouse_dd                rd 1
p_info                  process_information

;Data for open dialog
OpenDialog_data:
.type                   dd 0
.procinfo               dd procinfo
.com_area_name          dd communication_area_name  ;+8
.com_area               dd 0  ;+12
.opendir_pach           dd plugin_pach  ;+16
.dir_default_pach       dd communication_area_default_pach  ;+20
.start_path             dd od_path  ;+24
.draw_window            dd draw_window  ;+28
.status                 dd 0  ;+32
.openfile_pach          dd openfile_pach  ;+36
.filename_area          dd filename_area  ;+40
.filter_area            dd Filter
.x:
  .x_size               dw 420 ;+48 ; Window X size
  .x_start              dw 10 ;+50 ; Window X position
.y:
  .y_size               dw 320 ;+52 ; Window y size
  .y_start              dw 10 ;+54 ; Window Y position

communication_area_name:
                        db 'FFFFFFFF_open_dialog',0

od_path:
                        db '/sys/File Managers/OpenDial',0

open_dialog_name:
                        db 'opendial',0
  
communication_area_default_pach:
                        db '/rd/1',0


Filter:
                        dd Filter.end - Filter.1
  .1:
                        db 'JPEG',0
                        db 'JPG',0
                        db 'JPE',0
                        db 'PNG',0
                        db 'GIF',0
                        db 'BMP',0
                        db 'KEX',0
                        db 'DAT',0
                        db 'INI',0
.end:
                        db 0

path                    rb 4096
openfile_pach           rb 4096
plugin_pach             rb 4096
procinfo                rb 1024
filename_area           rb 256
cur_dir_path            rb 4096
library_path            rb 4096

I_END:
	rb 0x1000      				; stack
E_END:
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

      mcall     0, <100,600>, <100,600>, 0x34eeeeee, 0x80000000, window_title 

      ;New Torrent Section Drawing
      mov       ebx, 10 shl 16
      mov       bx,  10
      mcall     4,,0,label1_string,label1_string.length

      mov       ebx, 20 shl 16
      mov       bx,  33
      mcall     4,,0,label2_string,label2_string.length

      push      dword edit_torrent_path
      call      [edit_box_draw]

      mcall     8, <20,70>, <60,20>,[button_open_identifier], 0x00dddddd
      mov       ebx, 25 shl 16
      mov       bx,  64
      mcall     4,,0,button_open_string,button_open_string.length 

      mcall     8, <110,80>, <60,20>,[button_add_identifier], 0x00dddddd
      mov       ebx, 115 shl 16
      mov       bx,  64
      mcall     4,,0,button_add_string,button_add_string.length

      mov       ebx, 1 shl 16
      mov       bx,  100
      mcall     4,,0,seperator_string,seperator_string.length

      ;Existing Torrent Section Drawing
      mov       ebx, 10 shl 16
      mov       bx,  110
      mcall     4,,0,label3_string,label3_string.length

      mov       ebx, 1 shl 16
      mov       bx,  250
      mcall     4,,0,seperator_string,seperator_string.length
  
      ;Torrent Progress/Details Drawing
      mov       ebx, 10 shl 16
      mov       bx,  260
      mcall     4,,0,label4_string,label4_string.length

      mov       ebx, 1 shl 16
      mov       bx,  410
      mcall     4,,0,seperator_string,seperator_string.length

      ;File List Drawing
      mov       ebx, 10 shl 16
      mov       bx,  420
      mcall     4,,0,label5_string,label5_string.length

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

library       \
        libini,  'libini.obj' , \
        libio,   'libio.obj'  , \
        proc_lib,'proc_lib.obj',\
        box_lib, 'box_lib.obj'

import libini                               , \
        ini.get_shortcut, 'ini_get_shortcut'

import libio                    , \
        libio.init, 'lib_init'  , \
        file.size , 'file_size' , \
        file.open , 'file_open' , \
        file.read , 'file_read' , \
        file.close, 'file_close'

import  proc_lib                            ,\
        OpenDialog_Init  ,'OpenDialog_init' ,\
        OpenDialog_Start ,'OpenDialog_start'

import  box_lib                           ,\
        edit_box_draw     ,'edit_box'     ,\
        edit_box_key      ,'edit_box_key' ,\
        edit_box_mouse    ,'edit_box_mouse'


include_debug_strings

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Data Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Data for window
window_title             db 'BitTorrent Clinet v1.0',0

;Data for labels
label1_string            db 'New Torrent : ',0
.length                  =  $-label1_string
label2_string            db 'Path : ',0
.length                  =  $-label2_string
label3_string            db 'Existing Torrents : ',0
.length                  =  $-label3_string
label4_string            db 'Torrent Progress & Details : ',0
.length                  =  $-label4_string
label5_string            db 'File List : ',0
.length                  =  $-label5_string
seperator_string         db '------------------------------------------------------------------------------------------------------------------------------------------------------',0
.length                  =  $-seperator_string




;Data for buttons
button_open_identifier   dd 5
button_add_identifier    dd 6
button_open_string       db 'Open File',0
.length                  =  $ - button_open_string
button_add_string        db 'Add Torrent',0
.length                  =  $ - button_add_string

;Data for edit box
edit_torrent_path edit_box 300,70,30,0xffffff,0x6f9480,0,0xAABBCC,0,308,hed,mouse_dd,ed_focus,hed_end-hed-1,hed_end-hed-1

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
                        db 'TORRENT',0
                        db 'JPG',0
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
  rb 0x1000             ; stack
E_END:
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

include 'includes/struct.inc'
include 'includes/proc32.inc'
include 'includes/macros.inc'
include 'includes/config.inc'
include 'includes/network.inc'
include 'includes/debug-fdo.inc'
include 'includes/dll.inc'
include 'includes/box_lib.mac'
include 'includes/load_lib.mac'
include 'includes/optionbox.inc'
@use_library              ;use load lib macros
version_op
use_option_box


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

      ;Setting mask
      mcall   40, 0x25

      ;drawing window and main event loop
      call    draw_window      

  event_wait:
        mcall   10

        cmp     eax, 1
        jz      .redraw

        cmp     eax, 2
        jz      .key

        cmp     eax, 3
        jz      .button

        mouse_option_boxes option_boxes,option_boxes_end

        push    dword edit_torrent_path
        call    [edit_box_mouse]

        push    dword edit_download_path
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
        je      .openfile_button
        cmp     ah, 6
        je      .openfolder_button
        cmp     ah, 7
        DEBUGF 2, "INFO : Add button pressed.\n"
        je      .add_button
        jmp     event_wait  
  
  .openfile_button:
        call    open_dlg
        jmp     event_wait

  .openfolder_button:
        jmp     event_wait

  .add_button:
        call    add_torrent
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

      ;SECTION 1 : New Torrent Section Drawing
      mcall     4,  <10,10>,0xB0000000,label11_string
      mcall     13, <12,560>, <27,80>, 0x005080DD
      
      mcall     4,  <20,35>,0x00FFFFFF,label12_string
      mcall     4,  <20,55>,0x00FFFFFF,label13_string

      push      dword edit_torrent_path
      call      [edit_box_draw]
      push      dword edit_download_path
      call      [edit_box_draw]

      mcall     8, <450,70>, <35,15>,[button_openfile_identifier], 0x007887A6
      mcall     4, <455,39>,0x00FFFFFF,button_openfile_string 

      mcall     8, <450,80>, <55,15>,[button_openfolder_identifier], 0x007887A6
      mcall     4, <455,59>,0x00FFFFFF,button_openfolder_string 


      mcall     8, <20,80>, <80,20>,[button_addtorrent_identifier], 0x007887A6
      mcall     4, <25,84>,0x00FFFFFF,button_addtorrent_string

      ;SECTION 2 : Existing Torrent Section Drawing
      mcall     4,  <10,120>,0xB0000000,label21_string
      mcall     13, <12,560>, <137,250>, 0x005080DD
      draw_option_boxes option_boxes,option_boxes_end

      mcall     8, <20,90>, <350,20>,[button_showtorrent_identifier], 0x007887A6
      mcall     4, <25,354>,0x00FFFFFF,button_showtorrent_string

      mcall     8, <140,130>, <350,20>,[button_starttorrent_identifier], 0x007887A6
      mcall     4, <145,354>,0x00FFFFFF,button_starttorrent_string

      mcall     8, <290,110>, <350,20>,[button_removetorrent_identifier], 0x007887A6
      mcall     4, <295,354>,0x00FFFFFF,button_removetorrent_string

  
      ;SECTION 3 : Torrent Progress/Details Drawing
      mcall     4,  <10,400>, 0xB0000000,label31_string
      mcall     13, <12,560>, <417,150>, 0x005080DD
   
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

add_torrent:
          push    edi

          DEBUGF  2, "INFO : In add_torrent.\n"

          mov     eax, [localhost_ip]
          mov     [sockaddr_backend.ip],eax

          ;Opening a socket
          mcall   socket, AF_INET4, SOCK_STREAM, 0
          cmp     eax, -1
          jnz     @f
          DEBUGF 3, "ERROR : Open socket : %d\n",ebx
          jmp     .error

         ;Connecting with backend
  @@:     mov     [socketnum], eax
          mcall   connect, [socketnum], sockaddr_backend, sockaddr_backend.length
          cmp     eax, -1
          jnz     @f
          DEBUGF 3, "ERROR : Connect %d\n",ebx
          jmp     .error
  @@:

  .error: DEBUGF 3, "ERROR : Procedure ended with an error.\n"
          mcall   close, [socketnum]
          mov     eax, -1
          pop     edi
          ret

  .exit:  DEBUGF 2, "INFO : Procedure ended successfully.\n"
          mcall   close, [socketnum]
          mov     eax, 0

          pop     edi
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
;Data for connecting with backend
sockaddr_backend:  
                        dw AF_INET4
    .port               dw 23 shl 8     ;port 50000 = 0xC350 -in network byte order     
    .ip                 dd 0
                        rb 10
    .length             =  $ - sockaddr_backend

localhost_ip:
                        db 127
                        db 0
                        db 0
                        db 1

socketnum               dd 0

buffer                  rb 512
.length                 =  512

;Data for window
window_title             db 'BitTorrent Clinet v1.0',0

;Data for labels
label11_string           db 'New Torrent : ',0
label12_string           db 'Torrent File : ',0
label13_string           db 'Download Location : ',0
label21_string           db 'Existing Torrents : ',0
label31_string           db 'Torrent Progress/Details : ',0

;Data for buttons
button_openfile_identifier      dd 5
button_openfolder_identifier    dd 6
button_addtorrent_identifier    dd 7
button_showtorrent_identifier   dd 8
button_starttorrent_identifier  dd 9
button_removetorrent_identifier dd 10
button_openfile_string          db 'Open File',0
button_openfolder_string        db 'Open Folder',0
button_addtorrent_string        db 'Add Torrent',0
button_showtorrent_string       db 'Show Torrent',0
button_starttorrent_string      db 'Start/Pause Torrent',0
button_removetorrent_string     db 'Remove Torrent',0



;Data for edit box
edit_torrent_path edit_box 300,135,33,0xffffff,0x6f9480,0,0xAABBCC,0,308,hed,mouse_dd,ed_focus,hed_end-hed-1,hed_end-hed-1

edit_download_path edit_box 300,135,53,0xffffff,0x6f9480,0,0xAABBCC,0,308,hed,mouse_dd,ed_focus,hed_end-hed-1,hed_end-hed-1

hed                     db 'Insert path here',0
hed_end:

mouse_dd                rd 1
p_info                  process_information

;Data for optionbox (radiobuttons)
option_boxes:
op1 option_box option_group1,20,145,0xFFFFFF,0,0xFFFFFF,op_text.1,op_text.e1-op_text.1
op2 option_box option_group1,20,160,0xFFFFFF,0,0xFFFFFF,op_text.2,op_text.e2-op_text.2
op3 option_box option_group1,20,175,0xFFFFFF,0,0xFFFFFF,op_text.3,op_text.e3-op_text.3

option_boxes_end:

op_text:
.1 db 'Torrent #1' 
.e1:
.2 db 'Torrent #2'
.e2:
.3 db 'Torrent #3'
.e3:

option_group1 dd op1

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
                        db 'DIR',0
.end:
                        db 0

;path                    rb 4096
;openfile_pach           rb 4096
;plugin_pach             rb 4096
;procinfo                rb 1024
;filename_area           rb 256
;cur_dir_path            rb 4096
;library_path            rb 4096

path                    rb 1024
openfile_pach           rb 1024
plugin_pach             rb 1024
procinfo                rb 1024
filename_area           rb 256
cur_dir_path            rb 1024
library_path            rb 1024

I_END:
  rb 0x1000             ; stack
E_END:
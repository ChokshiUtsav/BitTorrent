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

include 'includes/struct.inc'
include 'includes/proc32.inc'
include 'includes/macros.inc'
include 'includes/config.inc'
include 'includes/network.inc'
include 'includes/debug-fdo.inc'
include 'includes/dll.inc'
include 'includes/libio.inc'
include 'torrent.inc'
include 'torrent_actions.inc'
include 'torrent_errors.inc'
include 'bittorrent_backend_actions.asm'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;Code Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;entry point of main thread

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

            ;start torrent
    @@:     invoke  torrent.new, BT_NEW_FILE, torrent_filename1, download_location1
            cmp     eax, -1
            jne     @f
            DEBUGF 3, "INFO : Problem with torrent.new\n"
            jmp     .error

    @@:     invoke torrent.start, eax
            

    .error: DEBUGF 3, "ERROR : Thread 1 ended with error.\n"
            mcall   -1

    .exit:  DEBUGF 2, "INFO : Thread 1 exited successfully.\n"    
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
       torrent.start,'start',       \
       torrent.resume,'resume'   

include_debug_strings

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;Data Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Data for all torrents
torrent_filename1    db '/usbhd0/1/test.torrent',0
download_location1   db '/tmp0/1',0

I_END:
    rb 0x1000                   ; stack
E_END:
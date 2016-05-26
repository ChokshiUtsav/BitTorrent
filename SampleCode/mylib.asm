;    libbmfnt -- torrent library
;
;    Copyright (C) 2015 Ivan Baravy (dunkaist)
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

format MS COFF

public @EXPORT as 'EXPORTS'

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;Include Area;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

include 'struct.inc'
include 'proc32.inc'
include 'macros.inc'
include 'libio.inc'
include 'debug-fdo.inc'
purge section,mov,add,sub

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;Code Area;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section '.flat' code readable align 16

proc lib_init
          mov     [mem.alloc], eax
          mov     [mem.free], ebx
          mov     [mem.realloc], ecx
          mov     [dll.load], edx
              
          invoke  dll.load, @IMPORT
          or  eax, eax
          jz  .libsok

          DEBUGF 3, "ERROR : Problem Initializing libraries.\n"
          xor eax, eax
          inc eax
          ret

 .libsok: DEBUGF 2, "INFO : Library Initialized Successfully.\n"
          xor eax,eax
          ret
endp

proc mylib.test _file

    push ebx      
    DEBUGF 2, "INFO : Mylib.Test\n"
      invoke  file.size, [_file]
      DEBUGF 2, "INFO : File Size is %d\n",ebx
      cmp     ebx, -1
      jz     .error
      jmp     .quit       
  .error:
      DEBUGF 3, "ERROR : file.size\n"    
  .quit:
      pop ebx
        ret
endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;Import & Export Area ;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 16
@EXPORT:

export                                      \
        lib_init           , 'lib_init'   , \
        mylib.test         , 'test'

align 16
@IMPORT:

library                            \
        libio,     'libio.obj'

import libio                    , \
        libio.init, 'lib_init'  , \
        file.size , 'file_size'

include_debug_strings


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Data Area ;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section '.data' data readable writable align 16

mem.alloc       dd ?
mem.free        dd ?
mem.realloc     dd ?
dll.load        dd ?
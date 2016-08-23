;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    Copyright (C) 2015 Ivan Baravy (dunkaist)
;    Modified by Utsav Chokshi (Utsav_Chokshi)
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods for percent encoding

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;Procedure Area;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Converts data to percent encoded data
;Input     : pointer to dat, length of data
;Outcome   : stores encoded data at location pointed by edi
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent._.percent_encode _data, _len
            push    ebx esi
            
            DEBUGF 2, "INFO: In torrent._.percent_encode\n"
            
            mov     esi, [_data]
            mov     ecx, [_len]
    .next_byte:
            jecxz   .quit
            mov     eax, '%   '
            stosb
            xor     eax, eax
            lodsb
            push    eax
            shr     eax, 4
            movzx   eax, [hexnums + eax]
            stosb
            pop     eax
            and     eax, 0x0f
            movzx   eax, [hexnums + eax]
            stosb
            dec     ecx
            jmp     .next_byte

    .quit:  DEBUGF 2,"INFO: Procedure ended successfully\n"
            pop     esi ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;Data Area;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

hexnums db '0123456789ABCDEF'

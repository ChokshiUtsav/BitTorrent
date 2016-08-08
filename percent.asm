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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods for initializing and setting bitfield of torrent and peer

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Procedure Area ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;initializes bitfield to zeros
proc torrent._.init_bitfield _torrent, _loc
            
            locals
                    byte_constant   dd 8
            endl

            push    ebx ecx edx edi

            mov     edi, [_loc]
            mov     ebx, [_torrent]
            mov     eax, [ebx + torrent.pieces_cnt]
            mov     edx, 0
            div     [byte_constant]
            cmp     edx, 0
            je      @f
            inc     eax

       @@:  mov     ecx, eax
            xor     eax, eax
    .loop:  cmp     ecx, 0
            je      .quit
            stosd
            dec     ecx
            jmp     .loop

    .quit:  pop     edi edx ecx ebx
            ret
 endp

 ;sets bit in bitfield (_loc : peer.bitfield or torrent.bitfield)
 proc  bitfield._.set_bit _loc, _index

            DEBUGF 2, "INFO : In bitfield._.set_bit\n"

            push  esi

            mov   esi, [_loc]
            mov   eax, [_index]
            shr   eax, 3            ;eax=index/8
            add   esi, eax
            mov   eax, [_index]
            and   eax, 7            ;eax=index%8
            bts   [esi], ax         ;sets bit

            pop   esi
            ret
 endp

 ;gets bit from bitfield
 proc  bitfield._.get_bit _torrent, _loc, _index

            DEBUGF 2, "INFO : In bitfield._.get_bit\n"

            push  esi

            mov   esi, [_loc]
            mov   eax, [_index]
            shr   eax, 3            ;eax=index/8
            add   esi, eax
            mov   eax, [_index]
            and   eax, 7            ;eax=index%8
            bt    [esi], ax     ;sets bit

            pop   esi
            ret
 endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods for initializing ,setting and manipulating torrent.bitfield and peer.bitfield

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Procedure Area ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Initializes bitfield to zeros
;Input   : pointer to torrent data structure and pointer to bitfield
;Outcome : all bytes of bitfield are set to zero
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : sets bit in bitfield (_loc : peer.bitfield or torrent.bitfield)
;Input   : pointer to bitfield , piece-index
;Outcome : bit that corresponds to piece-index is set to 1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : gets bit in bitfield (_loc : peer.bitfield or torrent.bitfield)
;Input   : pointer to bitfield , piece-index
;Outcome : eax = 1/0 (bit that corresponds to piece-index)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc  bitfield._.get_bit _torrent, _loc, _index

            DEBUGF 2, "INFO : In bitfield._.get_bit\n"

             push  esi

             mov   esi, [_loc]
             mov   eax, [_index]
             shr   eax, 3            ;eax=index/8
             add   esi, eax
             mov   eax, [_index]
             and   eax, 7            ;eax=index%8
             bt    [esi], ax         ;tests bit
             jc    @f
             mov   eax, 0
             jmp   .quit

       @@:   mov   eax, 1    

      .quit: pop   esi
             ret
 endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : Finds first available piece
;Input   : pointer to torrent data structure and peer data structre
;Outcome : eax = piece-index
           eax = -1 (if no piece found)
;Note    :Availbale piece satisfies following three conditions :
;1) Peer has the piece available (Check using peer.bitfield)
;2) Client does not have the piece (Check using torrent.bitfield)
;3) Piece is not being downloaded by other peer (Check using piece.download_status)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc bitfield._.find_first_avl_piece _torrent, _peer
            
            locals
                    size            dd ?
                    index           dd ?
            endl

            DEBUGF 2, "INFO : In find_first_avl_piece\n"
            push    ebx ecx edx esi edi

            mov     eax, [_peer]
            lea     edi, [eax + peer.bitfield]
            mov     ebx, [_torrent]
            lea     esi, [ebx + torrent.bitfield]

            mov     eax, [ebx + torrent.pieces_cnt]
            shr     eax, 3
            mov     [size], eax
            mov     edx, [ebx + torrent.pieces_cnt]
            and     dx, 7

            mov     ecx, 0
    .loop:  cmp     ecx, [size]
            je      .check_lastbyte
            mov     eax, 0
            mov     ebx, 0
            mov     al, byte [esi]
            mov     bl, byte [edi]
            not     ax
            and     bx, ax

    @@:     bsf     ax, bx
            jz      @f

            mov      [index], ecx
            shl      [index], 3
            add      [index], eax
            stdcall  piece._.get_status, [_torrent], [index]
            cmp      eax, BT_PIECE_DOWNLOAD_NOT_STARTED
            je       .quit
            bsf      ax, bx
            btr      bx, ax
            jmp      @b

     @@:    inc     ecx
            add     esi, 1
            add     edi, 1
            jmp     .loop

    .check_lastbyte:
            cmp      edx, 0
            je       .error
            mov      eax, 0
            mov      ebx, 0
            mov      al, byte [esi]
            mov      bl, byte [edi]
            not      ax
            and      bx, ax
    @@:     bsf      ax, bx
            jz       .error
            cmp      bx, dx
            jg       .error
            imul     ecx, 8
            mov      [index], ecx
            add      [index], eax
            stdcall  piece._.get_status, [_torrent], [index]
            cmp      eax, BT_PIECE_DOWNLOAD_NOT_STARTED
            je       .quit
            bsf      ax, bx
            btr      bx, ax
            jmp      @b

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            mov     eax, -1
            pop     edi esi edx ecx ebx
            ret 

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
            mov     eax, [index]
            pop     edi esi edx ecx ebx
            ret 
endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods related to managing memory for pieces which has been kept in main memory
;Methods of this file mainly invoves finding suitable empty location for piece download/upload.
;These methods are useful while torrent download is in progress.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Procedure Area ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Allocating memory for downloading pieces 
proc torrent._.allocate_mem_space _torrent
            
            DEBUGF 2, "INFO : In torrent._.allocate_mem_space\n"

            push    ebx ecx edi

            ;Allocating memory
            mov     ebx, [_torrent]
            mov     ecx, [ebx + torrent.piece_length]
            imul    ecx, NUM_PIECES_IN_MEM
            invoke  mem.alloc, ecx
            test    eax, eax
            jnz     @f
            DEBUGF 3, "ERROR : Not enough memory\n"
            jmp     .error

      @@:   mov     [ebx + torrent.piece_mem], eax

            ;initializing piece memory status
            mov     ecx, NUM_PIECES_IN_MEM
            lea     edi, [ebx + torrent.piece_mem_status]
    .loop:  cmp     ecx, 0
            je      .quit
            mov     eax, MEM_LOCATION_EMPTY
            stosb
            mov     eax, 0x00000000
            stosd
            dec     ecx
            jmp     .loop

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            mov     eax, -1
            pop     edi ecx ebx
            ret

    .quit : DEBUGF 2, "INFO : Procedure ended successfully\n"
            mov     eax, 0
            pop     edi ecx ebx
            ret
endp

;Finds an first memory location with given status
;Sets piece index and status , if found
proc torrent._.get_mem_loc _torrent, _index, _status

            DEBUGF 2, "INFO : In torrent._.get_mem_empty_loc\n"

            push    ebx ecx esi
            
            mov     ebx, [_torrent]
            mov     ecx, 0
            lea     esi, [ebx + torrent.piece_mem_status]

    .loop:  cmp     ecx, NUM_PIECES_IN_MEM
            je      .error
            mov     eax, [_status]
            cmp     byte [esi], al
            je      .location_found
            add     esi, 5
            inc     ecx
            jmp     .loop

    .location_found:
            mov     byte [esi], MEM_LOCATION_IN_USE
            inc     esi
            mov     eax, [_index]
            mov     dword[esi], eax
            mov     eax, [ebx + torrent.piece_length]
            imul    eax, ecx
            add     eax, [ebx + torrent.piece_mem]
            jmp     .quit

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            pop     esi ecx ebx
            mov     eax, -1
            ret

    .quit : DEBUGF 2, "INFO : Procedure ended successfully\n"
            pop     esi ecx ebx
            ret        
endp

;sets piece index and download/upload status for memory location
proc torrent._.set_piece_mem_status _torrent, _index, _status
            
            DEBUGF 2, "INFO : torrent._.set_piece_mem_status\n"                

            push    ebx ecx esi
            
            mov     ebx, [_torrent]
            mov     ecx, 0
            lea     esi, [ebx + torrent.piece_mem_status]

    .loop:  cmp     ecx, NUM_PIECES_IN_MEM
            je      .error
            inc     esi
            lodsd
            cmp     eax, [_index]
            jne     @f
            sub     esi, 5
            mov     eax, [_status]
            mov     byte[esi], al
            jmp     .quit
     @@:    inc     ecx
            jmp     .loop

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            pop     esi ecx ebx
            ret

    .quit : DEBUGF 2, "INFO : Procedure ended successfully\n"
            pop     esi ecx ebx
            ret     
endp

;prints piece_mem_status
proc torrent._.print_piece_mem_status _torrent

            push    eax ebx ecx esi
            
            mov     ebx, [_torrent]
            mov     ecx, 0
            lea     esi, [ebx + torrent.piece_mem_status]

    .loop:  cmp     ecx, NUM_PIECES_IN_MEM
            je      .quit
            lodsb
            DEBUGF 2, "INFO : status %d\n", eax
            lodsd
            DEBUGF 2, "INFO : index %d\n", eax
            inc     ecx
            jmp     .loop

    .quit:  pop     esi ecx ebx eax
            ret
endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods related to generating and verifying SHA1 hash

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Procedure Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc  : generates SHA1 hash of data
;Input : Pointer to data , length of data and pointer to location where 20 byte hash can be stored
;Outcome : Stores hash of data at location pointed by _hash 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent._.generate_hash _data, _len, _hash
            
            DEBUGF 2, "INFO : In torrent._.generate_hash\n"
        
            push        ebx ecx edx esi edi

            stdcall     sha1.init, ctx
            stdcall     sha1.update,ctx, [_data], [_len]
            stdcall     sha1.final, ctx
            lea         esi, [ctx.hash]
            DEBUGF 2,"INFO : hash :%x%x%x%x%x\n'",[esi+0x0],[esi+0x4],[esi+0x8],[esi+0xc],[esi+0x10]
            mov         edi, [_hash]
            mov         ecx, 20
            rep         movsb

    .quit:  DEBUGF 2,   "INFO : Procedure ended successfully.\n"
            pop         edi esi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc    : verifies hash of piece-data against original hash
;Input   : Pointer to torrent data structure, piece-index and pointer to hash
;Outcome : eax = 0  -> Success (Hash matched)
           eax = -1 -> Error (Hash did not match)  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc piece._.verify_hash _torrent, _index, _hash

            DEBUGF 2, "INFO : In piece._.ver_hash\n"
            
            push        ebx ecx edx esi edi

            mov         eax, [_torrent]
            mov         ebx, [_index]
            imul        ebx, sizeof.piece
            add         ebx, [eax + torrent.pieces]
            lea         esi, [ebx + piece.piece_hash]
            mov         edi, [_hash]
            mov         ecx, 20
            rep         cmpsb

            cmp         ecx, 0
            je          .quit

    .error: DEBUGF 3,  "ERROR : Hash did not match\n"
            mov         eax, -1
            pop         edi esi edx ecx ebx
            ret

    .quit:  DEBUGF 2,  "INFO : Hash matched\n"
            mov         eax, 0
            pop         edi esi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Data Area;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align SHA1_ALIGN
ctx ctx_sha1
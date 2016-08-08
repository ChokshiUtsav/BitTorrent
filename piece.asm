;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods related to piece
;Methods of this file mainly involves IO and file related operation.
;These methods are useful as part of pre-processing and post-processing and do not confront any network related operations.

;A piece is chunk of torrent data which can be verified against hash provided in torrent file.
;Usually pieces are of size 256kB.
;But piece may range from 256kB to 4096kB depending on total size of torrent.

;Structure for "piece" can be found in torrent.inc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Procedure Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : fills array of pieces in torrent structure.
;Input     : pointer to torrent data structure and pointer to pieces
;Outcome   : array of pieces filled with details
;ErrorCode : eax = 0  -> success
             eax = -1 -> error  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc piece._.fill_all_pieces _torrent, _pieces

            DEBUGF 2, "INFO : In piece._.fill_all_pieces\n"
    
            push        ebx ecx edx edi

            mov         ebx, [_torrent]
            mov         ecx, [ebx+torrent.pieces_cnt]

            ;Intialization
            mov         [piece_index], 0
            mov         [cur_file_index], 0
            mov         [cur_file_offset],0
            push        esi
            mov         esi, [ebx+torrent.files]
            lodsd
            pop         esi
            mov         [cur_file_rem_size], eax

    .loop:  
            cmp         [piece_index], ecx
            je          .quit
            stdcall     piece._.fill_piece, [_torrent], [_pieces]
            inc         [piece_index]
            jmp         .loop

    .error: DEBUGF 3, "ERROR : Procedure ended with error.\n"
            mov         eax, -1
            pop         edi edx ecx ebx
            ret

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully.\n"
            mov         eax, 0
            pop         edi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : fills a single piece with index = [piece_index]
;Input     : pointer to torrent data structure and pointer to pieces
;Outcome   : a piece structure filled with details
;ErrorCode : eax = 0  -> success
             eax = -1 -> error  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;             

proc piece._.fill_piece _torrent, _pieces
            
            ;DEBUGF 2, "INFO : In piece._.fill_piece %d\n",[piece_index]

            push        ebx ecx edx edi

            ;Initializations
            mov        [num_offsets], 0
            mov        [cur_piece_offset], 0
            mov        ebx, [_torrent]
            mov        eax, [ebx+torrent.piece_length]
            mov        [cur_piece_rem_size], eax

            ;go to correct location in array of pieces
            mov         ebx, [piece_index]
            imul        ebx, sizeof.piece
            add         ebx, [_pieces]

            ;index
            mov         eax, [piece_index]
            mov         [ebx+piece.index],eax

            ;hash
            lea         edi, [ebx+piece.piece_hash]
            mov         ecx, 20
            rep         movsb

            ;download status
            mov        [ebx+piece.download_status], BT_PIECE_DOWNLOAD_NOT_STARTED

            ;number of blocks downloaded
            mov        [ebx+piece.num_blocks_downloaded], 0

    .loop:
            cmp        [cur_piece_rem_size], 0
            je          .quit
            mov        ecx, [num_offsets]
            imul       ecx, 4

            ;piece_offset
            lea       edi, [ebx+piece.piece_offset]
            add       edi, ecx
            mov       eax, [cur_piece_offset]
            stosd

            ;file_offset
            lea        edi, [ebx+piece.file_offset]
            add        edi, ecx
            mov        eax, [cur_file_offset]
            stosd

            ;file_index
            lea        edi, [ebx+piece.file_index]
            add        edi, ecx
            mov        eax, [cur_file_index]
            stosd

            mov        eax, [cur_file_rem_size]
            cmp        [cur_piece_rem_size], eax
            ja          .nextfile

    .samefile:

            ;length
            lea        edi, [ebx+piece.length]
            add        edi, ecx
            mov        eax, [cur_piece_rem_size]
            stosd

            mov        eax, [cur_piece_rem_size]
            add        [cur_file_offset], eax
            sub        [cur_file_rem_size],eax

            cmp        [cur_file_rem_size], 0
            jne        @f
            jmp        .newfile

        @@: mov        [cur_piece_rem_size], 0
            inc        [num_offsets]
            jmp        .loop
            

    .nextfile:
            ;length
            lea        edi, [ebx+piece.length]
            add        edi, ecx
            mov        eax, [cur_file_rem_size]
            stosd

            mov        eax, [cur_file_rem_size]
            sub        [cur_piece_rem_size],eax
            jmp        .newfile

    .newfile:
            mov        [cur_file_offset], 0
            inc        [cur_file_index]

            ;check any file left ? -> cur_file_index == files_cnt ?
            push       ebx
            mov        ebx, [_torrent]
            mov        eax, [ebx+torrent.files_cnt]
            cmp        [cur_file_index], eax
            jne        @f
            pop        ebx
            inc        [num_offsets]
            jmp        .quit

        @@: push       esi
            mov        ebx, [_torrent]
            mov        esi, [cur_file_index]
            imul       esi, 0x1000           
            add        esi, [ebx+torrent.files]
            lodsd
            pop        esi ebx
            mov        [cur_file_rem_size], eax
            inc        [num_offsets]
            jmp        .loop

    .error: ;DEBUGF 3,  "ERROR : Procedure ended with error.\n"
            mov         eax, -1
            pop         edi edx ecx ebx
            ret

    .quit:  ;DEBUGF 2,  "INFO : Procedure ended successfully.\n"
            mov         eax, [num_offsets]
            mov         [ebx+piece.num_offsets],eax
            mov         eax, 0
            pop         edi edx ecx ebx
            ret         
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : returns download status of piece
;Input     : pointer to torrent data structure and index of piece
;Outcome   : eax = download_status
;Note      : Download status can be one of this :
             BT_PIECE_DOWNLOAD_NOT_STARTED/BT_PIECE_DOWNLOAD_IN_PROGRESS/ BT_PIECE_DOWNLOAD_COMPLETE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc piece._.get_status _torrent, _index
            
            DEBUGF 2, "INFO : In piece._.get_status\n"

            push       ebx esi

            mov        esi, [_index]
            imul       esi, sizeof.piece
            mov        ebx, [_torrent]
            add        esi, [ebx + torrent.pieces]
            mov        eax, [esi + piece.download_status]

            pop        esi ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : sets download status of piece
;Input     : pointer to torrent data structure , index of piece, download_status 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sets download status of piece
proc piece._.set_status _torrent, _index, _status
            
            DEBUGF 2, "INFO : In piece._.set_status\n"

            push       ebx esi

            mov        esi, [_index]
            imul       esi, sizeof.piece
            mov        ebx, [_torrent]
            add        esi, [ebx + torrent.pieces]
            mov        eax, [_status]
            mov        [esi + piece.download_status], eax 

            pop        esi ebx
            ret
endp  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : sets number of blocks, downloaded, for a piece
;Input     : pointer to torrent data structure , index of piece, number of blocks 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sets block number of piece
proc piece._.set_num_blocks _torrent, _index, _numblocks
            
            DEBUGF 2, "INFO : In piece._.set_num_blocks\n"

            push       ebx esi

            mov        esi, [_index]
            imul       esi, sizeof.piece
            mov        ebx, [_torrent]
            add        esi, [ebx + torrent.pieces]
            mov        eax, [_numblocks]
            mov        [esi + piece.num_blocks_downloaded], eax

            pop        esi ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : reads a single piece from file(s) to memory
;Input     : pointer to torrent data structure, index of piece,pointer to location that contains data
;Outcome   : memory location pointed by data is filled with piece data
;ErrorCode : eax = 0  -> success
             eax = -1 -> error  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc piece._.get_piece _torrent, _index, _data

            push        ebx ecx edx edi esi

            mov         ebx, [_index]
            imul        ebx, sizeof.piece
            mov         eax, [_torrent]
            add         ebx, [eax+torrent.pieces]

            ;Initializations
            mov         [num_offsets], 0
            lea         edi, [_data]

    .loop:  mov         ecx, [ebx+piece.num_offsets]
            cmp         ecx, [num_offsets]
            je          .quit

            mov         ecx, [num_offsets]
            imul        ecx, 4
            
            ;getting number of bytes to read from the file
            lea         esi, [ebx+piece.length]
            add         esi, ecx
            lodsd
            mov         [num_bytes], eax

            ;getting file-offset
            lea         esi, [ebx+piece.file_offset]
            add         esi, ecx
            lodsd
            mov         [cur_file_offset], eax

            ;getting file-index
            lea         esi, [ebx+piece.file_index]
            add         esi, ecx
            lodsd
            mov         [cur_file_index], eax

            ;getting file-name
            mov         eax, [_torrent]
            mov         esi, [cur_file_index]
            imul        esi, 0x1000
            add         esi, 4           
            add         esi, [eax+torrent.files]

            ;open file for reading
            invoke      file.open, esi, O_READ
            or          eax, eax
            jnz         @f
            DEBUGF 2, "ERROR : Problem opening file for write\n"
            jmp         .error


            ;set file pointer to offset from position 0(SEEK_SET)
        @@: mov         [filedesc], eax
            invoke      file.seek, [filedesc], [cur_file_offset], SEEK_SET
            inc         eax
            jnz         @f
            DEBUGF 2, "ERROR : Problem with file seek\n"
            jmp         .error

            ;read from file to data
        @@: invoke      file.read, [filedesc], edi, [num_bytes]
            inc         eax
            jnz         @f
            DEBUGF 2, "ERROR : Problem with file write\n"
            jmp         .error

        @@: invoke      file.close, [filedesc]
            add         edi, [num_bytes]
            inc         [num_offsets]
            jmp         .loop   

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            cmp         [filedesc], 0
            jz          @f
            invoke      file.close, [filedesc]
        @@: mov         eax, -1
            pop         esi edi edx ecx ebx
            ret

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
            mov         eax, 0
            pop         esi edi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : ;writes a single piece from memory to file(s)
;Input     : pointer to torrent data structure , index of piece, pointer to location where piece data needs to be written
;Outcome   : files, to which piece belongs, are written
;ErrorCode : eax = 0  -> success
             eax = -1 -> error  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc piece._.set_piece  _torrent, _index, _data
            
            DEBUGF 2, "INFO : In piece._.set_piece\n"
    
            push        ebx ecx edx edi esi

            mov         ebx, [_index]
            imul        ebx, sizeof.piece
            mov         eax, [_torrent]
            add         ebx, [eax+torrent.pieces]

            ;Initializations
            mov         [num_offsets], 0
            mov         edi, [_data]

    .loop:  mov         ecx, [ebx+piece.num_offsets]
            cmp         ecx, [num_offsets]
            je          .quit

            mov         ecx, [num_offsets]
            imul        ecx, 4
            
            ;getting number of bytes to write to the file
            lea         esi, [ebx+piece.length]
            add         esi, ecx
            lodsd
            mov         [num_bytes], eax

            ;getting file-offset
            lea         esi, [ebx+piece.file_offset]
            add         esi, ecx
            lodsd
            mov         [cur_file_offset], eax

            ;getting file-index
            lea         esi, [ebx+piece.file_index]
            add         esi, ecx
            lodsd
            mov         [cur_file_index], eax

            ;getting file-name
            mov         eax, [_torrent]
            mov         esi, [cur_file_index]
            imul        esi, 0x1000
            add         esi, 4           
            add         esi, [eax+torrent.files]

            ;open file for writing
            invoke      file.open, esi, O_WRITE
            or          eax, eax
            jnz         @f
            DEBUGF 2, "ERROR : Problem opening file for write\n"
            jmp         .error

            ;set file pointer to offset from position 0(SEEK_SET)
        @@: mov         [filedesc], eax
            invoke      file.seek, [filedesc], [cur_file_offset], SEEK_SET
            inc         eax
            jnz         @f
            DEBUGF 2, "ERROR : Problem with file seek\n"
            jmp         .error

            ;write to file from data
        @@: invoke      file.write, [filedesc], edi, [num_bytes]
            inc         eax
            jnz         @f
            DEBUGF 2, "ERROR : Problem with file write\n"
            jmp         .error

        @@: invoke      file.close, [filedesc]
            add         edi, [num_bytes]
            inc         [num_offsets]
            jmp         .loop   

    .error: DEBUGF 3, "ERROR : Procedure ended with error\n"
            cmp         [filedesc], 0
            jz           @f
            invoke      file.close, [filedesc]
        @@: mov         eax, -1
            pop         esi edi edx ecx ebx
            ret

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully\n"
            mov         eax, 0
            pop         esi edi edx ecx ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Data Area;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cur_file_index          dd  ?
cur_file_offset         dd  ?
cur_file_rem_size       dd  ?
cur_piece_offset        dd  ?
cur_piece_rem_size      dd  ?
num_offsets             dd  ?
piece_index             dd  ?
num_bytes               dd  ?
file_array_elemet_size  =  0x1000
filename                rb 0x1000
filedesc                dd 0
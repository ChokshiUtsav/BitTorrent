;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods related to piece
;Methods of this file mainly involves IO and file related operation.
;These methods are useful as part of pre-processing and post-processing and do not confront any network related operations.

;A piece is chunk of torrent data which can be verified against hash provided in torrent file
;Usually pieces are of size 512kB
;But piece may range from 256kB to 1024kB depending on total size of torrent.

;Structure for "piece" can be found in torrent.inc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Procedure Area;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;fills array of pieces
proc piece._.fill_all_pieces _torrent, _pieces
	
			push 		eax ebx ecx edx edi

			mov 		ebx, [_torrent]
			mov			ecx, [ebx+torrent.pieces_cnt]

			;Intialization
			mov			[piece_index], 0
			mov			[cur_file_index], 0
			mov			[cur_file_offset],0
			push		esi
			mov			esi, [ebx+torrent.files]
			lodsd
			pop         esi
			mov			[cur_file_rem_size], eax

	.loop:	
			cmp 		[piece_index], ecx
			je			.quit
			stdcall		piece._.fill_piece, [_torrent], [_pieces]
			dec 		ecx
			jmp			.loop

	.error:	

	.quit:	
			pop     edi edx ecx ebx eax
			ret
endp

;fills a single piece
proc piece._.fill_piece _torrent, _pieces
			push 		eax ebx ecx edx edi

			;Initializations
			mov        [num_offsets], 0
			mov        [cur_piece_offset], 0
			mov        ebx, [_torrent]
			mov        eax, [ebx+torrent.piece_length]
			mov        [cur_piece_rem_size], eax

			;go to correct location in array of pieces
			mov			ebx, [piece_index]
			imul		ebx, sizeof.piece
			add			ebx, [_pieces]

			;index
			mov         eax, [piece_index]
			mov         [ebx+piece.index],eax

			;hash
			lea         edi, [ebx+piece.piece_hash]
			mov			ecx, 20
			rep         movsb

			;download status
			mov        [ebx+piece.download_status], BT_PIECE_DOWNLOAD_NOT_STARTED

			;number of blocks downloaded
			mov        [ebx+piece.num_blocks_downloaded], 0x0000

	.loop:
			cmp        [cur_piece_rem_size], 0
			je			.quit
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
			ja			.nextfile

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
			jne		   @f
			jmp        .newfile

		@@:	mov        [cur_piece_rem_size], 0
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

		@@:	push	   esi
			mov        ebx, [_torrent]
			mov        esi, [cur_file_index]
			imul       esi, 0x1000           
			add		   esi, [ebx+torrent.files]
			lodsd
			pop        esi ebx
			mov		   [cur_file_rem_size], eax
			inc        [num_offsets]
			jmp        .loop

	.error:

	.quit:
			pop     edi edx ecx ebx eax
			ret			
endp

;reads a single piece from secondary memory to primary memory
proc piece._.get_piece _torrent, _index
	
endp

;writes a single piece from primary memory to secondary memory
proc piece._.set_piece

endp

;generates hash of piece-data
proc piece._.generate_hash
endp

;verifies hash of piece-data against original hash
proc piece._.verify_hash
endp

;gets hash of piece stored in piece structure
proc piece._.get_hash_of_piece
endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Data Area;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cur_file_index			dd  ?
cur_file_offset			dd  ?
cur_file_rem_size		dd  ?
cur_piece_offset		dd 	?
cur_piece_rem_size		dd  ?
num_offsets				dd  ?
piece_index         	dd  ?
file_array_elemet_size  =  0x1000
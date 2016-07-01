proc torrent._.bdecode_dict _torrent, _dataend, _keytable
        DEBUGF 2, "INFO : In torrent._.bdecode_dict\n"
  .next_key:
        cmp     esi, [_dataend]
        jae     .quit
        cmp     byte[esi], 'e'
        jz      .quit
        stdcall torrent._.bdecode_get_type
        cmp     al, BT_BENCODE_STR
        jnz     .error
        stdcall torrent._.bdecode_readnum
        DEBUGF 2,'key: %s\n',esi:eax
  .value:
        stdcall torrent._.bdecode_process_key, eax, [_keytable]
        test    eax, eax
        jnz     .found
        DEBUGF 2,'skip\n'
        stdcall torrent._.bdecode_skip_element
        jmp     .next_key
  .found:
        DEBUGF 2,'value: '
        stdcall eax, [_torrent], ecx
        jmp     .next_key

  .error:
        DEBUGF 2,'ERROR: torrent.bdecode\n'
  .quit:
        ret
endp


;Converts string of numbers to number and stores in eax
proc torrent._.bdecode_readnum
        xor     eax, eax
        xor     edx, edx
        xor     ecx, ecx
  .next_char:
        lodsb
        cmp     al, '0'
        jb      .quit
        cmp     al, '9'
        ja      .quit
        sub     eax, '0'
        imul    ecx, 10
        add     ecx, eax
        jmp     .next_char
  .quit:
        mov     eax, ecx
        ret
endp


;Identifies type[dictionary,list,integer,string] and stores in eax
proc torrent._.bdecode_get_type
        movzx   eax, byte[esi]
        cmp     al, 'd'
        jnz     @f
        mov     eax, BT_BENCODE_DICT
        inc     esi
        jmp     .quit
    @@:
        cmp     al, 'l'
        jnz     @f
        mov     eax, BT_BENCODE_LIST
        inc     esi
        jmp     .quit
    @@:
        cmp     al, 'i'
        jnz     @f
        mov     eax, BT_BENCODE_INT
        inc     esi
        jmp     .quit
    @@:
        cmp     al, 'e'
        jnz     @f
        mov     eax, BT_BENCODE_END
        inc     esi
        jmp     .quit
    @@:
        mov     eax, BT_BENCODE_STR
        jmp     .quit
  .quit:
        ret
endp


proc torrent._.bdecode_process_key _len, _keytable
        mov     eax, [_len]
        mov     edi, [_keytable]
  .next:
        movzx   ecx, byte[edi]
        test    ecx, ecx
        jnz     @f
        xor     eax, eax
        jmp     .quit
    @@:
        cmp     eax, ecx
        jz      @f
        inc     edi
        add     edi, ecx
        add     edi, 4
        add     edi, 4
        jmp     .next
    @@:
        inc     edi
        push    esi
        rep     cmpsb
        pop     esi
        jz      @f
        add     edi, ecx
        add     edi, 4
        add     edi, 4
        jmp     .next
    @@:
        mov     eax, [edi]
        mov     ecx, [edi+4]
  .quit:
        add     esi, [_len]
        ret
endp


proc torrent._.bdecode_announce _torrent, _arg
        push    ebx edi

        mov     ebx, [_torrent]
        mov     [ebx + torrent.trackers_cnt], 0
        mov     edi, [ebx + torrent.trackers]

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_STR
        jz      @f
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        stdcall torrent._.bdecode_readnum
        DEBUGF 2,'%s\n',esi:eax
        mov     [edi + tracker.announce_len], eax
        add     edi, tracker.announce
        mov     ecx, eax
        rep     movsb
        mov     byte[edi], 0
        inc     [ebx + torrent.trackers_cnt]
        jmp     .quit
        
  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_announce_list _torrent, _arg
DEBUGF 2,'list\n'
        push    ebx edi

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_LIST
        jz      @f
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        mov     ebx, [_torrent]
        mov     [ebx + torrent.trackers_cnt], 0
  .next:
        mov     edi, [ebx + torrent.trackers]
        mov     eax, sizeof.tracker
        imul    eax, [ebx + torrent.trackers_cnt]
        add     edi, eax
        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_LIST
        jz      @f
        cmp     eax, BT_BENCODE_END
        jz      .quit
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        stdcall torrent._.bdecode_readnum
        DEBUGF 2,' %s\n',esi:eax
        mov     [edi + tracker.announce_len], eax
        add     edi, tracker.announce
        mov     ecx, eax
        rep     movsb
        xor     eax, eax
        stosb
        inc     esi     ; 'e'
        inc     [ebx + torrent.trackers_cnt]
        jmp     .next
        
  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_skip_element
        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_LIST
        jz      .list
        cmp     eax, BT_BENCODE_DICT
        jz      .dict
        cmp     eax, BT_BENCODE_STR
        jz      .str
        cmp     eax, BT_BENCODE_INT
        jz      .int
        DEBUGF 3,'ERROR: bdecode_skip_element bad type\n'
        jmp     .error
  .list:
        cmp     byte[esi], 'e'
        jnz     @f
        inc     esi
        jmp     .quit
    @@:
        stdcall torrent._.bdecode_skip_element
        jmp     .list
  .dict:
        cmp     byte[esi], 'e'
        jnz     @f
        inc     esi
        jmp     .quit
    @@:
        stdcall torrent._.bdecode_skip_element
        jmp     .dict
  .str:
        stdcall torrent._.bdecode_readnum
        add     esi, eax
        jmp     .quit
  .int:
        stdcall torrent._.bdecode_readnum
        jmp     .quit

  .error:
  .quit:
        ret
endp


proc torrent._.bdecode_httpseeds _torrent, _arg
DEBUGF 2,'list\n'
        push    ebx edi

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_LIST
        jz      @f
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        mov     ebx, [_torrent]
        mov     [ebx + torrent.peers_cnt], 0
        mov     edx, [ebx + torrent.peers]
  .next:
        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_STR
        jz      @f
        cmp     eax, BT_BENCODE_END
        jz      .quit
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        xor     eax, eax
        mov     [edx + peer.am_interested], al
        mov     [edx + peer.is_interested], al
        inc     eax
        mov     [edx + peer.am_choking], al
        mov     [edx + peer.is_choking], al
        push    edx
        stdcall torrent._.bdecode_readnum
        pop     edx
        DEBUGF 2,' %s\n',esi:eax
        mov     byte[edx + peer.protocol], BT_PEER_PROTOCOL_HTTP
        lea     edi, [edx + peer.url]
        mov     ecx, eax
        rep     movsb
        inc     [ebx + torrent.peers_cnt]
        mov     byte[edi], 0
        add     edx, sizeof.peer
        jmp     .next
        
  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_info _torrent, _arg
locals
        info_begin      dd ?
        info_end        dd ?
        info_len        dd ?
        msglen          dd ?
        hex             rb 128
endl
DEBUGF 2,'dict\n'
        push    ebx edx edi
        mov     [info_begin], esi
        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_DICT
        jz      @f
        DEBUGF 3,'ERROR: bdecode_info bad type: not a dict\n'
        jmp     .error
    @@:
        stdcall torrent._.bdecode_dict, [_torrent], -1, [_arg]
        mov     [info_end], esi
        mov     eax, esi
        sub     eax, [info_begin]
        inc     eax
        mov     [info_len], eax

        mov     ebx, [_torrent]
        lea     edx, [ebx + torrent.info_hash]
        mov     [msglen], 0
        lea     ecx, [msglen]
        push    edx esi
        invoke  crash.hash, LIBCRASH_SHA1, edx, [info_begin], [info_len], callback, ecx
        pop     esi edx
        lea     eax, [hex]
        push    esi
	invoke	crash.bin2hex, edx, eax, LIBCRASH_SHA1
        pop     esi
        mov     ebx, [_torrent]
        lea     edx, [ebx + torrent.info_hash]
        lea     eax, [hex]
  .error:
  .quit:
        pop     edi edx ebx
        ret
endp


proc callback _left
        xor     eax, eax
        ret
endp


proc torrent._.bdecode_string _torrent, _arg
        stdcall torrent._.bdecode_readnum
        DEBUGF 2,'%s\n',esi:eax
        add     esi, eax
        ret
endp


proc torrent._.bdecode_info_name _torrent, _arg
        push    ebx edi

        mov     ebx, [_torrent]

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_STR
        jz      @f
        DEBUGF 2,'ERROR: bad type\n'
        jmp     .error
    @@:
        stdcall torrent._.bdecode_readnum
        DEBUGF 2,'%s\n',esi:eax
        cmp     [ebx + torrent.files_cnt], 1
        jnz     @f
        mov     edi, [ebx + torrent.files]
        add     edi, 4
        jmp     .common
    @@:
        lea     edi, [ebx + torrent.name]
  .common:
        mov     ecx, eax
        rep     movsb
        mov     byte[edi], 0
        jmp     .quit
        
  .error:
  .quit:
        pop     edi ebx
        ret


        ret
endp


proc torrent._.bdecode_info_piece_length _torrent, _arg
        push    ebx edi

        mov     ebx, [_torrent]

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_INT
        jz      @f
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        stdcall torrent._.bdecode_readnum
        DEBUGF 2,'%u\n',eax
        mov     [ebx + torrent.piece_length], eax
        jmp     .quit
        
  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_info_length _torrent, _arg
        push    ebx edi

        mov     ebx, [_torrent]
        mov     [ebx + torrent.files_cnt], 1
        invoke  mem.alloc, (0x1000 * 1)
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: bdecode_info_length alloc\n'
        jmp     .error
    @@:
        mov     [ebx + torrent.files], eax
        mov     edi, eax
        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_INT
        jz      @f
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        
        stdcall torrent._.bdecode_readnum
        DEBUGF 2,'%d\n',eax
        stosd
        mov     [ebx + torrent.left], eax
        jmp     .quit
        
  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_info_pieces _torrent, _arg
DEBUGF 2,'list\n'
        push    ebx edi

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_STR
        jz      @f
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@: 
        ;stores count of pieces
        mov     ebx, [_torrent]
        stdcall torrent._.bdecode_readnum
        xor     edx, edx
        mov     edi, 20
        div     edi
        mov     [ebx + torrent.pieces_cnt], eax
        
        ;allocates memory : (pieces_cnt*sizeof.piece)
        xor     edx, edx
        mov     ecx, sizeof.piece 
        mul     ecx
        push    ecx
        invoke  mem.alloc, eax
        pop     ecx
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: bdecode_pieces alloc\n'
        jmp     .error

    @@:
        ;fills piece structure
        mov     [ebx + torrent.pieces], eax
        stdcall piece._.fill_all_pieces, [_torrent], eax

        ;print first piece
        DEBUGF 2, "First Piece\n"
        mov     eax, [ebx + torrent.pieces]
        DEBUGF 2, "Index : %d\n", [eax+piece.index]
        DEBUGF 2, "Hash : %d\n", [eax+piece.piece_hash]
        DEBUGF 2, "Download Status : %d\n", [eax+piece.download_status]
        DEBUGF 2, "Blocks downloaded : %d\n", [eax+piece.num_blocks_downloaded]
        DEBUGF 2, "Number of offsets : %d\n", [eax+piece.num_offsets]
        DEBUGF 2, "Piece Offset : %d\n", [eax+piece.piece_offset]
        DEBUGF 2, "Length : %d\n", [eax+piece.length]
        DEBUGF 2, "File Offset : %d\n", [eax+piece.file_offset]
        DEBUGF 2, "File Index : %d\n", [eax+piece.file_index]
        
        ;print last piece
        DEBUGF 2, "Last Piece\n"
        mov    ecx, [ebx+torrent.pieces_cnt]
        dec    ecx
        imul   ecx, sizeof.piece
        add    eax, ecx
        DEBUGF 2, "Index : %d\n", [eax+piece.index]
        DEBUGF 2, "Hash : %d\n", [eax+piece.piece_hash]
        DEBUGF 2, "Download Status : %d\n", [eax+piece.download_status]
        DEBUGF 2, "Blocks downloaded : %d\n", [eax+piece.num_blocks_downloaded]
        DEBUGF 2, "Number of offsets : %d\n", [eax+piece.num_offsets]
        DEBUGF 2, "Piece Offset : %d\n", [eax+piece.piece_offset]
        DEBUGF 2, "Length : %d\n", [eax+piece.length]
        DEBUGF 2, "File Offset : %d\n", [eax+piece.file_offset]
        DEBUGF 2, "File Index : %d\n", [eax+piece.file_index]

        ;stdcall piece._.set_piece, [_torrent], 1, 

        jmp     .quit

  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_info_files _torrent, _arg
DEBUGF 2,'list\n'
        push    ebx edi

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_LIST
        jz      @f
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        mov     ebx, [_torrent]
        invoke  mem.alloc, (0x1000 * 1000)
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: bdecode_info_files alloc\n'
        jmp     .error
    @@:
        mov     [ebx + torrent.files], eax
        mov     [ebx + torrent.files_cnt], 0
  .next:
        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_DICT
        jz      @f
        cmp     eax, BT_BENCODE_END
        jz      .quit
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        stdcall torrent._.bdecode_dict, [_torrent], -1, [_arg]
        inc     esi
        jmp     .next
        
  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_info_files_length _torrent, _arg
        push    ebx edi

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_INT
        jz      @f
        DEBUGF 3,'ERROR: bad type\n'
        jmp     .error
    @@:
        mov     ebx, [_torrent]
        stdcall torrent._.bdecode_readnum
        mov     edi, [ebx + torrent.files_cnt]
        imul    edi, 0x1000
        add     edi, [ebx + torrent.files]
        stosd
        add     [ebx + torrent.left], eax
        DEBUGF 2,'%d\n',eax

  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_info_files_path _torrent, _arg
        push    ebx edi

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_LIST
        jz      @f
        DEBUGF 3,'ERROR: bad type not a list\n'
        jmp     .error
    @@:
        mov     ebx, [_torrent]
        mov     edi, [ebx + torrent.files_cnt]
        imul    edi, 0x1000
        add     edi, 4
        add     edi, [ebx + torrent.files]
  .next:
        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_STR
        jz      @f
        cmp     eax, BT_BENCODE_END
        jz      .quit
        DEBUGF 3,'ERROR: bad type not a string\n'
        jmp     .error
    @@:
        stdcall torrent._.bdecode_readnum
        mov     ecx, eax
        rep     movsb
        mov     al, '/'
        stosb
        jmp     .next

  .error:
  .quit:
        mov     byte[edi-1], 0
        mov     edi, [ebx + torrent.files_cnt]
        imul    edi, 0x1000
        add     edi, 4
        add     edi, [ebx + torrent.files]
        DEBUGF 2,'%s\n',edi
        inc     [ebx + torrent.files_cnt]
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_tracker_interval _torrent, _arg
        push    ebx edi

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_INT
        jz      @f
        DEBUGF 3,'ERROR: bad type not an int\n'
        jmp     .error
    @@:
        mov     ebx, [_torrent]
        mov     edx, [ebx + torrent.trackers]
        stdcall torrent._.bdecode_readnum
        mov     [edx + tracker.interval], eax
        DEBUGF 2,'%d\n',eax

  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_tracker_min_interval _torrent, _arg
        push    ebx edi

        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_INT
        jz      @f
        DEBUGF 3,'ERROR: bad type not an int\n'
        jmp     .error
    @@:
        mov     ebx, [_torrent]
        mov     edx, [ebx + torrent.trackers]
        stdcall torrent._.bdecode_readnum
        mov     [edx + tracker.min_interval], eax
        DEBUGF 2,'%d\n',eax

  .error:
  .quit:
        pop     edi ebx
        ret
endp


proc torrent._.bdecode_tracker_peers _torrent, _arg
        push    ebx edi

        mov     ebx, [_torrent]
        stdcall torrent._.bdecode_get_type
        cmp     eax, BT_BENCODE_LIST
        jz      .nocompact
        cmp     eax, BT_BENCODE_STR
        jz      .compact
        DEBUGF 3,'ERROR: bad type not a list or string\n'
        jmp     .error
  .nocompact:
        DEBUGF 2,'nocompact\n'
        DEBUGF 3,'ERROR: nocompact is not implemented\n'
        jmp     .error
  .compact:
        DEBUGF 2,'compact\n'
        mov     edi, [ebx + torrent.peers]
        mov     eax, [ebx + torrent.peers_cnt]
        imul    eax, sizeof.peer
        add     edi, eax
        stdcall torrent._.bdecode_readnum
        xor     edx, edx
        mov     ecx, 6          ; ipv4 + port
        div     ecx
        test    edx, edx
        jnz     .error
        add     [ebx + torrent.peers_cnt], eax
        mov     ecx, eax
  .next_peer:
        jecxz   .quit
        xor     eax, eax
        mov     [edi + peer.am_interested], al
        mov     [edi + peer.is_interested], al
        inc     eax
        mov     [edi + peer.am_choking], al
        mov     [edi + peer.is_choking], al
        lodsd
        ;bswap   eax
        mov     [edi + peer.ipv4], eax
        xor     eax, eax
        lodsw
        xchg    al, ah
        mov     [edi + peer.port], eax
        add     edi, sizeof.peer
        dec     ecx
        jmp     .next_peer
  .error:
        DEBUGF 3,'ERROR: bdecode_tracker_peers\n'
  .quit:
        DEBUGF 3,'bdecode_tracker_peers done: %d\n',[ebx + torrent.peers_cnt]
        pop     edi ebx
        ret
endp


known_keys_0:
db 8, 'announce'
dd torrent._.bdecode_announce, 0
db 13, 'announce-list'
dd torrent._.bdecode_announce_list, 0
db 7, 'comment'
dd torrent._.bdecode_string, 0
db 9, 'httpseeds'
dd torrent._.bdecode_httpseeds, 0
db 4, 'info'
dd torrent._.bdecode_info, known_keys_info
db 0

known_keys_info:
db 5, 'files'
dd torrent._.bdecode_info_files, known_keys_files
db 6, 'length'
dd torrent._.bdecode_info_length, 0
db 4, 'name'
dd torrent._.bdecode_info_name, 0
db 12, 'piece length'
dd torrent._.bdecode_info_piece_length, 0
db 6, 'pieces'
dd torrent._.bdecode_info_pieces, 0
db 0

known_keys_files:
db 6, 'length'
dd torrent._.bdecode_info_files_length, 0
db 4, 'path'
dd torrent._.bdecode_info_files_path, 0
db 0


keys_tracker_response0:
db 8, 'interval'
dd torrent._.bdecode_tracker_interval, 0
db 12, 'min interval'
dd torrent._.bdecode_tracker_min_interval, 0
db 5, 'peers'
dd torrent._.bdecode_tracker_peers, keys_tracker_response_peers
db 0

keys_tracker_response_peers:
db 0



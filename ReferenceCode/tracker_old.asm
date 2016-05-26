proc torrent._.tracker_get _torrent, _tracker
        
        push    ebx

        DEBUGF 2, "INFO: In torrent._.tracker_get\n"
        
        mov     ebx, [_tracker]
        mov     eax, [ebx + tracker.protocol]
  .next_protocol:
        stdcall [tracker_get_by_protocol + eax*4], [_torrent], [_tracker]
        test    eax, eax
        jz      .success
        cmp     eax, BT_TRACKER_ERROR_NOT_SUPPORTED
        jnz     .error
DEBUGF 2,'protocol %d is not supported by tracker\n',[ebx + tracker.protocol]
        dec     [ebx + tracker.protocol]
        jnc     .next_protocol
        jmp     .error
  .success:
  .error:
        pop     ebx
        ret
endp


proc tracker._.get_tcp _torrent, _tracker
locals
        identifier      dd ?
endl
        push    ebx esi edi

        mov     ebx, [_tracker]
        stdcall torrent._.tracker_fill_params, [_torrent], [_tracker]

        lea     edi, [ebx + tracker.announce]
        lea     eax, [ebx + tracker.params]
;DEBUGF 2,'url: %s\n',edi
;DEBUGF 2,'params: %s\n',eax
        invoke  http.get, edi, 0, 0, 0
        test    eax, eax
        jz      .error
        mov     [identifier], eax

    @@:
        invoke  http.receive, [identifier]
        test    eax, eax
        jnz     @b

        mov     ebx, [identifier]
        mov     eax, [ebx + http_msg.content_received]
        mov     [final_size], eax
        mov     ebx, [ebx + http_msg.content_ptr]
        mov     [final_buffer], ebx
;        mcall   70, fileinfo


        mov     esi, [final_buffer]
        mov     eax, esi
        inc     esi
        add     eax, [final_size]
        stdcall torrent._.bdecode_dict, [_torrent], eax, keys_tracker_response0


        invoke  http.free, [identifier]
        jmp     .quit

  .error:
        DEBUGF 3,'ERROR: %d\n',eax
  .quit:
        xor     eax, eax
        pop     edi esi ebx
        ret
endp


proc tracker._.get_udp _torrent, _tracker
        mov     eax, BT_TRACKER_ERROR_NOT_SUPPORTED
        ret
endp


tracker_get_by_protocol dd tracker._.get_tcp, tracker._.get_udp



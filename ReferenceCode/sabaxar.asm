use32
    org 0x0
    db  'MENUET02'
    dd  0x01,start,i_end,e_end,e_end,0,0,0

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1

include '../../../struct.inc'
include '../../../proc32.inc'
include '../../../macros.inc'
include '../../../config.inc'
include '../../../network.inc'
include '../../../debug-fdo.inc'
include '../../../dll.inc'

include 'torrent.inc'

MAX_TORRENTS = 1024

struct sabaxar_state
        torrents_cnt  dd ?
        torrents      dd ?
        peers_cnt     dd ?
        max_peers_cnt dd ?
        uploaded      dd ?
        downloaded    dd ?
        peer_id       rb 20
        port_in       dd ?
ends


start:
	mcall	68, 11          ; heap
        mcall   40, 1 SHL 7
        mcall   60, 1, ipc_buf, sizeof.ipc_buffer
        mcall   9, proc_info, -1

	stdcall dll.Load, @IMPORT
	or	eax, eax
        jz      .libs_ok
        DEBUGF 3,'ERROR: load libraries\n'
	jmp	.error
  .libs_ok:

        ;stdcall sabaxar.read_config, [config_file], state
        ;stdcall sabaxar.load_state, state

        stdcall sabaxar.add_torrent, BT_NEW_FILE, torrent_filename1
;        stdcall sabaxar.add_torrent, BT_NEW_FILE, torrent_filename2
;        stdcall sabaxar.add_torrent, BT_NEW_FILE, torrent_filename3

        xor     ecx, ecx
        mov     esi, [state.torrents]
  .start_next_torrent:
        cmp     ecx, [state.torrents_cnt]
        jz      .all_started
        mov     edi, [esi + ecx*4]
        push    ecx
        invoke  torrent.start, edi
        pop     ecx
        test    eax, eax
        jnz     .start_ok
        DEBUGF 3,'ERROR: Cannot start torrent\n'
        jmp     .error
  .start_ok:
        mov     [edi + torrent.pid], eax
        inc     ecx
        jmp     .start_next_torrent
  .all_started:

  .still:
DEBUGF 2,'WAIT_FOR_IPC_MSG\n'
        mcall   10
DEBUGF 2,'GOT_IPC_MSG\n'
        mov     ebx, ipc_buf.messages
        mov     [ipc_buf.locked], 1

  .next_msg:
DEBUGF 2,'NEXT_MSG\n'
        stdcall torrent._.parent_ipc_handler, ebx
        mov     eax, [ebx + ipc_message.length]
        add     ebx, eax
        mov     eax, ipc_buf
        add     eax, [ipc_buf.occupied]
        add     eax, 8
        cmp     ebx, eax
        jb      .next_msg
        mov     [ipc_buf.occupied], 0
        mov     [ipc_buf.locked], 0
        jmp     .still

  .error:
  .quit:
        mcall   -1


proc torrent._.parent_ipc_handler _msg
        push    ebx esi edi

        mov     ebx, [_msg]
DEBUGF 2,'Sabaxar got IPC from PID_%u, length=%u\n',[ebx + ipc_message.pid],[ebx + ipc_message.length]
        mov     eax, ipc_buf
DEBUGF 2,'ipc: %x %x %x %x %x %x %x %x %x %x\n',[eax],[eax+4],[eax+8],[eax+12],[eax+16],[eax+20],[eax+24],[eax+28],[eax+32],[eax+36]
        lea     edx, [ebx + ipc_message.bytes]
        mov     edx, [edx]
DEBUGF 2,'For torrent at %x stub is %d\n',edx,[edx + torrent.stub]

  .error:
  .quit:
        pop     edi esi ebx
        ret
endp


proc sabaxar.add_torrent _bt_new_type, _src
        push    ebx esi edi

        invoke  torrent.new, [_bt_new_type], [_src]
        test    eax, eax
        jnz     @f
        DEBUGF 3,'ERROR: Failed to add new torrent\n'
	jmp	.error
    @@:
        mov     [eax + torrent.stub], 0
        mov     ecx, [proc_info.PID]
        mov     [eax + torrent.parent_pid], ecx
        mov     edx, [state.torrents]
        mov     ecx, [state.torrents_cnt]
        mov     [edx + ecx*4], eax
        inc     [state.torrents_cnt]

  .error:
  .quit:
        pop     edi esi ebx
        ret
endp
proc sabaxar.load_state _state
        push    ebx esi edi

        mov     ebx, [_state]

        stdcall mem.Alloc, MAX_TORRENTS*4
        test    eax, eax
        jnz     .alloc_ok
        DEBUGF 3,'ERROR: not enough memory for torrents table\n'
        jmp     .error
  .alloc_ok:
        mov     [ebx + state.torrents], eax

  .error:
  .quit:
        pop     edi esi ebx
        ret
endp


proc sabaxar.read_config _config, _state
        push    ebx esi edi

        mov     ebx, [_state]
        mov     [ebx + state.port_in], 50001
        mov     [ebx + state.downloaded], 0
        mov     [ebx + state.uploaded], 0
        mov     [ebx + state.max_peers_cnt], 200

        pop     edi esi ebx
        ret
endp


align 4
@IMPORT:

library				\
	torrent, 'torrent.obj', \
        libini,  'libini.obj' , \
        libio,   'libio.obj'

import	torrent		   , \
	lib_init           , 'lib_init'   , \
	torrent.tracker_get, 'tracker_get', \
        torrent.start      , 'start'      , \
        torrent.stop       , 'stop'       , \
        torrent.new        , 'new'        , \
	torrent.bdecode    , 'bdecode'

import libini                               , \
        ini.get_shortcut, 'ini_get_shortcut'

import libio                    , \
        libio.init, 'lib_init'  , \
        file.size , 'file_size' , \
        file.open , 'file_open' , \
        file.read , 'file_read' , \
        file.close, 'file_close'

include_debug_strings

config_file dd defconfig
defconfig   db '/hd0/1/sabaxar.ini',0
state_file  dd defstate
defstate    db '/hd0/1/sabaxar.sta',0
peer_id     db '-SX0001-testtesttest'     ; SX for SabaXar
torrent_filename1 db '/udbhd0/1/debian_8.0.0_amd64_netinst.iso.torrent',0
torrent_filename2 db '/usbhd0/1/ubuntu-15.04-desktop-amd64.iso.torrent',0
torrent_filename3 db '/usbhd0/1/archlinux-2015.08.01-dual.iso.torrent',0
state        sabaxar_state
proc_info    process_information
ipc_buf      ipc_buffer
ipc_msg      ipc_message

i_end:

        rb 0x1000       ; stack
e_end:

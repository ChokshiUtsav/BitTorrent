TORRENT_STACK_SIZE = 0x1000

MAX_PEERS_PER_TORRENT = 50
MAX_PEERS_TOTAL = 200

BT_TRACKER_PROTOCOL_TCP  = 0    ; bep_0003: The BitTorrent Protocol Specification
BT_TRACKER_PROTOCOL_UDP  = 1    ; bep_0015: UDP Tracker Protocol for BitTorrent
BT_TRACKER_PROTOCOL_LAST = 1

BT_TRACKER_ERROR_NOT_SUPPORTED = 1

BT_PEER_PROTOCOL_TCP  = 0       ; bep_0003: The BitTorrent Protocol Specification
BT_PEER_PROTOCOL_uTP  = 1       ; bep_0029: uTorrent transport protocol
BT_PEER_PROTOCOL_HTTP = 2       ; bep_0017: HTTP Seeding
BT_PEER_PROTOCOL_LAST = 2

BT_PEER_MSG_CHOKE          = 0
BT_PEER_MSG_UNCHOKE        = 1
BT_PEER_MSG_INTERESTED     = 2
BT_PEER_MSG_NOT_INTERESTED = 3
BT_PEER_MSG_HAVE           = 4
BT_PEER_MSG_BITFIELD       = 5
BT_PEER_MSG_REQUEST        = 6
BT_PEER_MSG_PIECE          = 7
BT_PEER_MSG_CANCEL         = 8
BT_PEER_MSG_EXTENDED       = 20

BT_NEW_FILE   = 0
BT_NEW_MAGNET = 1

BT_BENCODE_DICT = 0
BT_BENCODE_LIST = 1
BT_BENCODE_INT  = 2
BT_BENCODE_STR  = 3
BT_BENCODE_END  = 4

BT_PEER_STATE_UNKNOWN      = 0
BT_PEER_STATE_OFFLINE      = 1
BT_PEER_STATE_DISCONNECTED = 2
BT_PEER_STATE_CONNECTED    = 3

struct ipc_buffer
        locked   dd ?
        occupied dd ?
        messages rb 0x1000 - 8
ends

struct ipc_message
        pid    dd ?
        length dd ?
        bytes  rb 4
ends

struct tracker
        announce_len    dd ?
        announce        rb 1024
        params          rb 1024
        protocol        dd ?
        interval        dd ?
        min_interval    dd ?
ends

struct peer
        ipv4            dd ?
        ipv6            rb 16
        port            dd ?
        peer_id_present dd ?
        peer_id         rb 20
        url             rb 256
        am_choking      db ?
        am_interested   db ?
        is_choking      db ?
        is_interested   db ?
        protocol        db ?
        last_seen       dd ?
        bit_field       dd ?
ends

struct torrent
        trackers_cnt    dd ?
        trackers        dd ?    ; array
        peers_cnt       dd ?
        peers           dd ?
        pieces_cnt      dd ?
        pieces          dd ?
        piece_length    dd ?
        files_cnt       dd ?
        files           dd ?
        info            dd ?
        info_hash       rb 20   ; sha1 length
        peer_id         rb 20
        port            dd ?
        name            rb 256  ; utf-8
        uploaded        dd ?
        downloaded      dd ?
        left            dd ?
        pid             dd ?
        parent_pid      dd ?
        stack           dd ?
        stub            dd ?
        ipc_buf         dd ?
        ipc_msg         ipc_message
        proc_info       process_information
ends

struct bit_field
        size            dd ?
        bytes           rb 1024
ends
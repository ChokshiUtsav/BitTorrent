TORRENT_STACK_SIZE = 0x1000

MAX_PEERS_PER_TORRENT = 50
MAX_PEERS_TOTAL       = 200
NUM_PIECES_IN_MEM     = 10

RECV_TIMEOUT       = 1          ;in seconds
PEER_TIMEOUT       = 1800       ;in seconds
KEEPALIVE_TIME     = 7200       ;in seconds = 2 mins
TRACKER_TIMEOUT    = 1800       ;in seconds = 30 mins

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

BT_PIECE_DOWNLOAD_NOT_STARTED = 0
BT_PIECE_DOWNLOAD_IN_PROGRESS = 1
BT_PIECE_DOWNLOAD_COMPLETE    = 2

MEM_LOCATION_EMPTY = 0          ;location is empty
MEM_LOCATION_IN_USE = 1         ;either upload/download is in progress
MEM_LOCATION_FILLED = 2         ;piece is downloaded and not being uploaded

HANDSHAKE_MSGLEN = 68
NOPAYLOAD_MSGLEN = 5
REQUEST_MSGLEN   = 17
BUFFERSIZE       = 4096
BLOCKLENGTH      = 16384        ;2^14 : standard block size

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
        url             rb 256
        am_choking      db ?
        am_interested   db ?
        is_choking      db ?
        is_interested   db ?
        protocol        db ?
        peer_id_present dd ?
        peer_id         rb 20
        sock_num        dd ?     ;socket number for communication
        last_seen       dd ?
        cur_piece       dd ?     ;index of piece being downloaded by peer
        cur_block       dd ?     ;index of block(within piece) being downloaded by peer
        piece_location  dd ?     ;location of cur_piece within piece_mem
        bitfield        rb 1024
ends

;Requires approximately 2kB
struct piece
        index                   dd ?                    
        piece_hash              rb 20                   
        download_status         dd ?                    
        num_blocks_downloaded   dd ?                    
        num_offsets             dd ? ;array_size        
        piece_offset            rb 0x0200  ;array       
        length                  rb 0x0200  ;array
        file_offset             rb 0x0200  ;array
        file_index              rb 0x0200  ;array
ends

struct torrent
        trackers_cnt     dd ?
        trackers         dd ?    ; array
        peers_cnt        dd ?
        peers            dd ?
        pieces_cnt       dd ?
        pieces           dd ?    ;array
        piece_length     dd ?
        num_blocks       dd ?    ;piece_length/BLOCKLENGTH
        files_cnt        dd ?
        files            dd ?    ;array
        info             dd ?
        info_hash        rb 20   ;sha1 length
        peer_id          rb 20
        port             dd ?
        name             rb 256  ; utf-8
        uploaded         dd ?
        downloaded       dd ?
        left             dd ?
        piece_mem_status rb NUM_PIECES_IN_MEM*5    ;array of status of pieces kept in memory
        piece_mem        dd ?    ;array of pieces kept in memory [each element = piece size]
        bitfield         rb 1024
        pid              dd ?
        parent_pid       dd ?
        stack            dd ?
        stub             dd ?
        ipc_buf          dd ?
        ipc_msg          ipc_message
        proc_info        process_information
ends
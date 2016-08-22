#About file
Following are point of changes which may require code changes.

##Point of changes
### (1) Verification of peer-id:
Currently, peer_id from hanshake message is not verified with the one sent by tracker server as some tracker responses does not contain peer ids (because of reasons of annonymity).

So current implementation of code simply copies peer-id sent by peer. Though check is added using parameter peer.peer_id_present but it is redundant.

Location of change : message.asm -> message._.ver_handshake_msg

### (2) Handling large files
Currently, file-size is stored in double word registers. So maximum file-size that can be handled is 2^32 = 4GB. 

Location of change : piece.asm -> file-size variables
					 torrent.inc -> peer struct

### (3) Identifying seeders and leechers
Currently, there is no member variable/field in peer struct that informs that whether peer is seeder or leecher.
Seeder  : Peer having all pieces.
Leecher : Peer, not having, all pieces.

For identifying seeder, bitfield of peer can be checked. If it contains all 1s then it is seeder.

Location of change : torrent.inc  -> peer struct
                     peer.asm     -> peer._.communicate 
                     bitfiled.asm -> bitfield._.is_seeder (**yet to implement)
					 

### (4) Is Backend (Background program) running?
Currently, Frontend does not verify whether Bittorrent_backend is running ?

Location of change : bittorrent_frontend.asm -> before welcome message.

### (5) Check for duplicate torrents
Currently, there is no check made for duplicate torrents. So same torrent can be added again.

For identifying duplicate torrents, we can compare info_hash of torrents.
If they are same, do not add new torrent.

Location of change : bittorrent_backend_actions.asm -> backend_actions.torrent_add 


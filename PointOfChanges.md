#About file
Following are point of changes which may require code changes in near/far future.
Pattern follows -> Filename : Procedure : LineNumber : Description

##Point of changes
1) Peer.asm : peer._.handshake _torrent : 28-30
   Currently, Plain [i.e. without any extension] version of bit torrent protocol is followed. If some extensions are included then 8 consecutive zeros may be changed by extension number.
2) Peer.asm : peer._.handshake _torrent : 97
   Currently, peer_id from hanshake message is not verified with the one sent by tracker server as some trackeer responses does not contain peer ids (because of reasons annonymity). So current version of code simply copies peer-id sent by peer.


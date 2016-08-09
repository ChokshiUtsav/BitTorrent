#About file
Following are point of changes which may require code changes.

##Point of changes
### (1) Verification of peer-id:
Currently, peer_id from hanshake message is not verified with the one sent by tracker server as some tracker responses does not contain peer ids (because of reasons of annonymity).

So current implementation of code simply copies peer-id sent by peer. Though check is added using parameter peer.peer_id_present but it is redundant.

Location of change : message.asm -> message._.ver_handshake_msg

### (2) Handling large files
Currently, file-size is stored in double word registers. So maximum file-size that can be handled is 2^32 = 4GB. 

Location of change : piece.asm

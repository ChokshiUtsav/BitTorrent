#About file
This file explains which of features have not been implemented yet.

##Unsupported Features :
### (1) uTP (uTorrent Protocol)
An alternative to TCP protocol for communication between peers.
[Read more about it here](http://bittorrent.org/beps/bep_0029.html)
Why ? It requires , writing protocol from scratch (i.e. desigining packet format).

### (2) Magnet links
An alternate to download a torrent without even downloading torrent file
[Read more about it here](http://stackoverflow.com/questions/3844502/how-do-bittorrent-magnet-links-work)
Why ? Every torrent that has magnet link , also has .torrent file. So this is an add-on and not neccessary feature.

### (3) UDP based trackers
Requires communication to be haapended with tracker using UDP protocol.
Why ?  Yet to figure out format of UDP request and response.

### (4) Extensions of  Bittorrent Protocol
This point is more fact rather than unsupported feature.

Currently, Plain [i.e. without any extension] version of bit torrent protocol is followed.

So while exchanging handshake message, 8 bytes for protocol extension is kept all zeros (00000000).

Why? Extended bittorent protocol requires to implement some extended features which has not been implemented. 

### (5) Distributed Hash Table (DHT)
This feature allows tracking of peers downloading without the use of standard tracker.

[Read more about it here](https://wiki.theory.org/BitTorrentSpecification#Distributed_Hash_Table)

Why? Implementation of this feature requires heavy changes in over-all design. 

### (6) Tracker scrape convention
Tracker scrape URL is another fancy way of getting details from tracker. 

[Read more about it here](https://wiki.theory.org/BitTorrentSpecification#Tracker_.27scrape.27_Convention)

Why ? Every tracker server that has scrape URL, also has, announce URL. So this is an add-on and not neccessary feature.  
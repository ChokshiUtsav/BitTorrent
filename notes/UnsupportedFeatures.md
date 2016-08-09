#About file
This file explains which of features have not been implemented yet.

##Unsupported Features :
### (1) uTP (uTorrent Protocol)
An alternative to TCP protocol for communication between peers.
Why ? It requires , writing protocol from scratch (i.e. desigining packet format).
[Read more about it here](http://bittorrent.org/beps/bep_0029.html)

### (2) Magnet links
An alternate to download a torrent without even downloading torrent file
Why ? Every torrent that has magnet link , also has .torrent file. So this is an add-on and not neccessary feature.
[Read more about it here](http://stackoverflow.com/questions/3844502/how-do-bittorrent-magnet-links-work)

### (3) UDP based trackers
Requires communication to be haapended with tracker using UDP protocol
Why ?  Yet to figure out format of UDP request and response.


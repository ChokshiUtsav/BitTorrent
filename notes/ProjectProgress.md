#About file
This file contains list of tasks done and not done during 3 months of GSoC Project.

##List-of-tasks-done
(1) Decoding becoded torrent file and extracting meta-info from file. [week 1](https://github.com/ChokshiUtsav/BitTorrent/blob/master/bencode.asm)
(2) Generating HTTP Request for tracker server and Parsing HTTP response. 
    Integrating SHA1 hash. [week 2 & 3](https://github.com/ChokshiUtsav/BitTorrent/blob/master/tracker.asm)
(3) Establishing connection with one of peers using hanshake message [week 4](https://github.com/ChokshiUtsav/BitTorrent/blob/master/peer.asm)
(4) Identifying different kind of torrent messages and filtering out Bitfiled and Have kind of messages and sending interested message. [week 5](https://github.com/ChokshiUtsav/BitTorrent/blob/master/message.asm)
(5) Generating request messages for asking pieces from the other peers. [week 6](https://github.com/ChokshiUtsav/BitTorrent/blob/master/peer.asm)
(6) Writing files from memory to disk and handling pieces in memory. [week 9](https://github.com/ChokshiUtsav/BitTorrent/blob/master/piece.asm)
(7) Connecting with multiple peers for downloading and maintaining download statstics [week 10](https://github.com/ChokshiUtsav/BitTorrent/blob/master/torrent.asm)
(8) I have designed GUI and started working on it. But as torrent's core functionality was remaining, I left it. [not mentioned in milestones](https://github.com/ChokshiUtsav/BitTorrent/blob/master/bittorrent_frontend.asm)
(9) I designed command line based GUI as an alternate. It supports only 3 commands : download_torrent(to start download), show_all_torrent (to check all torrents), show_torrent (to chek progress of particular torrent) [not mentioned in milestones](https://github.com/ChokshiUtsav/BitTorrent/blob/master/bittorrent_frontend_new.asm)
(10) Preparing document of code developed [week 12](chokshiutsav.github.io/BitTorrent)

##List-of-tasks-not-done
(1) Accepting connection from interested peers and uploading pieces to them and sending different torrent messages to them [week 7 and 8]
(2) Implementing torrent application that can use torrent library correctly.
    It involves , connecting backend & frontend and handling multiple torrents simultaneously using threading.
(3) Testing application as whole and preparing robust torrent library [week 11]
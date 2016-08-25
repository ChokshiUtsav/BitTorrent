QEMU=qemu-system-i386
KOLIBRI_IMG_PATH=.
HDA_PATH=.

all: torrent.obj bittorrent_backend bittorrent_frontend_new

torrent.obj : torrent.asm torrent.inc tracker.asm peer.asm bencode.asm percent.asm
	fasm $< $@

bittorrent_backend: bittorrent_backend.asm torrent.inc torrent_errors.inc
	fasm $< $@

bittorrent_frontend_new: bittorrent_frontend_new.asm
	fasm $< $@

run : clean all
	mcopy -vmoi $(KOLIBRI_IMG_PATH)/kolibri.img torrent.obj ::lib/torrent.obj
	$(QEMU) -L . -m 4096 -fda $(KOLIBRI_IMG_PATH)/kolibri.img -boot a -vga vmware -net nic,model=rtl8139 -net user -soundhw ac97 -usb -usbdevice disk:format=raw:fat:rw:$(HDA_PATH) -usbdevice tablet

clean :
	rm -f torrent.obj bittorrent_frontend_new bittorrent_backend bittorrent_backend_new

qemu_run:
	$(QEMU) -L . -m 1024 -fda $(KOLIBRI_IMG_PATH)/kolibri.img -boot a -vga vmware -net nic,model=rtl8139 -net user -soundhw ac97 -usb -usbdevice disk:format=raw:/dev/sda -usbdevice tablet


QEMU=qemu-system-i386
KOLIBRI_IMG_PATH=.
HDA_PATH=.

all: torrent.obj sample

torrent.obj : torrent.asm torrent.inc tracker.asm peer.asm bencode.asm percent.asm
	fasm $< $@

sample: sample.asm torrent.inc
	fasm $< $@

run : clean all
	mcopy -vmoi $(KOLIBRI_IMG_PATH)/kolibri.img torrent.obj ::lib/torrent.obj
	$(QEMU) -L . -m 128 -fda $(KOLIBRI_IMG_PATH)/kolibri.img -boot a -vga vmware -net nic,model=rtl8139 -net user -soundhw ac97 -usb -usbdevice disk:format=raw:fat:$(HDA_PATH) -usbdevice tablet

clean :
	rm -f torrent.obj sample

qemu_run:
	$(QEMU) -L . -m 128 -fda $(KOLIBRI_IMG_PATH)/kolibri.img -boot a -vga vmware -net nic,model=rtl8139 -net user -soundhw ac97 -usb -usbdevice disk:format=raw:fat:$(HDA_PATH) -usbdevice tablet	


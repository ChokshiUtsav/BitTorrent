format binary as ""

use32
        org     0x0
        db      'MENUET01'      ; signature
        dd      0x01            ; header version
        dd      START           ; entry point
        dd      I_END           ; initialized size
        dd      E_END   		; required memory
        dd      E_END		    ; stack pointer
        dd      0		        ; parameters
        dd      0               ; path

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1


include '../../../proc32.inc'
include '../../../macros.inc'
purge mov,add,sub
include '../../../struct.inc'
include '../../../dll.inc'
include '../../../libio.inc'
include '../../../debug-fdo.inc'

START:
	;init heap
    mcall   68, 11
    test    eax, eax
    jz      .exit

	;load libraries
    stdcall dll.Load, @IMPORT
    test    eax, eax
    jnz     .exit

    ;Get the file size
    DEBUGF 2, "PROGRESS : Getting file size\n"
    invoke  file.size, filename
    cmp     ebx, -1
    jnz     @f
    DEBUGF 3,'ERROR: file.size\n'
    jmp     .error

 @@:
 	mov [filesize], ebx
    DEBUGF 2, "PROGRESS : Allocating memory for file size\n"
    stdcall  mem.Alloc, [filesize]
    test    eax, eax
    jnz     @f
    DEBUGF 3,'ERROR: mem.alloc\n'
    jmp      .error  

 @@:   
    mov     [filebuf], eax   
    ;open file for reading
    invoke file.open, filename, O_READ
    or eax, eax
    jz .error1

    ;saving file descriptor
    mov [fdesc], eax

    ;read all bytes of file
    invoke file.read, eax, [filebuf], [filesize]
    mov [bytes_read], eax
    inc eax
    jz .close1

    ;open file for writing
    invoke file.open, filename_2, O_WRITE
    or eax, eax
    jz .error1

    ;saving file descriptor
    mov [fdesc2], eax

    ;set file pointer to offset 0(SEEK_SET)
    invoke file.seek, [fdesc2], 0, SEEK_SET
    inc eax
    jz .close2

    ;writing all bytes to file
    invoke file.write, [fdesc2], [filebuf], [bytes_read]
    jmp .close2

.close1:
	invoke 	file.close, [fdesc]
	inc eax
	jnz .error2
	DEBUGF 1,'SUCCESS: Closing a file 1\n'
	jmp .exit

.close2:
	invoke 	file.close, [fdesc]
	inc eax
	jnz .error2
	DEBUGF 1,'SUCCESS: Closing a file 2\n'
	jmp .exit	

.error1:
	DEBUGF 2,'ERROR: Problem opening a file\n'
	jmp .exit

.error2:
	DEBUGF 2,'ERROR: Problem closing a file\n'
	jmp .exit

.error:
	DEBUGF 2, 'ERROR : Program ended with error\n'
  	jmp .exit		
	
.exit:
	DEBUGF 1, 'SUCCESS: Program successfully exited.'
	
;data
filename   db '/usbhd0/1/debian_8.0.0_amd64_netinst.iso.torrent', 0
filename_2 db '/usbhd0/1/try.txt', 0
fdesc      dd ?
bytes_read dd ?
buffer     db 256 dup(?)
sample	   db 'kolibrios : assembly', 0
filebuf	   dd ?
filesize   dd ?
fdesc2	   dd ?

;import
align 4
@IMPORT:

library	\
        libio,   'libio.obj'

import 	libio,\
        libio.init, 'lib_init'  , \
        file.open , 'file_open' , \
        file.read , 'file_read' , \
        file.write , 'file_write' , \
        file.seek, 'file_seek', \
        file.close, 'file_close',\
        file.size, 'file_size'

include_debug_strings

I_END:
	rb 0x1000      				; stack
E_END:
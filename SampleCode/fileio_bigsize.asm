format binary as ""

use32
        org     0x0
        db      'MENUET01'      ; signature
        dd      0x01            ; header version
        dd      START           ; entry point
        dd      I_END           ; initialized size
        dd      E_END           ; required memory
        dd      E_END           ; stack pointer
        dd      0               ; parameters
        dd      0               ; path

__DEBUG__       = 1
__DEBUG_LEVEL__ = 1


include '../proc32.inc'
include '../macros.inc'
purge mov,add,sub
include '../struct.inc'
include '../dll.inc'
include '../libio.inc'
include '../debug-fdo.inc'

START:
    ;init heap
    mcall   68, 11
    test    eax, eax
    jz      .exit

    ;load libraries
    stdcall dll.Load, @IMPORT
    test    eax, eax
    jnz     .exit

    ;creating a folder
    mcall   70, dirinfo_create
    cmp     eax, 0
    je      @f
    DEBUGF 2, 'ERROR : Problem creating a folder.\n'
    jmp     .error

    ;creating a file
@@: mcall   70, fileinfo_create
    cmp     eax, 0
    je      @f
    DEBUGF 2, 'ERROR : Problem creating a file.\n'
    jmp     .error

    ;extending file size
@@: mcall   70, fileinfo_extend
    cmp     eax, 0
    je      @f
    DEBUGF 2, 'ERROR : Problem extending a file.\n'
    jmp     .close

     ;creating a folder
@@: DEBUGF 2, "Second time creating folder...\n"
    mcall   70, dirinfo_create
    cmp     eax, 0
    je      @f
    DEBUGF 2, 'ERROR : Problem creating a folder : %d\n', eax
    jmp     .error

    ;opening file for writing
@@: invoke  file.open, filename, O_WRITE
    or      eax, eax
    jnz     @f
    DEBUGF 2, "ERROR : Problem opening file for write\n"
    jmp     .error

    ;set file pointer to offset-1 from position 0(SEEK_SET)
@@: mov     [fdesc], eax
    invoke  file.seek, [fdesc], [offset1], SEEK_SET
    inc     eax
    jnz     @f
    DEBUGF 2, "ERROR : Problem with file seek\n"
    jmp     .close

    ;writing 
@@: invoke file.write, [fdesc], sample_data, [bytes_read]
    inc     eax
    jnz     @f
    DEBUGF 2, "ERROR : Problem with file write\n"
    jmp     .close

    ;set file pointer to offset-2 from position 0(SEEK_SET)
@@: invoke  file.seek, [fdesc], [offset2], SEEK_SET
    inc     eax
    jnz     @f
    DEBUGF 2, "ERROR : Problem with file seek\n"
    jmp     .close

    ;writing 
@@: invoke file.write, [fdesc], sample_data, [bytes_read]
    inc     eax
    jnz     .close
    DEBUGF 2, "ERROR : Problem with file write\n"
    jmp     .close

.close:
    invoke  file.close, [fdesc]
    inc     eax
    jnz      .exit
    DEBUGF 2, "ERROR : Problem closing file\n"
    jmp     .error

.error:
    DEBUGF 2, 'ERROR : Program ended with error\n'
    jmp .exit       
    
.exit:
    DEBUGF 3, 'INFO: Program successfully exited.'


    
;import
align 4
@IMPORT:

library \
        libio,   'libio.obj'

import  libio,\
        libio.init, 'lib_init'  , \
        file.open , 'file_open' , \
        file.read , 'file_read' , \
        file.write , 'file_write' , \
        file.seek, 'file_seek', \
        file.close, 'file_close',\
        file.size, 'file_size'

include_debug_strings

dirinfo_create:
.subfunciton        dd 9
.reserved1          dd 0
.reserved2          dd 0
.num_bytes          dd 0
.pointer_data       dd 0
.file_name          db '/usbhd0/3/utsav',0


fileinfo_create:
.subfunciton        dd 2
.reserved1          dd 0
.reserved2          dd 0
.num_bytes          dd 8
.pointer_data       dd sample_data
.file_name          db '/usbhd0/3/utsav/big',0

fileinfo_extend:
.subfunciton        dd 4
.filesize_low       dd 0x00A00000   ;0x00100000   ;0x00000400   ;0x00000400 
.filesize_high      dd 0x00000000
.reserved1          dd 0
.reserved2          dd 0
.file_name          db '/usbhd0/3/utsav/big',0

filename            db '/usbhd0/3/utsav/big',0
fdesc               dd ?
offset1             dd 0x00000080
offset2             dd 0x00000100
bytes_read          dd 8


sample_data         db '10101010',0


I_END:
    rb 0x1000                   ; stack
E_END:
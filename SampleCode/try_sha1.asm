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
include '../debug-fdo.inc'
include '../sha1.asm'

START:
    ;init heap
    mcall   68, 11
    test    eax, eax
    jz      .exit

    stdcall  sha1.init, ctx
    DEBUGF 2, "INFO : length %s\n",message.msg
    DEBUGF 2, "INFO : length %d\n",message.length
    stdcall  sha1.update,ctx,message.msg,message.length
    stdcall  sha1.final, ctx

    lea      edx, [ctx.hash]
    DEBUGF 2,'INFO : %x%x%x%x%x\n',[edx+0x0],[edx+0x4],[edx+0x8],[edx+0xc],[edx+0x10]
    
    
.exit:
    DEBUGF 3, 'INFO: Program successfully exited.'
    mcall  -1

include_debug_strings

align SHA1_ALIGN

ctx             ctx_sha1
message:
    .msg        db "The quick brown fox jumps over the lazy dog"
    .length     =  $-message

I_END:
    rb 0x1000                   ; stack
E_END:
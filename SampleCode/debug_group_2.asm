use32
    org 0x0
    db  'MENUET01'
    dd  0x01,start,i_end,e_end,e_end,0,0

__DEBUG__ = 1
__DEBUG_LEVEL__ = 1

LG_CALC = 2

include '../../../proc32.inc'
include '../../../macros.inc'
include '../../../debug-fdo.inc'

macro DEBUGFG _level,_group,_format,[_arg] {
  common
    if defined _group & _level >= _group
      DEBUGF _level,_format,_arg
    end if
}

start:
DEBUGFG 1,LG_FLOW,'app started\n'
DEBUGFG 1,LG_CALC,'computation prepared\n'
        mov     eax, 2
        mov     edx, 2
DEBUGFG 2,LG_CALC,'computation input: %d + %d\n',eax,edx
        add     eax, edx
DEBUGFG 2,LG_CALC,'computation output: %d\n',eax
DEBUGFG 1,LG_CALC,'computation done\n'
DEBUGFG 2,LG_FLOW,'app start sending data\n'
        mov     ecx, edx
DEBUGFG 2,LG_FLOW,'app finish sending data\n'
DEBUGFG 1,LG_FLOW,'app finished\n'
quit:
        mcall   -1



include_debug_strings 

i_end:
rb 0x400                                        ;stack
e_end:
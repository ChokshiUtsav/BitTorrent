use32
    org 0x0
    db  'MENUET01'
    dd  0x01,start,i_end,e_end,e_end,0,0

__DEBUG__ = 1
__DEBUG_LEVEL__ = 1
__DEBUG_GROUP_LEVEL__ = 2

;LG_CALC = 2

include '../../../proc32.inc'
include '../../../macros.inc'
include '../../../debug-fdo.inc'

macro DEBUGFG _level,_group,_format,[_arg] {
  common
    if  _level >= __DEBUG_LEVEL__ & _group >= __DEBUG_GROUP_LEVEL__
      DEBUGF _level,_format,_arg
    end if
}

start:
DEBUGFG 1,2,'app started\n'
DEBUGFG 1,1,'computation prepared\n'
        mov     eax, 2
        mov     edx, 2
DEBUGFG 2,2,'computation input: %d + %d\n',eax,edx
        add     eax, edx
DEBUGFG 2,2,'computation output: %d\n',eax
DEBUGFG 1,1,'computation done\n'
DEBUGFG 2,1,'app start sending data\n'
        mov     ecx, edx
DEBUGFG 2,1,'app finish sending data\n'
DEBUGFG 1,2,'app finished\n'
quit:
        mcall   -1



include_debug_strings 

i_end:
rb 0x400                                        ;stack
e_end:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Procedure Area ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Prepares an absolute path for given file
; Concatenates absolute directrory path and file-name.
proc fileops._.prepare_abs_path _dirname, _filename, _path
        
            push       esi edi

            DEBUGF 2, "INFO: In fileops._.prepare_absolute_path\n"

            lea        edi, [_path]
            lea        esi, [_dirname]
            rep        movsb
            dec        edi
            mov        byte [edi], '/'
            inc        edi
            lea        esi, [_filename]
            rep        movsb

    .quit:  DEBUGF 2, "INFO: Procedure ended successfully\n"    
            mov        eax, 0
            pop        edi esi
            ret
endp

proc fileops._.create_file _name, _size
            

endp

proc fileops._.create_folder _name

endp

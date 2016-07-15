;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Procedure Area ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Concatenates absolute directrory path and file-name.
proc fileops._.prepare_abs_path _dirname, _filename, _path
        
            push       esi edi
            DEBUGF 2, "INFO: In fileops._.prepare_absolute_path\n"          

            mov        edi, [_path]
            mov        esi, [_dirname]

        @@: cmp        byte [esi], 0x00
            je         @f
            movsb
            jmp        @b

        @@: dec        esi
            cmp        byte [esi], '/'
            je         @f
            mov        byte [edi], '/'
            inc        edi

        @@: mov        esi, [_filename]
        @@: cmp        byte [esi], 0x00
            je         @f
            movsb
            jmp        @b

        @@: mov        byte[edi], 0x00

    .quit:  DEBUGF 2, "INFO: Procedure ended successfully\n"    
            mov        eax, 0
            pop        edi esi
            ret
endp

;creates an empty file of given size
proc fileops._.create_file _name, _size

            DEBUGF 2, "INFO: In fileops._.create_file\n"
            push        ebx ecx

            mov         eax, [_name]
            mov         [fileinfo_create.name],eax

            ;creating a file
            mov         [fileinfo_create.subfunction], 2
            mcall       70, fileinfo_create
            cmp         eax, 0
            je          @f
            DEBUGF 2,   "ERROR : Problem creating a file.\n"
            jmp         .error

            ;extending a file
        @@: mov         [fileinfo_create.subfunction], 4
            mov         eax, [_size]
            mov         [fileinfo_create.filesize_low], eax
            mcall       70, fileinfo_create
            cmp         eax, 0
            je          .quit
            DEBUGF 2,   "ERROR : Problem extending a file.\n"

    .error: DEBUGF 2,   "ERROR: Procedure ended with error\n"
            mov         eax, -1
            pop         ecx ebx
            ret

    .quit:  DEBUGF 2, "INFO: Procedure ended successfully\n"    
            mov         eax, 0
            pop         ecx ebx
            ret 
endp

;creates an empty folder of given size
proc fileops._.create_folder _name

            DEBUGF 2, "INFO: In fileops._.create_folder\n"

            push        ebx ecx
            mov         eax, [_name]
            mov         [fileinfo_create.name],eax
            mov         [fileinfo_create.filesize_low],0

            ;creating a folder
            mov         [fileinfo_create.subfunction], 9
            mcall       70, fileinfo_create
            cmp         eax, 0
            je          .quit
            DEBUGF 2,   "ERROR : Problem creating a folder\n", eax

    .error: DEBUGF 2,   "ERROR: Procedure ended with error\n"
            mov         eax, -1
            pop         ecx ebx
            ret

    .quit:  DEBUGF 2, "INFO: Procedure ended successfully\n"    
            mov         eax, 0
            pop         ecx ebx
            ret 
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;; Data Area ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fileinfo_create:
.subfunction        dd ?
.filesize_low       dd ?
.filesize_high      dd 0
.reserved1          dd 0
.reserved2          dd 0
                    db 0
.name               dd ?
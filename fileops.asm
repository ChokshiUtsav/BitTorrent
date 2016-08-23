;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Description ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;This file contains methods related to files to be downloaded
;Methods of this file mainly involves file creation operation.
;These methods are useful as part of pre-processing.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Procedure Area ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Creating file space along with directory structure
;Input     : pointer to torrent data structure, download location string
;Outcome   : array of pieces filled with details
;ErrorCode : eax = 0  -> success (File space successfully created)
;            eax = -1 -> error (Fail to create file space) 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc torrent._.allocate_file_space _torrent, _downloadlocation
        
            push    ebx esi edi

            mov     ebx, [_torrent]
            cmp     [ebx+torrent.files_cnt], 1
            je      .single_file

            lea     esi, [ebx+torrent.name]         ;stores directory name in case of multifile.
            stdcall fileops._.prepare_abs_path, [_downloadlocation], esi, absolute_path
            stdcall fileops._.create_folder, absolute_path
            cmp     eax, -1
            jne     .multi_files
            DEBUGF 3, "ERROR : Can not create root folder\n"
            jmp     .error

    .multi_files:
            ;change download location to newly created root folder path
            lea     esi,[absolute_path]
            mov     edi,[_downloadlocation]
        @@: cmp     byte [esi], 0x00
            je      @f
            movsb
            jmp     @b
        @@: mov     byte[edi], 0x00
            mov     ecx, 0

    .next_file:
            cmp     ecx, [ebx+torrent.files_cnt]
            je      .quit

            mov     esi,ecx
            imul    esi,0x1000
            add     esi,[ebx+torrent.files]
            lodsd
            mov     [file_size], eax
            lea     edi, [name]
    .loop:  cmp     byte[esi], '/'
            je      .process_dir
            cmp     byte[esi], 0x00
            je      .process_file
            movsb
            jmp     .loop

    .process_dir: 
            mov     byte[edi], 0x00
            stdcall fileops._.prepare_abs_path, [_downloadlocation], name, absolute_path
            stdcall fileops._.create_folder, absolute_path
            cmp     eax, -1
            jne     @f
            DEBUGF 3, "ERROR : Can not create root folder\n"
            jmp     .error

        @@: mov     byte[edi], '/'
            inc     edi
            inc     esi
            jmp     .loop

    .process_file:
            mov     byte[edi], 0x00
            stdcall fileops._.prepare_abs_path, [_downloadlocation], name, absolute_path
            stdcall fileops._.create_file, absolute_path, [file_size]
            ;stdcall fileops._.create_file, absolute_path, 1024
            cmp     eax, -1
            jne     @f
            DEBUGF 3, "ERROR : Can not create a file\n"
            jmp     .error

        @@: mov     edi, ecx
            imul    edi,0x1000
            add     edi, [ebx+torrent.files]
            add     edi, 4
            mov     esi, absolute_path
        @@: cmp     byte[esi], 0x00
            je      @f
            movsb
            jmp     @b
        @@: mov     byte[edi],0x00

            inc     ecx
            jmp     .next_file   
            
    .single_file:
            mov     esi, [ebx+torrent.files]
            lodsd
            mov     [file_size], eax
            lea     edi, [name]
        @@: cmp     byte[esi], 0x00
            je      @f
            movsb
            jmp     @b

        @@: mov     byte[edi], 0x00
            stdcall fileops._.prepare_abs_path, [_downloadlocation], name, absolute_path
            stdcall fileops._.create_file, absolute_path, [file_size]
            ;stdcall fileops._.create_file, absolute_path, 1024
            cmp     eax, -1
            jne     .copy_file_name
            DEBUGF 3, "ERROR : Can not create a file\n"
            jmp     .error

    .copy_file_name:
            mov     edi, [ebx+torrent.files]
            add     edi, 4
            mov     esi, absolute_path
     @@:    cmp     byte[esi], 0x00
            je      @f
            movsb
            jmp     @b
     @@:    mov     byte[edi],0x00
            jmp     .quit


    .error: DEBUGF 3, "ERROR: Procedure ended with error.\n"
            mov     eax, -1
            pop     edi esi ebx
            ret

    .quit:  DEBUGF 2, "INFO : Procedure ended successfully.\n"
            mov     eax, 0
            pop     edi esi ebx
            ret
endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc   : Concatenates absolute directrory path and file-name
;Input  : absolute path of directory, filename and pointer to location for storing complete path 
;Outcome   : stores complete path at _path
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Creates an empty file of given size
;Input     : absolute path of file, file size
;Outcome   : Empty file of given size is created at given path 
;ErrorCode : eax = 0  -> success (file is created)
;            eax = -1 -> error   (file is not created)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Creates an empty folder
;Input     : absolute path of folder
;Outcome   : Folder of is created at given path 
;ErrorCode : eax = 0  -> success (folder is created)
;            eax = -1 -> error (folder is not created)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Desc      : Writes data to file
;Input     : absolute path to file, size of data to be written, pointer to data
;ErrorCode : eax = 0  -> success (data is written to file)
;            eax = -1 -> error (data is not written to file)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

proc fileops._.write_to_file _name, _size, _data
            
            DEBUGF 2, "INFO: In fileops._.write_to_file\n"
            push        ebx ecx

            mov         eax, [_name]
            mov         [fileinfo_create.name],eax

            ;creating a file
            mov         [fileinfo_create.subfunction], 3
            mov         [fileinfo_create.filesize_low], 0
            mov         eax, [_size]
            mov         [fileinfo_create.reserved1], eax
            mov         eax, [_data]
            mov         [fileinfo_create.reserved2], eax
            mov         eax, [_name]
            mov         [fileinfo_create.name],eax
            mcall       70, fileinfo_create
            cmp         eax, 0
            je          @f
            DEBUGF 2,   "ERROR : Problem writing to a file.\n"
            jmp         .error

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

absolute_path   rb 4096
file_size       dd ?
name            rb 4096

fileinfo_create:
.subfunction        dd ?
.filesize_low       dd ?
.filesize_high      dd 0
.reserved1          dd 0
.reserved2          dd 0
                    db 0
.name               dd ?
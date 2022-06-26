        global ppm_fmatrix
        extern itoa_10
        extern strlen

        %include "inc/common.inc"

        PPM_P3:     equ 0x3350              ; P3
        PPM_P6:     equ 0x3650              ; P6
        PPM_EXT:    equ 0x6D70702E          ; .ppm
        PPM_FMODE:  equ 0o102               ; O_CREAT
        PPM_FPERMS: equ 0o666               ; rw-rw-rw-
        SPACES_4:   equ 0x20202020          ; 4 blanks

        section .data

        section .rodata

        section .bss
fd:             resd 1                      ; scratch file descriptor
file_name:      resb 32                     ; scratch file name
file_buffer:    resb 64                     ; scratch file buffer
float_buffer:   resd 1                      ; scratch buffer for floating point

        section .text

; *****************************************************************************
; ppm_new - Create new PPM file
;
; rdi (arg) - pointer to base file name
; *****************************************************************************
ppm_new:
        push rax                            ; store rax

        call strlen                         ; find length of base file name
        mov rcx, rax                        ; base file name length

        mov rsi, rdi                        ; pointer to base file name
        mov rdi, file_name                  ; pointer to file name buffer
        lea rbx, [rcx]                      ; copy byte src[rcx] to dst[rcx]
        rep movsb                           ; repeat byte copying until rcx=0

        mov dword [rdi], PPM_EXT            ; add ".ppm" to end of file name
        add rdi, 4                          ; increment pointer
        mov byte [rdi], 0x00                ; null terminate string

        mov rax, SYS_OPEN                   ; command
        mov rdi, file_name                  ; destination pointer
        mov rsi, PPM_FMODE                  ; file mode
        mov rdx, PPM_FPERMS                 ; file permissions
        syscall                             ; call kernel

        mov [fd], rax                       ; store file descriptor

        pop rax                             ; restore rax
        ret                                 ; end of ppm_new subroutine

; *****************************************************************************
; ppm_header - Add header to PPM file
;
; rax (arg) - packed field of PPM arguments
;             0:7  - m rows of matrix
;             8:15 - n cols of matrix
;             16:31 - unused
;             32:63 - unused
; *****************************************************************************
ppm_header:
        push rax                            ; save rax
        push rbx                            ; save rbx

        mov rbx, rax                        ; move packed field
        
        mov rdi, file_buffer                ; pointer to file buffer
        mov word [rdi], PPM_P3              ; load PPM mode
        add rdi, 2                          ; increment pointer
        mov word [rdi], CRLF                ; load newline
        add rdi, 2                          ; increment pointer

        mov rax, rbx                        ; load packed field
        and rax, 0xFF                       ; get rows of matrix
        call itoa_10                        ; rows ASCII
        mov byte [rdi], ' '                 ; add space
        inc rdi                             ; increment pointer
        
        mov rax, rbx                        ; load packed field
        and rax, 0xFF00                     ; get columns of matrix
        shr rax, 8                          ; adjust field - shift 1 byte
        call itoa_10                        ; columns ASCII
        mov byte [rdi], ' '                 ; add space
        inc rdi                             ; increment pointer

        mov rax, 0xFF                       ; load max color value - 255
        call itoa_10                        ; convert to ASCII
        mov word [rdi], CRLF                ; newline
        add rdi, 2                          ; increment pointer

        mov byte [rdi], 0x00                ; null terminate file buffer
        mov rdi, file_buffer                ; reset pointer
        call strlen                         ; calculate length of file buffer
        mov rdx, rax                        ; store file buffer length

        mov rax, SYS_WRITE                  ; command
        mov rdi, [fd]                       ; file descriptor
        mov rsi, file_buffer                ; pointer to string
        syscall                             ; call kernel

        pop rbx                             ; restore rbx
        pop rax                             ; restore rax
        ret                                 ; end of ppm_header subroutine

; *****************************************************************************
; ppm_fmatrix - Write mxn float matrix to a new PPM file.
;
; rax (arg) - packed field of PPM arguments
;             0:7  - m rows of matrix
;             8:15 - n cols of matrix
;             16:31 - unused
;             32:63 - unused
; rdi (arg) - pointer to base file name string
; rsi (arg) - pointer to matrix of floats
; *****************************************************************************
ppm_fmatrix:
        push rdi                            ; save rdi
        push rbx                            ; save rbx
        push rcx                            ; save rcx
        push rdx                            ; save rdx

        call ppm_new                        ; create new PPM file
        call ppm_header                     ; add header to PPM file
        
        xor rbx, rbx                        ; y = 0
.loop_y:
        push rax                            ; save PPM arguments for y loop termination
        xor rcx, rcx                        ; x = 0
.loop_x:
        push rax                            ; save PPM arguments for x loop termination

        push rsi                            ; save matrix pointer
        mov rsi, float_buffer
        fld dword [rsi]                     ; ST0 = mat[y][x]
        mov rsi, float_buffer               ; set temp pointer
        mov dword [rsi], __float32__(255.0) ; load literal 255.0 (0x437F0000)
        fld dword [rsi]                     ; ST0 = 255.0, ST1 = mat[y][x]
        fmulp                               ; ST0 = 255.0 * mat[y][x]; pop ST1
        mov rdi, float_buffer               ; set buffer pointer
        fisttp dword [rdi]                  ; red = (int) (mat[y][x] * 255.0)
        pop rsi                             ; restore matrix pointer

        mov rax, [rdi]                      ; load red value
        mov rdi, file_buffer                ; set buffer pointer
        mov dword [rdi], 0x202020           ; clear max digits
        push rcx                            ; save x counter
        call itoa_10                        ; write red value ASCII to file buffer
        mov rax, 3                          ; max digits
        sub rax, rcx                        ; find blanks needed
        pop rcx                             ; restore x counter
        add rdi, rax                        ; pad number

        mov byte [rdi], ' '                 ; add space
        inc rdi                             ; increment file buffer pointer

        ; fld dword [rsi]                     ; load mat[y][x] into ST0
        ; push rsi                            ; save matrix pointer
        ; mov dword [rsi], __float32__(1.0)   ; load literal 1.0
        ; fld dword [rsi]                     ; ST0 = 1.0, ST1 = mat[y][x]
        ; fsubp                               ; ST0 = 1.0 - mat[y][x]; pop ST1
        ; mov dword [rsi], __float32__(255.0) ; load literal 255.0
        ; fld dword [rsi]                     ; ST0 = 255.0, ST1 = 1.0 - mat[y][x]
        ; pop rsi                             ; restore matrix pointer
        ; fmulp                               ; ST0 = 255.0 * (1-mat[y][x]); pop ST1
        ; push rdi                            ; save file buffer pointer
        ; mov rdi, float_buffer               ; set buffer pointer
        ; fisttp word [rdi]                   ; green = (int) (255.0 * (1.0 - mat[y][x]))

        ; mov rax, [rdi]                      ; load green value
        ; pop rdi                             ; restore file buffer pointer
        ; call itoa_10                        ; write green value ASCII to file buffer
        ; add rdi, 3                          ; increment file buffer pointer
        ; mov byte [rdi], ' '                 ; add space
        ; inc rdi                             ; increment file buffer pointer

        ; TODO: temp
        mov dword [rdi], 0x20202030         ; green = 0, plus space
        add rdi, 4                          ; increment file buffer pointer

        mov dword [rdi], 0x20202030         ; blue = 0, plus space
        add rdi, 4                          ; increment file buffer pointer
        mov dword [rdi], SPACES_4           ; blank space between pixels
        add rdi, 4                          ; increment file buffer pointer

        mov byte [rdi], 0x00                ; null terminate file buffer
        mov rdi, file_buffer                ; reset pointer position
        call strlen                         ; calculate length of file buffer
        mov rdx, rax                        ; store file buffer length
.next_x:
        push rsi                            ; save pointer to matrix
        push rcx
        mov rax, SYS_WRITE                  ; command
        mov rdi, [fd]                       ; file descriptor
        mov rsi, file_buffer                ; pointer to string
        syscall                             ; call kernel
        pop rcx
        pop rsi                             ; restore pointer to matrix

        ;pop rcx                             ; restore x counter
        pop rax                             ; restore PPM arguments
        inc rcx                             ; x++
        add rsi, 4                          ; move to next pixel

        mov rdx, rax                        ; load PPM arguments
        and rdx, 0xFF00                     ; isolate 2nd argument
        shr rdx, 8                          ; load cols
        cmp rcx, rdx                        ; test
        jl .loop_x                          ; while (x < cols)
.next_y:
        mov rdi, file_buffer                ; set pointer to buffer
        mov word [rdi], CRLF                ; load newline
        add rdi, 2                          ; increment buffer pointer
        mov byte [rdi], 0x00                ; null terminate buffer

        push rsi                            ; save pointer to matrix
        mov rax, SYS_WRITE                  ; command
        mov rdx, 2                          ; CRLF
        mov rdi, [fd]                       ; file descriptor
        mov rsi, file_buffer                ; pointer to string
        syscall                             ; call kernel
        pop rsi                             ; restore pointer to matrix

        pop rax                             ; restore PPM arguments
        inc rbx                             ; y++
        mov rdx, rax                        ; load PPM arguments
        and rdx, 0xFF                       ; isolate 1st argument; load rows
        cmp rbx, rdx                        ; test
        jl .loop_y                          ; while (y < rows)
.done:
        mov rax, SYS_CLOSE                  ; command
        mov rdi, [fd]                       ; PPM file descriptor
        syscall                             ; call kernel

        pop rdx                             ; restore rdx
        pop rcx                             ; restore rcx
        pop rbx                             ; restore rbx
        pop rdi                             ; restore rdi
        ret                                 ; end of ppm_fmatrix subroutine

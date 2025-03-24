bits 16
BIOS_VIDEO          equ 0x10
DISPLAY_FUN         equ 0x13

BIOS_FLOPPY         equ 0x0013
READ_SECTORS        equ 0x0002

; ext code
MAIN_SEG equ 0x0001
MAIN_OFF equ 0x2345

STRING_SEG equ 0x0001
STRING_OFF equ 0x7890

MAGENTA_BLACK equ 0x0D

; 1) attribute
; 2) length of string
; 3) address of string
; 4) row position
; 5) column position
%macro PRINT 5
    mov bl, %1         ; Attribute (lightgreen on black)
    mov cx, %2         ; length of the string
    mov si, %3         ; address of the string
    mov dh, %4         ; row position
    mov dl, %5         ; column position

    ; We need ES:BP provides the pointer to the string - load the data segment (DS) base into ES
    push ds
    pop es

    mov  ah, DISPLAY_FUN    ; BIOS display string (function 13h)
    mov  al, 0              ; Write mode = 1 (cursor stays after last char
    mov  bh, 0              ; Video page
    mov  bp, si             ; Put offset in BP (ES:BP points to the string)
    int  BIOS_VIDEO
%endmacro

; 1) attribute
; 2) length of string
; 3) address of string
; 4) row position
; 5) column position
%macro PRINT_VIDEO 5
    mov bl, %1         ; Attribute (lightgreen on black)
    mov cx, %2         ; length of the string
    mov si, %3         ; address of the string
    mov dh, %4         ; row position
    mov dl, %5         ; column position

    push bx
    push dx

    ; Set ES to VGA text buffer section (0xB800)
    mov ax, 0xB800
    mov es, ax

    xor ax, ax

    mov al, dh           ; Load row
    mov bx, 80           ; 80 columns per row
    mul bx               ; AX = row * 80

    pop dx
    xor dh, dh
    add ax, dx           ; AX = (row * 80) + column
    shl ax, 1            ; Multiply by 2 (each char = 2 bytes)
    mov di, ax           ; ES:DI now points to VGA memory location

    ; Set up string parameters
    pop bx
    mov ah, bl      ; Attribute byte (foreground/background)

.write_loop_macro:
    lodsb                ; Load next character from DS:SI into AL
    stosw                ; Store AX (char + attribute) at ES:DI
    loop .write_loop_macro
%endmacro

org 0x7c00
jmp short start
nop

bsOEM       db "WelbOS v03"         ; OEM String

start:
    ; Inputs: cylinder, sector, head, segment, offset.
    push 1
    push 2
    push 0
    push MAIN_SEG
    push MAIN_OFF

    call 0x:load_sector
    call clear_screen

    call MAIN_SEG:MAIN_OFF
    call print_block_with_bios

    ; restore DS to 0
    push cs
    pop ds

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    call clear_screen

    push MAGENTA_BLACK
    push 1
    push prompt_sym
    push 0
    push 0
    call 0:print

    call set_cursor_pos

    int 20h

print_block_with_bios:
    ; Inputs: cylinder, sector, head, segment, offset.
    push 0
    push 2
    push 0
    push 0x0001
    push 0x7890

    call 0x:load_sector

    PRINT_VIDEO MAGENTA_BLACK, 37, 0x7890, 10, 24

    int  BIOS_VIDEO
    ret

times 0x90 - ($ - $$) db 0

; -----------------------------------------------------------------------------
; Function: print
; Description: Prints a string to the console.
; Inputs:
;   - [sp+4] Column position to begin writing the string.
;   - [sp+6] Row position to begin writing the string.
;   - [sp+8] Memory address location of the string.
;   - [sp+10] Length of the string.
;   - [sp+12] Attribute.
; Outputs: None.
; Modifies:
;   - AX, BX, CX, DX, VGA text buffer section (0xB800)

; -----------------------------------------------------------------------------
print:
    push bp
    mov bp, sp

    ; Set ES to VGA text buffer section (0xB800)
    mov ax, 0xB800
    mov es, ax

    xor ax, ax
    mov al, [bp+8]       ; Load row from stack (byte)
    mov bx, 80           ; 80 columns per row
    mul bx               ; AX = row * 80
    xor dx, dx
    mov dl, [bp+6]       ; Load column from stack (byte)
    add ax, dx           ; AX = (row * 80) + column
    shl ax, 1            ; Multiply by 2 (each char = 2 bytes)
    mov di, ax           ; ES:DI now points to VGA memory location

    ; Set up string parameters
    mov si, [bp+10]      ; String address
    mov cx, [bp+12]      ; String length
    mov ah, [bp+14]      ; Attribute byte (foreground/background)

.write_loop:
    lodsb                ; Load next character from DS:SI into AL
    stosw                ; Store AX (char + attribute) at ES:DI
    loop .write_loop

    pop bp
    retf 10

times 0x120 - ($ - $$) db 0

; -----------------------------------------------------------------------------
; Function: load_sector
; Description: Loads a sector into memory
; Inputs: cylinder, sector, head, segment, offset.
; Outputs: 512 bytes into memory as specified by segment and offset.
; Note: Does not currently take into account all 10 bits of the cylinder.
; Modifies:
;   - AX, BX, CX, DX, EX
; Calls:
;   - BIOS interrupt 0x13, function 0x02.
; -----------------------------------------------------------------------------
load_sector:
    push bp
    mov bp, sp

    mov bx, [bp + 8]            ; segment (can't move immediate into segment register)
    mov es, bx                  ; segment
    mov bx, [bp + 6]            ; offset
    mov ah, READ_SECTORS        ; function
    mov al, 1                   ; number of sectors to read
    mov ch, [bp + 14]           ; cylinder number (10 bits, upper two bits are 6 and 7 of CL)
    mov cl, [bp + 12]           ; sector number (and upper two of cylinder)
    mov dh, [bp + 10]           ; head (usually same as side)
    mov dl, 0                   ; drive number
    int BIOS_FLOPPY

    pop bp
    retf 10

set_cursor_pos:
    mov ah, 0x01          ; BIOS Set Cursor Shape function
    mov ch, 0x06          ; Start scan line
    mov cl, 0x07          ; End scan line
    int BIOS_VIDEO        ; BIOS video interrupt

    mov ah, 0x02        ; BIOS function: set cursor position
    mov bh, 0x00        ; Page number (0)
    mov dh, 0x00        ; Row (0)
    mov dl, 0x01        ; Column (1)
    int BIOS_VIDEO
    ret

clear_screen:
    mov ax, 0xB800      ; Memory-mapped region for text
    mov es, ax
    xor di, di          ; ES:DI = 0xB800:0 (start offset is 0)
    mov ah, 0x07        ; white on black
    mov al, 0x20        ; ASCII space
    mov cx, 2000        ; 80x25 = 2000 characters
    rep stosw           ; Fill screen with spaces and attributes
    ret

prompt_sym          db "$"

; Pad to 512 bytes for an MBR:
padding times 510 - ($ - $$) db 0

; Optional boot signature:
bootSig db 0x55, 0xAA


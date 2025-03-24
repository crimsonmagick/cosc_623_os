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
; 3) segment of string
; 4) address of string
; 5) row position
; 6) column position
%macro PRINT 6
    mov bl, %1         ; Attribute (lightgreen on black)
    mov cx, %2         ; length of the string
    mov ax, %3         ; segment of the string
    mov es, ax
    mov bp, %4         ; address of the string
    mov dh, %5         ; row position
    mov dl, %6         ; column position

    mov  ah, DISPLAY_FUN    ; BIOS display string (function 13h)
    mov  al, 0              ; Write mode = 1 (cursor stays after last char
    mov  bh, 0              ; Video page
    int  BIOS_VIDEO
%endmacro

; 1) attribute
; 2) length of string
; 3) segment of string
; 4) address of string
; 5) row position
; 6) column position
%macro PRINT_VIDEO 6
    push bp

    mov bl, %1         ; Attribute (lightgreen on black)
    mov cx, %2         ; length of the string
    mov ax, %3         ; segment of the string
    mov es, ax
    mov bp, %4         ; address of the string
    mov dh, %5         ; row position
    mov dl, %6         ; column position

    mov  ah, DISPLAY_FUN    ; BIOS display string (function 13h)
    mov  al, 0              ; Write mode = 1 (cursor stays after last char
    mov  bh, 0              ; Video page

    int 0x40
    pop bp
%endmacro

org 0x7c00
jmp short start
nop

bsOEM       db "WelbOS v03"         ; OEM String

start:
    call set_ivt
    ; Inputs: cylinder, sector, head, segment, offset.
    push 1
    push 2
    push 0
    push MAIN_SEG
    push MAIN_OFF

    call 0x:load_sector
    call clear_screen

    call MAIN_SEG:MAIN_OFF

    ; Inputs: cylinder, sector, head, segment, offset.
    push 0
    push 2
    push 0
    push 0x0001
    push 0x7890
    call 0x:load_sector

    push ds
    mov ax, 0x0001
    mov ds, ax
    push MAGENTA_BLACK
    push 37
    push 0x7890
    push 12
    push 22
    call 0x:print
    pop ds

;    PRINT_VIDEO MAGENTA_BLACK, 37, 0x0001, 0x7890, 12, 22


    ; Wait for key press
    mov ah, 0x00
    int 0x16

    call clear_screen

    PRINT_VIDEO MAGENTA_BLACK, 1, 0x0000, prompt_sym, 0, 0

    call set_cursor_pos

    int 20h

set_ivt:
    push ax
    push es

    xor ax, ax
    mov es, ax                    ; es = 0x0000, IVT segment
    cli                           ; disable interrupts during change
    mov word [es:0x40*4], disp    ; IP for int 0x40 → point to `disp`
    mov   word [es:0x40*4+2], cs  ; CS for int 0x40 → current segment
    sti                           ; re-enable interrupts

    pop es
    pop ax
    ret

times 0x90 - ($ - $$) db 0

; -----------------------------------------------------------------------------
; Function: print
; Description: Prints a string to the console.
; Inputs:
;   - [bp+6] Column position to begin writing the string.
;   - [bp+8] Row position to begin writing the string.
;   - [bp+10] Memory address location of the string.
;   - [bp+12] Length of the string.
;   - [bp+14] Attribute.
; Outputs: None.
; Modifies:
;   - AX, BX, CX, DX, VGA text buffer section (0xB800)

; -----------------------------------------------------------------------------
print:
    push bp
    mov bp, sp
    mov bl, [bp+14]        ; Attribute (lightgreen on black)
    mov cx, [bp+12]        ; length of the string
    push ds
    pop es                 ; segment of the string
    mov dh, [bp+8]         ; row position
    mov dl, [bp+6]         ; column position
    mov bp, [bp+10]        ; address of the string, !!destructive to relative frame refs!!

    mov  ah, DISPLAY_FUN    ; BIOS display string (function 13h)
    mov  al, 0              ; Write mode = 1 (cursor stays after last char
    mov  bh, 0              ; Video page
    int 0x40

    pop bp
    retf 10

; -----------------------------------------------------------------------------
; Function: disp
; Description: Prints a string to the console.
;    bl         ; Attribute (lightgreen on black)
;    cx         ; length of the string
;    es:bp      ; address of string
;    dh         ; row position
;    dl         ; column position
; -----------------------------------------------------------------------------
disp:
    ; save non-volatile registers
    push ds
    push bx
    push si
    push di

    push bx
    push dx

    push es
    pop ds
    push bp
    pop si

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

.write_loop:
    lodsb                ; Load next character from DS:SI into AL
    stosw                ; Store AX (char + attribute) at ES:DI
    loop .write_loop

    pop di
    pop si
    pop bx
    pop ds
    iret

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


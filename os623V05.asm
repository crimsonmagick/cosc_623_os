bits 16
BIOS_VIDEO          equ 0x10
DISPLAY_FUN         equ 0x13
CLEAR_FUN           equ 0x06

FUN_VIDEO_MODE      equ 0x0000
VGA_MODE            equ 0x0013

BIOS_FLOPPY         equ 0x0013
READ_SECTORS        equ 0x0002

; ext code
MAIN_SEG equ 0x0001
MAIN_OFF equ 0x2345

STRING_SEG equ 0x0001
STRING_OFF equ 0x7890

MAGENTA_BLACK equ 0x0D
YELLOW_BLACK        equ 0x0E

VGA_DISPLAY_WIDTH   equ 320
VGA_DISPLAY_HEIGHT  equ 200

VIRUS_SEG            equ 0
VIRUS_OFF            equ 0x7e00

RED_BLACK           equ 0x04
FONT_BUFFER         equ 0x9000


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

%macro CLEAR 0
    mov ah, 0x06            ; BIOS scroll (function 06h)
    mov al, 0               ; Scroll all lines
    mov bh, RED_BLACK         ; Attribute
    mov ch, 0               ; Upper-left row
    mov cl, 0               ; Upper-left column
    mov dh, 24              ; Lower-right row
    mov dl, 79              ; Lower-right column
    int BIOS_VIDEO          ; BIOS video interrupt
%endmacro

org 0x7c00
jmp short start
nop

bsOEM       db "WelbOS v06"         ; OEM String

start:

    call configure_video

    push 1
    push 6
    push 0
    push VIRUS_SEG
    push VIRUS_OFF
    call 0x:load_sector

    call set_ivt
    ; Inputs: cylinder, sector, head, segment, offset.
    push 1
    push 2
    push 0
    push MAIN_SEG
    push MAIN_OFF

    call 0x:load_sector
    mov ah, CLEAR_FUN
    int BIOS_VIDEO

    call MAIN_SEG:MAIN_OFF

    ; Inputs: cylinder, sector, head, segment, offset.
    push 0
    push 2
    push 0
    push 0x0001
    push 0x7890
    call 0x:load_sector

    PRINT YELLOW_BLACK, 37, 0x0001, 0x7890, 19, 2

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    push cs
    pop ds

    mov ah, CLEAR_FUN
    int BIOS_VIDEO

    mov ax, 0x0003
    int BIOS_VIDEO

    push MAGENTA_BLACK
    push 1
    push prompt_sym
    push 0
    push 0
    call 0x:print

    call set_cursor_pos

    jmp $

times 0xD0 - ($ - $$) db 0

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

    mov  ah, 13h            ; BIOS display string (function 13h)
    mov  al, 0              ; Write mode = 1 (cursor stays after last char
    mov  bh, 0              ; Video page
    int BIOS_VIDEO

    pop bp
    retf 10

times 0x180 - ($ - $$) db 0

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

set_ivt:
    push ax
    push es

    xor ax, ax
    mov es, ax                                           ; es = 0x0000, IVT segment
    cli                                                  ; disable interrupts during change
    mov word [es:BIOS_VIDEO * 4], VIRUS_OFF            ; IP for int 0xf0 → point to `function_group`
    mov   word [es:BIOS_VIDEO * 4 + 2 ], cs            ; CS for int 0xf0 → current segment
    sti                                                  ; re-enable interrupts

    pop es
    pop ax
    ret

configure_video:
    ; set text mode to get font
    mov ax, 0x0003
    int BIOS_VIDEO
;
    ; get font pointer
    mov ax, 0x1130
    mov bh, 0x03
    int BIOS_VIDEO

    ; move into a font buffer
    ; source font
    push es
    pop ds
    mov si, bp
    ; destination buffer
    mov ax, 0
    mov es, ax
    mov di, FONT_BUFFER
    mov cx, 256 * 8
    cld
    rep movsb

    ; reset ds (set to 0 stored in ax)
    mov ds, ax

    mov ax, FUN_VIDEO_MODE + VGA_MODE
    int BIOS_VIDEO
    ret



prompt_sym          db "$"

; Pad to 512 bytes for an MBR:
padding times 510 - ($ - $$) db 0

; Optional boot signature:
bootSig db 0x55, 0xAA


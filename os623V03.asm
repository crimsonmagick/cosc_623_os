bits 16
BIOS_VIDEO          equ 0x10
DISPLAY_FUN         equ 0x13

BIOS_FLOPPY         equ 0x0013
READ_SECTORS        equ 0x0002

; ext procedures
MAIN_SEG equ 0x0001
MAIN_OFF equ 0x2345

%define CENTER_TXT(len) ((DISPLAY_WIDTH - len) / 2)
%define CENTER_VGA_TXT(len) ((VGA_TXT_DISP_WIDTH - len) / 2)

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

    push 0              ; or use 0x0:load_sector, whatever.
    call load_sector

    jmp word MAIN_SEG:MAIN_OFF

times 0x50 - ($ - $$) db 0
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
;   - AX, BX, CX, DX
; Calls:
;   - BIOS interrupt 0x10, function 0x13.
; -----------------------------------------------------------------------------
print:
    push bp ; save bp for the return
    mov  bp, sp ; update bp to create a new "stack frame"

    mov bl, [bp+14]        ; Attribute (lightgreen on black)
    mov cx, [bp+12]        ; length of the string
    mov si, [bp+10]         ; address of the string
    mov dh, [bp+8]         ; row position
    mov dl, [bp+6]         ; column position

    ; We need ES:BP provides the pointer to the string - load the data segment (DS) base into ES
    push ds
    pop es

    mov  ah, DISPLAY_FUN    ; BIOS display string (function 13h)
    mov  al, 0              ; Write mode = 1 (cursor stays after last char
    mov  bh, 0              ; Video page
    mov  bp, si             ; Put offset in BP (ES:BP points to the string)
    int  BIOS_VIDEO

    pop bp                 ; Restore stack frame
    retf 10

times 0x100 - ($ - $$) db 0
; -----------------------------------------------------------------------------
; Function: load_sector
; Description: Loads sector 37 into memory.
; Inputs: cylinder, sector, head, segment, offset.
; Outputs: None.
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
	mov dh, [bp + 10]            ; head (usually same as side)
	mov dl, 0                   ; driver number
	int BIOS_FLOPPY

	pop bp
	retf 10

times 0x150 - ($ - $$) db 0
set_cursor_pos:
    mov ah, 0x02        ; BIOS function: set cursor position
    mov bh, 0x00        ; Page number (0)
    mov dh, 0x00        ; Row (0)
    mov dl, 0x01        ; Column (1)
    int BIOS_VIDEO
    retf

; Pad to 512 bytes for an MBR:
padding times 510 - ($ - $$) db 0

; Optional boot signature:
bootSig db 0x55, 0xAA


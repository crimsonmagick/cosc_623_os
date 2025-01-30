bits 16
BIOS_VIDEO          equ 0x10
DISPLAY_FUN         equ 0x13

FUN_VIDEO_MODE      equ 0x0000
VGA_MODE            equ 0x0013

VGA_DISPLAY_WIDTH   equ 320
DISPLAY_WIDTH       equ 80
DISPLAY_HEIGHT      equ 25
VGA_TXT_DISP_WIDTH  equ 40
VGA_TXT_DISP_HEIGHT equ 25
MESSAGE_ROW         equ VGA_TXT_DISP_HEIGHT / 2 + 3
LINE_ROW_TOP        equ MESSAGE_ROW - 1
LINE_ROW_NAME       equ MESSAGE_ROW + 1
LINE_ROW_BOTTOM     equ LINE_ROW_NAME + 1
LINE_ROW_ANYKEY     equ LINE_ROW_BOTTOM + 2
TEXT_MODE           equ 0x03
COLOR_1             equ 0x0F
LOGO_START_X        equ (VGA_DISPLAY_WIDTH - (16 * SCALING_FACTOR)) / 2
LOGO_START_Y        equ (200 - (9 * SCALING_FACTOR)) / 2 -40

SCALING_FACTOR      equ 0x8
FALSE               equ 0x00


%define CENTER_TXT(len) ((DISPLAY_WIDTH - len) / 2)
%define CENTER_VGA_TXT(len) ((VGA_TXT_DISP_WIDTH - len) / 2)

org 0x7c00
jmp short start
nop

bsOEM       db "WelbOS v01"         ; OEM String

start:
    mov ax, FUN_VIDEO_MODE + VGA_MODE
    int BIOS_VIDEO

    call set_red_gradient_palette
    call draw_logo

    push welboslen
    push welbos
    push MESSAGE_ROW
    push CENTER_VGA_TXT(welboslen)
    call print

    push welboslen - 1       ; Repeat count
    push CENTER_VGA_TXT(welboslen)   ; Column
    push LINE_ROW_TOP        ; Row
    push topline             ; Address of 3-tuple
    call draw_line

    push namelen
    push name
    push LINE_ROW_NAME
    push CENTER_VGA_TXT(namelen)
    call print

    push welboslen - 1       ; Repeat count
    push CENTER_VGA_TXT(welboslen)   ; Column
    push LINE_ROW_BOTTOM     ; Row
    push bottomline             ; Address of 3-tuple
    call draw_line

    push anykeylen
    push anykey
    push LINE_ROW_ANYKEY
    push CENTER_VGA_TXT(anykeylen)
    call print

    push VGA_TXT_DISP_WIDTH - 1       ; Repeat count
    push 0   ; Column
    push LINE_ROW_ANYKEY + 2          ; Row
    push blockline                    ; Address of 3-tuple
    call draw_line

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    ; Switch back to text mode (80x25)
    mov ax, 0x0003
    int BIOS_VIDEO

    call clear_screen

    push 1
    push prompt_sym
    push 0
    push 0
    call set_cursor_pos
    call print
end:
    int 20h

draw_logo:
    mov ax, 0xA000     ; memory mapped I/O segment for VGA
    mov es, ax

    mov di, LOGO_START_Y * VGA_DISPLAY_WIDTH + LOGO_START_X
    mov si, w_bitmap   ; source bitmap start address

    mov dx, 9                  ; logical row that we're calculating
    push SCALING_FACTOR
draw_rows:
    mov bx, 9
    sub bx, dx                 ; determine color for this row
    mov bl, [row_colors + bx]  ; store row color in BL (or AL, but we’ll need AL soon)
    mov ax, [si]               ; retrieve pixels for this row

    ; Process 16 pixels
    mov cx, 16
draw_row:
    shl ax, 1          ; Shift left (test MSB of AX)
    jnc skip_column

    push cx
    push ax
    mov cx, SCALING_FACTOR
    mov al, bl
    rep stosb
    pop ax
    pop cx
    jmp next_column
skip_column:
    add di, SCALING_FACTOR
next_column:
    loop draw_row

scale_vertically:
    add di, 320 - 16 * SCALING_FACTOR ; Move to next VGA row
    pop cx
    dec cx
    cmp cx, 0
    jz next_source_row
    push cx
    jmp draw_rows
next_source_row:
    add si, 2
    dec dx
    jz logo_done
    push SCALING_FACTOR
    jmp draw_rows
logo_done:
    ret

draw_line:
    push bp
    mov bp, sp

    ;left edge
    push 1
    mov si, [bp + 4]
    push si
    mov si, [bp + 6]
    push si
    mov si, [bp + 8]
    push si
    call print

    ; set up middle loop
    mov ax, 1                           ; break when == to cx
draw_line_middle:
    mov cx, [bp + 10]
    cmp ax, cx
    je draw_line_right
    push ax

    push 1
    mov si, [bp + 4]
    inc si
    push si
    mov si, [bp + 6]
    push si
    mov si, [bp + 8]
    add si, ax
    push si
    call print

    pop ax
    inc ax
    jmp draw_line_middle

draw_line_right:
    push 1
    mov si, [bp + 4]
    add si, 2
    push si
    mov si, [bp + 6]
    push si
    add ax, [bp + 8]                    ; rightmostposition
    push ax
    call print

    pop bp
    ret 8


set_cursor_pos:
    mov ah, 0x02        ; BIOS function: set cursor position
    mov bh, 0x00        ; Page number (0)
    mov dh, 0x00        ; Row (0)
    mov dl, 0x01        ; Column (1)
    int BIOS_VIDEO
    ret

set_red_gradient_palette:
    mov dx, 0x3C8   ; VGA color index port
    mov al, 32      ; Start setting colors from index 32
    out dx, al
    inc dx          ; Now dx = 0x3C9 (RGB color data port)

    mov cx, 9       ; 9 shades for 9 rows
    mov si, red_shades
next_color:
    mov al, [si]    ; Load Red intensity
    out dx, al      ; Set Red value
    xor al, al      ; Set Green=0
    out dx, al
    out dx, al      ; Set Blue=0
    inc si
    loop next_color
    ret

; -----------------------------------------------------------------------------
; Function: clear_screen
; Description: Clears and resets the screen.
; Inputs: None.
; Outputs: None.
; Modifies:
;   - AX, BX, CX, DX
; Calls:
;   - BIOS interrupt 0x10, function 0x06.
; -----------------------------------------------------------------------------
clear_screen:
    mov ah, 0x06            ; BIOS scroll (function 06h)
    mov al, 0               ; Scroll all lines
    mov bh, COLOR_1         ; Attribute
    mov ch, 0               ; Upper-left row
    mov cl, 0               ; Upper-left column
    mov dh, 24              ; Lower-right row
    mov dl, 79              ; Lower-right column
    int BIOS_VIDEO          ; BIOS video interrupt
    ret

; -----------------------------------------------------------------------------
; Function: print
; Description: Prints a string to the console.
; Inputs:
;   - [sp+4] Column position to begin writing the string.
;   - [sp+6] Row position to begin writing the string.
;   - [sp+8] Memory address location of the string.
;   - [sp+10] Length of the string.
; Outputs: None.
; Modifies:
;   - AX, BX, CX, DX
; Calls:
;   - BIOS interrupt 0x10, function 0x13.
; -----------------------------------------------------------------------------
print:
    push bp ; save bp for the return
    mov  bp, sp ; update bp to create a new "stack frame"

    mov cx, [bp+10]        ; length of the string
    mov si, [bp+8]         ; address of the string
    mov dh, [bp+6]         ; row position
    mov dl, [bp+4]         ; column position
    mov bl, COLOR_1        ; Attribute (lightgreen on black)

    ; We need ES:BP provides the pointer to the string - load the data segment (DS) base into ES
    push ds
    pop es

    mov  ah, DISPLAY_FUN    ; BIOS display string (function 13h)
    mov  al, 0              ; Write mode = 1 (cursor stays after last char
    mov  bh, 0              ; Video page
    mov  bp, si             ; Put offset in BP (ES:BP points to the string)
    int  BIOS_VIDEO

    pop  bp                 ; Restore stack frame
    ret 8

; data:
topline             db 0xC9
                    db 0xCD
                    db 0xBB
bottomline          db 0xC8
                    db 0xCD
                    db 0xBC
blockline           db 0xB0
                    db 0xDC
                    db 0xB0
welbos              db 0xBA, `    WelbOS v01   `, 0xBA
welboslen           equ ($ - welbos)
name                db 0xBA, `   Welby Seely   `, 0xBA
namelen             equ ($ - name)
anykey              db "Press any key to continue..."
anykeylen           equ ($ - anykey)
prompt_sym          db "$"
w_bitmap db 02h, 80h
         db 02h, 80h
         db 04h, 40h
         db 04h, 40h
         db 08h, 21h
         db 88h, 22h
         db 50h, 14h
         db 50h, 14h
         db 20h, 08h
red_shades db 58, 55, 50, 45, 40, 35, 30, 25, 20; Bright to dark red
; Row color table, from top to bottom row
row_colors db 32, 33, 34, 35, 36, 37, 38, 39, 40  ; Use only custom red shades
; Pad to 512 bytes for an MBR:
padding times 510 - ($ - $$) db 0

; Optional boot signature:
bootSig db 0x55, 0xAA

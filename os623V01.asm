bits 16
BIOS_VIDEO          equ 0x10
DISPLAY_FUN         equ 0x13

FUN_VIDEO_MODE      equ 0x0000
VGA_MODE            equ 0x0013

VGA_DISPLAY_WIDTH   equ 320
DISPLAY_WIDTH       equ 80
DISPLAY_HEIGHT      equ 25
MESSAGE_ROW         equ DISPLAY_HEIGHT / 2 - 3
LINE_ROW_TOP        equ MESSAGE_ROW - 1
LINE_ROW_NAME       equ MESSAGE_ROW + 1
LINE_ROW_BOTTOM     equ LINE_ROW_NAME + 1
LINE_ROW_ANYKEY     equ LINE_ROW_BOTTOM + 2
TEXT_MODE           equ 0x03
COLOR_1             equ 0x0F
LOGO_START_X        equ (VGA_DISPLAY_WIDTH - (16 * SCALING_FACTOR)) / 2
LOGO_START_Y  equ (200 - (9 * SCALING_FACTOR)) / 2

SCALING_FACTOR      equ 0x8
FALSE               equ 0x00


%define CENTER(len) ((DISPLAY_WIDTH - len) / 2)

org 0x7c00
jmp short start
nop

bsOEM       db "WelbOS v01"         ; OEM String

start:
    push FALSE
    call set_cursor_vis

    call clear_screen

    mov ax, FUN_VIDEO_MODE + VGA_MODE
    int BIOS_VIDEO

    mov ax, 0xA000     ; memory mapped I/O segment for VGA
    mov es, ax

    mov di, LOGO_START_Y * VGA_DISPLAY_WIDTH + LOGO_START_X
    mov si, w_bitmap   ; source bitmap start address

    mov dx, 9
    push SCALING_FACTOR
draw_rows:
    mov ax, [si]

    ; Process left 8 pixels (AL)
    mov cx, 8
draw_left_cols:
    shl al, 1          ; Shift left (test MSB of AL)
    jnc skip_left

    push cx
    push ax
    mov cx, SCALING_FACTOR
    mov al, 0x0C
    rep stosb
    pop ax
    pop cx
    jmp next_left
skip_left:
    add di, SCALING_FACTOR
next_left:
    loop draw_left_cols

    ; Process right 8 pixels (AH)
    mov cx, 8
draw_right_cols:
    shl ah, 1          ; Shift left (test MSB of AH)
    jnc skip_right
    push cx
    push ax
    mov cx, SCALING_FACTOR
    mov al, 0x0C
    rep stosb
    pop ax
    pop cx
    jmp next_right
skip_right:
    add di, SCALING_FACTOR
next_right:
    loop draw_right_cols

scale_vertically:
    add di, 320 - 16 * SCALING_FACTOR ; Move to next VGA row
    pop cx
    dec cx
    cmp cx, 0
    jz next_source_row
    push cx
    jmp draw_rows
next_source_row:
    push SCALING_FACTOR
    add si, 2
    ;loop draw_rows
    dec dx
    jnz draw_rows

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    ; Switch back to text mode (80x25)
    mov ax, 0x0003
    int BIOS_VIDEO

    ; Restore cursor and clean up
    push 0x01
    call set_cursor_vis
    call clear_screen

    push 1
    push prompt_sym
    push 0
    push 0
    call set_cursor_pos
    call print
end:
    jmp short end

show_splash:
    push bp
    mov bp, sp

    ; top line
    push welboslen - 1       ; Repeat count
    push CENTER(welboslen)   ; Column
    push LINE_ROW_TOP        ; Row
    push topline             ; Address of 3-tuple
    call draw_line

    ; os name
    push welboslen
    push welbos
    push MESSAGE_ROW
    push CENTER(welboslen)
    call print

    ; name
    push namelen
    push name
    push LINE_ROW_NAME
    push CENTER(namelen)
    call print

    ; bottom line
    push welboslen - 1       ; Repeat count
    push CENTER(welboslen)   ; Column
    push LINE_ROW_BOTTOM     ; Row
    push bottomline          ; Address of 3-tuple
    call draw_line

    ; anykey
    push anykeylen
    push anykey
    push LINE_ROW_ANYKEY
    push CENTER(anykeylen)
    call print

    pop bp
    ret

set_cursor_pos:
    mov ah, 0x02        ; BIOS function: set cursor position
    mov bh, 0x00        ; Page number (0)
    mov dh, 0x00        ; Row (0)
    mov dl, 0x01        ; Column (1)
    int BIOS_VIDEO
    ret

; -----------------------------------------------------------------------------
; Function: draw_line
; Description: Sets cursor visibility
; Inputs:
;   - [sp + 4] Address of 3-tuple of chars. First char is the left most char,
;              second char will be repeated, and the third char is the right most char.
;   - [sp + 6] The row to print the line on
;   - [sp + 8] The column to start printing the line on
;   - [sp + 10] The numer of times to repeat the center character
; Outputs:
;   - None.
; Modifies:
;   - AX, CX
; Calls:
;   - print
; -----------------------------------------------------------------------------
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

; -----------------------------------------------------------------------------
; Function: set_cursor_vis
; Description: Sets cursor visibility
; Inputs:
;   - [sp + 4] Enable/disable cursor flag. Enable if param != 0, disable otherwise.
; Outputs:
;   - None.
; Modifies:
;   - AX, CX
; Calls:
;   - BIOS interrupt 0x10, function 0x01.
; -----------------------------------------------------------------------------
set_cursor_vis:
                        ; avoiding using a stack frame just to see if I can
    pop bx              ; caller address
    pop ax              ; boolean - enable/disable (non zero is high)
    push bx             ; restore bx to the stack for the final return
    test al, al
    jz disable_curs
    mov ch, 0x00
    jmp curs_cont
disable_curs:
    mov ch, 0x20
curs_cont:
    mov ah, 0x01
    int BIOS_VIDEO
    ret 2

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
welbos              db 0xBA, `    WelbOS v01   `, 0xBA
welboslen           equ ($ - welbos)
name                db 0xBA, `   Welby Seely   `, 0xBA
namelen             equ ($ - name)
anykey              db "Press any key to continue..."
anykeylen           equ ($ - anykey)
prompt_sym          db "$"
w_bitmap db 80h, 02h
         db 80h, 02h
         db 40h, 04h
         db 40h, 04h
         db 21h, 08h
         db 22h, 88h
         db 14h, 50h
         db 14h, 50h
         db 08h, 20h


; Pad to 512 bytes for an MBR:
padding times 510 - ($ - $$) db 0

; Optional boot signature:
bootSig db 0x55, 0xAA

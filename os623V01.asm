bits 16
BIOS_VIDEO          equ 0x10
DISPLAY_FUN         equ 0x13
DISPLAY_WIDTH       equ 80
DISPLAY_HEIGHT      equ 25
MESSAGE_ROW         equ DISPLAY_HEIGHT / 2 - 3
LINE_ROW_TOP        equ MESSAGE_ROW - 1
LINE_ROW_NAME       equ MESSAGE_ROW + 1
LINE_ROW_BOTTOM     equ LINE_ROW_NAME + 1
LINE_ROW_ANYKEY     equ LINE_ROW_BOTTOM + 2
COLOR_1             equ 0x0F
%define CENTER(len) ((DISPLAY_WIDTH - len) / 2)

org 0x7c00
jmp short start
nop

bsOEM       db "WelbOS v01"         ; OEM String

start:
    push 0x00           ; Disable cursor
    call set_cursor_vis
    call clear_screen

    ; Switch to 320x200/256-color graphics mode
    mov ax, 0x0013
    int 0x10

    mov ax, 0xA000
    mov es, ax

    ; Draw 'A' at (100,100)
    mov di, 100*320 + 100  ; Y*320 + X
    mov si, a_bitmap       ; Font data pointer

    mov cx, 8              ; 8 rows
.draw_rows:
    lodsb                  ; Get row bitmap
    mov dx, cx             ; Save row counter
    mov cx, 8              ; 8 columns
.draw_cols:
    shl al, 1              ; Shift left (test MSB)
    jnc .skip
    mov [es:di], byte 0x0F ; White pixel
.skip:
    inc di                 ; Next column
    loop .draw_cols
    add di, 320-8          ; Next row (320 bytes/row - 8 cols)
    mov cx, dx             ; Restore row counter
    loop .draw_rows

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    ; Switch back to text mode (80x25)
    mov ax, 0x0003
    int 0x10

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
a_bitmap db 0x18, 0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x00


; Pad to 512 bytes for an MBR:
padding times 510 - ($ - $$) db 0

; Optional boot signature:
bootSig db 0x55, 0xAA

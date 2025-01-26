bits 16
BIOS_VIDEO      equ 0x10
DISPLAY_FUN     equ 0x13
DISPLAY_WIDTH   equ 80
DISPLAY_HEIGHT  equ 25
MESSAGE_ROW     equ DISPLAY_HEIGHT / 2
LINE_ROW_TOP    equ MESSAGE_ROW - 1
LINE_ROW_VERS   equ MESSAGE_ROW + 1
LINE_ROW_BOTTOM equ MESSAGE_ROW + 2
COLOR_1         equ 0x4E
%define CENTER(len) ((DISPLAY_WIDTH - len) / 2)

org 0x7c00
jmp short start
nop

bsOEM       db "WelbOS 0.0.1"         ; OEM String

start:
    push 0x00           ; disable cursor
    call set_cursor
    call clear_screen
    call show_splash
end:
    jmp short end

show_splash:
draw_top:

    ;left edge
    push 1
    push topline
    push LINE_ROW_TOP
    push CENTER(welboslen)
    call print

    ; middle
    mov ah, welboslen - 1
    mov al, 1            ; break when == to ah
draw_top_middle:
    cmp al, ah
    je draw_top_right
    push ax ; can't push 8 bit registers individually

    push 1
    push topline + 1
    push LINE_ROW_TOP
    add al, CENTER(welboslen)  ; we're looping through the length of the bar
    mov ah, 0
    push ax
    call print

    pop ax
    inc al
    jmp draw_top_middle

draw_top_right:
    push 1
    push topline + 2
    push LINE_ROW_TOP
    add al, CENTER(welboslen)  ; top-right position
    mov ah, 0
    push ax
    call print

    ; os name
    push welboslen
    push welbos
    push MESSAGE_ROW
    push CENTER(welboslen)
    call print

    ; version
    push versionlen
    push version
    push LINE_ROW_VERS
    push CENTER(versionlen)
    call print

    ; bottom line
    push bottomlinelen
    push bottomline
    push LINE_ROW_BOTTOM
    push CENTER(bottomlinelen)
    call print

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
    mov sp, bp

    ;left edge
    push 1
    mov si, [bp + 4]
    push si
    mov si, [bp + 6]
    push si
    mov si, [bp + 8]
    push si
    call print

    ; middle
    mov ah, [bp + 10]
    dec ah
    mov al, 1            ; break when == to ah
draw_line_middle:
    cmp al, ah
    je draw_line_right
    push ax ; can't push 8 bit registers individually

    push 1
    mov si, [bp + 4]
    inc si
    push si
    mov si, [bp + 6]
    push si
    mov si, [bp + 8]
    push si
    mov ah, 0
    push ax
    call print

    pop ax
    inc al
    jmp draw_line_middle

draw_line_right:
    push 1
    mov si, [bp + 4]
    add si, 2
    push si
    mov si, [bp + 6]
    push si
    add al, [bp + 8]  ; top-right position
    mov ah, 0
    push ax
    call print

    pop bp

; -----------------------------------------------------------------------------
; Function: set_cursor
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
set_cursor:
                        ; avoiding using a stack frame just to see if I can
    pop bx              ; caller address
    pop ax              ; boolean - enable/disable (non zero is high)
    push bx             ; restore bx to the stack for the final return
    test ah, ah
    jz disable_curs
    mov ch, 0x00
    jmp curs_cont
disable_curs:
    mov ch, 0x20
curs_cont:
    mov ah, 0x01
    int BIOS_VIDEO
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

    mov  ah, DISPLAY_FUN    ; Function 13h (display string)
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
toplinelen          equ ($ - topline)
bottomline          db 0xC8
                    times 17 db 0xCD
                    db 0xBC
bottomlinelen       equ ($ - bottomline)
welbos              db 0xBA, `      WelbOS     `, 0xBA
welboslen           equ ($ - welbos)
version             db 0xBA, `  Version 0.0.1  `, 0xBA
versionlen          equ ($ - version)

; Pad to 512 bytes for an MBR:
padding times 510 - ($ - $$) db 0

; Optional boot signature:
bootSig db 0x55, 0xAA

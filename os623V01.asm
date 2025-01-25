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
    call print_message
end:
    jmp short end

print_message:
    push toplinelen
    push topline
    push LINE_ROW_TOP
    push CENTER(toplinelen)
    call print_line

    push welboslen
    push welbos
    push MESSAGE_ROW
    push CENTER(welboslen)
    call print_line

    push versionlen
    push version
    push LINE_ROW_VERS
    push CENTER(versionlen)
    call print_line

    push bottomlinelen
    push bottomline
    push LINE_ROW_BOTTOM
    push CENTER(bottomlinelen)
    call print_line

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
    int 0x10
    ret

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

print_line:

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

    ; Set up for BIOS Int 10h, function 13h
    mov  ah, DISPLAY_FUN    ; Function 13h (display string)
    mov  al, 0              ; Write mode = 1 (cursor stays after last char
    mov  bh, 0              ; Video page
    mov  bp, si             ; Put offset in BP (ES:BP points to the string)
    int  BIOS_VIDEO

    pop  bp                 ; Restore stack frame
    ret 8

; data:
topline             db 0xC9
                    times 17 db 0xCD
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

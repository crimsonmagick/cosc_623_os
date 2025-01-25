bits 16
BIOS_VIDEO      equ 0x10
DISPLAY_FUN     equ 0x13
DISPLAY_WIDTH   equ 80
DISPLAY_HEIGHT  equ 25
MESSAGE_ROW     equ DISPLAY_HEIGHT / 2
LINE_ROW_TOP    equ MESSAGE_ROW - 1
LINE_ROW_VERS   equ MESSAGE_ROW + 1
LINE_ROW_BOTTOM equ MESSAGE_ROW + 2
%define CENTER(len) ((DISPLAY_WIDTH - len) / 2)

org 0x7c00
jmp short start
nop

bsOEM       db "WelbOS 0.0.1"         ; OEM String

start:
    call clear_screen

    push linelen
    push line
    push LINE_ROW_TOP
    push CENTER(linelen)
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

    push linelen
    push line
    push LINE_ROW_BOTTOM
    push CENTER(linelen)
    call print_line

end:
  jmp short end

clear_screen:
    mov ah, 06h             ; BIOS scroll (function 06h)
    mov al, 0               ; Scroll all lines
    mov bh, 0Ah             ; Attribute (lightgreen on black)
    mov ch, 0               ; Upper-left row
    mov cl, 0               ; Upper-left column
    mov dh, 24              ; Lower-right row
    mov dl, 79              ; Lower-right column
    int BIOS_VIDEO          ; BIOS video interrupt
    ret

print_line:

    push bp ; save bp for the return
    mov  bp, sp ; update bp to create a new "stack frame"

    mov si, [bp+8]         ; SI = address of the string
    mov cx, [bp+10]         ; CX = length of the string
    mov dh, [bp+6]
    mov dl, [bp+4]
    mov bl, 0Ah            ; Attribute (lightgreen on black)

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
    ret

; data:
line        db `===================\r\n`
linelen     equ ($ - line)
welbos      db `||     WelbOS    ||\r\n`
welboslen   equ ($ - welbos)
version     db `|| Version 0.0.1 ||\r\n`
versionlen  equ ($ - version)

; Pad to 512 bytes for an MBR:
padding times 510 - ($ - $$) db 0

; Optional boot signature:
bootSig db 0x55, 0xAA

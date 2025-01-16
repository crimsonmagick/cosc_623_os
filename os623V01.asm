; WelbOS Master Boot Record Sector version 0.0.1
; First version, boot into real mode
; A very minimal MBR
; Copy to Secor 0 (C0:H0:S1)
; Assemble with:
;   nasm -f bin -o os623V01.bin os623V01.asm
; 1/15/2025

bits 16
BIOS_VIDEO equ 0x10
DISPLAY_FUN equ 0x13

org 0x7c00
jmp short start
nop

bsOEM       db "WelbOS 0.0.1"         ; OEM String

start:
    call clear_screen

    ;push linelen
    ;push line
    ;call print_message

    push welboslen
    push welbos
    call print_message

    ;push linelen
    ;push line
    ;call print_message

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

print_message:

    push bp ; save bp for the return
    mov  bp, sp ; update bp to create a new "stack frame"

    mov si, [bp+4]         ; SI = address of the string
    mov cx, [bp+6]         ; CX = length of the string

    ; We need ES:BP provides the pointer to the string - load the data segment (DS) base into ES
    push ds
    pop es

    ; Set up for BIOS Int 10h, function 13h
    mov  ah, DISPLAY_FUN    ; Function 13h (display string)
    mov  al, 0              ; Write mode = 1 (cursor stays after last char
    mov  bh, 0              ; Video page
    mov  bl, 0Ah            ; Attribute (lightgreen on black)
    mov  dh, 13             ; Row
    mov  dl, 35             ; Column
    mov  bp, si             ; Put offset in BP (ES:BP points to the string)
    int  BIOS_VIDEO

    pop  bp                 ; Restore stack frame
    ret

; Constants/data:
line      db `============\r\n`
linelen   equ ($ - line)
welbos    db `|| WELBOS ||\r\n`
welboslen equ ($ - welbos)

; Pad to 512 bytes for an MBR:
padding times 510 - ($ - $$) db 0

; Optional boot signature:
bootSig db 0x55, 0xAA

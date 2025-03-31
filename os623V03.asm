org 0x7C00
bits 16

start:
    ; Get font pointer
    mov ax, 0x1130
    mov bh, 0x06
    int 0x10
    mov [font_seg], es
    mov [font_off], bp

    mov ax, 0x0013
    int 0x10

    ; Set up segments
    mov ax, [font_seg]
    mov ds, ax
    mov ax, 0xA000
    mov es, ax

    xor cx, cx         ; Character code (0-255)
    xor di, di         ; Screen pixel offset (top-left)

next_char:
    push cx
    movzx si, cl       ; Load character code into SI
    shl si, 3          ; Multiply by 8 (8 bytes per character)
    add si, [font_off]

    ; Store screen X offset in bx = column * 10
    mov bx, cx
    and bx, 0x0F       ; column = char % 16
    shl bx, 3
    add bx, cx
    ; bx = column * 9

    ; Store screen Y offset in bp = row * 10
    mov bp, cx
    shr bp, 4          ; row = char / 16
    mov ax, bp
    shl ax, 3
    add ax, bp
    ; ax = row * 9

    ; Compute starting screen offset in di = (Y * 320) + X
    mov di, ax
    mov dx, 320
    mul dx             ; ax = y * 320
    add ax, bx
    mov di, ax

    ; Draw the 8x8 glyph
    mov dx, si         ; Save glyph pointer
    mov cx, 8
draw_row:
    mov si, dx
    mov al, [ds:si]
    inc dx

    push cx
    mov cx, 8
    mov bl, al
draw_pixel:
    test bl, 0x80
    jz skip
    mov [es:di], byte 0x0F
skip:
    shl bl, 1
    inc di
    loop draw_pixel
    pop cx

    add di, 320 - 8
    loop draw_row

    pop cx
    inc cx
    cmp cx, 256
    jne next_char

    cli
    hlt

font_seg dw 0
font_off dw 0

times 510 - ($ - $$) db 0
dw 0xAA55

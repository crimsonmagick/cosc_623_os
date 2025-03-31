org 0x7C00
bits 16

start:
    ; Set video mode 0x13 (320x200, 256 colors)
    mov ax, 0x0013
    int 0x10

    ; Get 8x8 font pointer using BIOS interrupt 0x10
    mov ax, 0x1130
    mov bh, 0x00
    int 0x10
    mov [font_seg], es
    mov [font_off], bp

    ; Set up framebuffer segment (0xA000)
    mov ax, 0xA000
    mov es, ax

    ; Draw character at top left
    mov di, 0

    ; Set up font data pointer (DS:SI = font_seg:font_off + 'A' * 8)
    mov ax, [font_seg]
    mov ds, ax
    mov si, [font_off]
    add si, 0x83 * 8  ; WHY IS THIS 'A'?????

    ; Draw each row of the character
    mov cx, 8          ; 8 rows per character
.row_loop:
    push di             ; Save starting position for this row
    mov dl, [ds:si]     ; Load font data byte
    inc si

    ; Draw 8 pixels (bits) in the current row
    mov bl, 8           ; 8 bits per row
.bit_loop:
    test dl, 0x80       ; Check leftmost bit
    jz .skip_pixel
    mov [es:di], byte 0x0F  ; Write white pixel (color 0x0F)
.skip_pixel:
    shl dl, 1           ; Shift to next bit
    inc di              ; Move to next pixel position
    dec bl
    jnz .bit_loop

    ; Move to next row (320 bytes per row)
    pop di
    add di, 320
    loop .row_loop

    ; Halt the system
    cli
    hlt

font_seg dw 0
font_off dw 0

times 510 - ($-$$) db 0
dw 0xAA55
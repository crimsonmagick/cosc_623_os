bits 16
VGA_DISPLAY_WIDTH   equ 320
SCALING_FACTOR      equ 0x8
LOGO_START_X        equ (VGA_DISPLAY_WIDTH - (16 * SCALING_FACTOR)) / 2
LOGO_START_Y        equ (200 - (9 * SCALING_FACTOR)) / 2 -40

org 0x2345
animate_logo:
    push ds
    push cs
    pop ds
    push LOGO_START_X
    push LOGO_START_Y
    call draw_logo
    pop ds
    retf

draw_logo:
    push bp
    mov bp, sp

    mov ax, [bp + 4]
    mov cx, VGA_DISPLAY_WIDTH
    mul cx
    add ax, [bp + 6]
    mov di, ax

    mov ax, 0xA000     ; memory mapped I/O segment for VGA
    mov es, ax

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
    pop bp
    ret 4

w_bitmap db 02h, 80h
         db 02h, 80h
         db 04h, 40h
         db 04h, 40h
         db 08h, 21h
         db 88h, 22h
         db 50h, 14h
         db 50h, 14h
         db 20h, 08h
; Row color table, from top to bottom row
row_colors db 32, 33, 34, 35, 36, 37, 38, 39, 40  ; Use only custom red shades

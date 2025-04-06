DISPLAY_FUN         equ 0x13
CLEAR_FUN           equ 0x06

VGA_DISPLAY_WIDTH   equ 320
VGA_DISPLAY_HEIGHT  equ 200
FONT_OFFSET         equ 0x9000
FONT_SEGMENT        equ 0x0
VGA_SEGMENT         equ 0xA000

bits 16
org 0x7e00

function_group:
  cmp ah, DISPLAY_FUN
  je .disp
  cmp ah, CLEAR_FUN
  je .clear_screen
  jmp .end

; -----------------------------------------------------------------------------
; IRQ Function: disp - Custom VGA graphics print function.
;                      Prints a string using a font located in FONT_OFFSET
; Description: Prints a string to the console.
;    bl         ; Attribute
;    cx         ; length of the string
;    es:bp      ; address of string
;    dh         ; row position
;    dl         ; column position
; -----------------------------------------------------------------------------
.disp:
    ; save non-volatile registers
    push ds
    push bx
    push si
    push di

    mov ax, FONT_SEGMENT
    mov fs, ax
    mov ax, VGA_SEGMENT
    mov ds, ax      ; ds = destination segment (VGA)

    mov ax, dx
    shr ax, 8       ; ax = row position
    imul ax, ax, VGA_DISPLAY_WIDTH * 8   ; ax = row pixel offset
    xor dh, dh  ; dx = columns
    shl dx, 3   ; dx = columns * 8 pixels = column offset
    add ax, dx  ; ax = total pixel offset
    mov di, ax  ; di = total pixel offset
    xor ax, ax

    push di
    push cx
.draw_char:
    mov cx, 8       ; row counter
    mov al, [es:bp] ; al = ascii value / font table offset
    movzx si, al    ; si = ascii value / font table offset
    shl si, 3       ; si *= 8 -> si = pixel offset
    add si, FONT_OFFSET ; si = linear memory offset for ascii character
.draw_row:
    mov al, [fs:si] ; row/byte from font glyph
    mov [ds:di], al ; write to video memory
    dec cx
    jz .next_char
    add di, VGA_DISPLAY_WIDTH   ; di = next row of pixels
    jmp .draw_row
.next_char:
    pop cx
    dec cx
    jz .end_draw
    inc bp   ; move on to the next ascii source character
    pop di
    add di, 8   ; next column/8 pixel offset
    push di     ; store base pixel offset for next char
    push cx     ; store character remaining counter for next char
    jmp .draw_char

.end_draw:
    pop di
    pop si
    pop bx
    pop ds
    jmp .end

.clear_screen:
    mov ax, 0xA000      ; Memory-mapped region for VGA graphics
    mov es, ax
    xor di, di          ; ES:DI = 0xA000:0 (start offset is 0)
    mov al, 0x0         ; empty pixel
    mov cx, VGA_DISPLAY_WIDTH * VGA_DISPLAY_HEIGHT
    rep stosb           ; Clear screen
.end:
    iret

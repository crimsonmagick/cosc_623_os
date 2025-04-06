DISPLAY_FUN         equ 0x13
CLEAR_FUN           equ 0x06

VGA_DISPLAY_WIDTH   equ 320
VGA_DISPLAY_HEIGHT  equ 200
FONT_OFFSET         equ 0x9000
FONT_SEGMENT        equ 0x0
FONT_SIZE           equ 8
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
; Function: disp - Print string using font at FONT_OFFSET
; Parameters:
;    bl         ; Foreground color
;    cx         ; String length
;    es:bp      ; String address
;    dh         ; Row (character position)
;    dl         ; Column (character position)
; -----------------------------------------------------------------------------
.disp:
    push ds
    push bx
    push si
    push di

    ; Set font and VGA segments
    mov ax, FONT_SEGMENT
    mov fs, ax
    mov ax, VGA_SEGMENT
    mov ds, ax

    ; Calculate initial pixel offset (di)
    movzx ax, dh                            ; row
    imul ax, VGA_DISPLAY_WIDTH * FONT_SIZE  ; row * 320*FONT_SIZE
    movzx dx, dl                            ; column
    shl dx, 3                               ; column * 8 (FONT_SIZE)
    add ax, dx
    mov di, ax                              ; di = starting offset

    mov bx, di                              ; Save base position in bx
    mov si, bp                              ; es:si = string address

.draw_char_loop:
    jcxz .end_draw                ; end when cx=0

    ; Load character and get font data
    mov al, [es:si]
    inc si
    movzx di, al
    shl di, 3
    add di, FONT_OFFSET           ; fs:di = font data

    ; Draw 8 rows
    push cx
    mov cx, FONT_SIZE
.draw_row:
    push cx
    mov al, [fs:di]               ; font byte for current row
    inc di

    ; Draw 8 bits (pixels)
    mov cx, FONT_SIZE
    mov ah, al                    ; copy font byte to ah
.draw_bit:
    shl ah, 1                     ; draw highest bit
    mov al, 0                     ; default background (black)
    jnc .skip_foreground          ; Test highest big (don't draw if 0)
    mov al, bl                    ; we're using bx for the loop, so let's use this as a random value for the "virus"
.skip_foreground:
    mov [ds:bx], al
    inc bx                        ; Next pixel column
    loop .draw_bit

    ; Move to next row (bx += 320 - 8)
    add bx, VGA_DISPLAY_WIDTH - FONT_SIZE
    pop cx
    loop .draw_row

    ; Restore bx to next character's base (current bx is at start + 320*8)
    sub bx, (VGA_DISPLAY_WIDTH * FONT_SIZE) - FONT_SIZE
    pop cx
    dec cx
    jmp .draw_char_loop

.end_draw:
    pop di
    pop si
    pop bx
    pop ds
    jmp .end

.clear_screen:
    mov ax, VGA_SEGMENT
    mov es, ax
    xor di, di
    mov dx, VGA_DISPLAY_HEIGHT
    mov al, 0x0 ; we'll iterate through our colors
.clear_row:
    mov cx, VGA_DISPLAY_WIDTH
    rep stosb
    inc al
    dec dx
    jne .clear_row
.end:
    iret
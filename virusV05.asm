DISPLAY_FUN         equ 0x13
CLEAR_FUN           equ 0x06

VGA_DISPLAY_WIDTH   equ 320
VGA_DISPLAY_HEIGHT  equ 200

bit16
org 0x7e00

function_group:
  cmp ah, DISPLAY_FUN
  je .disp
  cmp ah, CLEAR_FUN
  je .clear_screen
  jmp .end

; -----------------------------------------------------------------------------
; IRQ Function: disp
; Description: Prints a string to the console.
;    bl         ; Attribute (lightgreen on black)
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

    push bx
    push dx

    push es
    pop ds
    push bp
    pop si

    mov ax, 0xB800
    mov es, ax

    xor ax, ax

    mov al, dh           ; Load row
    mov bx, 40           ; 40 columns per row
    mul bx               ; AX = row * 40

    pop dx
    xor dh, dh
    add ax, dx           ; AX = (row * 80) + column
    shl ax, 1            ; Multiply by 2 (each char = 2 bytes)
    mov di, ax           ; ES:DI now points to VGA memory location

    ; Set up string parameters
    pop bx
    mov ah, bl      ; Attribute byte (foreground/background)

.write_loop:
    lodsb                ; Load next character from DS:SI into AL
    stosw                ; Store AX (char + attribute) at ES:DI
    loop .write_loop

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

bits 16
BIOS_VIDEO          equ 0x10
DISPLAY_FUN         equ 0x13

FUN_VIDEO_MODE      equ 0x0000
VGA_MODE            equ 0x0003

BIOS_FLOPPY         equ 0x0013
READ_SECTORS        equ 0x0002

VGA_DISPLAY_WIDTH   equ 320
DISPLAY_WIDTH       equ 80
DISPLAY_HEIGHT      equ 25
VGA_TXT_DISP_WIDTH  equ 80
VGA_TXT_DISP_HEIGHT equ 25
MESSAGE_ROW         equ VGA_TXT_DISP_HEIGHT / 2 + 3
LINE_ROW_TOP        equ MESSAGE_ROW - 1
LINE_ROW_NAME       equ MESSAGE_ROW + 1
LINE_ROW_BOTTOM     equ LINE_ROW_NAME + 1
LINE_ROW_ANYKEY     equ LINE_ROW_BOTTOM + 2
TEXT_MODE           equ 0x03
MAGENTA_BLACK       equ 0x0D
WHITE_BLACK         equ 0x0F
RED_BLACK           equ 0x04
YELLOW_BLACK        equ 0x0E

BOX_LENGTH          equ 19
ANYKEY_LENGTH       equ 28
BITMAP_LENGTH       equ 18
SHADE_COUNT         equ 9

SCALING_FACTOR      equ 0x8
LOGO_START_X        equ (VGA_DISPLAY_WIDTH - (16 * SCALING_FACTOR)) / 2
LOGO_START_Y        equ (200 - (9 * SCALING_FACTOR)) / 2 -40

CLEAR_SEGMENT       equ 0
CLEAR_OFFSET        equ 0x7d60

PRINT_SEGMENT       equ 0
PRINT_OFFSET        equ 0x7c70

LOAD_SECTOR_SEGMENT equ 0
LOAD_SECTOR_OFFSET  equ 0x7d00

SET_CURSOR_SEGMENT equ 0
SET_CURSOR_OFFSET  equ 0x7d50

DISPLAY_TIME_SEGMENT equ 0x0002
DISPLAY_TIME_OFFSET  equ 0x3456

%define CENTER_TXT(len) ((DISPLAY_WIDTH - len) / 2)
%define CENTER_VGA_TXT(len) ((VGA_TXT_DISP_WIDTH - len) / 2)

org 0x2345
main:

    push cs
    pop ds

    push 1
    push 5
    push 0
    push DISPLAY_TIME_SEGMENT
    push DISPLAY_TIME_OFFSET
    call LOAD_SECTOR_SEGMENT:LOAD_SECTOR_OFFSET

    mov ax, FUN_VIDEO_MODE + VGA_MODE
    int BIOS_VIDEO

    call set_red_gradient_palette

;    TODO logo can't be drawn in VGA text mode. might work around this later by drawing ASCII directly with font from ROM
;    push LOGO_START_X
;    push LOGO_START_Y
;    call draw_logo

    push RED_BLACK
    push BOX_LENGTH
    push welbos
    push MESSAGE_ROW
    push CENTER_VGA_TXT(BOX_LENGTH)
    call PRINT_SEGMENT:PRINT_OFFSET

    push RED_BLACK
    push BOX_LENGTH - 1               ; Repeat count
    push CENTER_VGA_TXT(BOX_LENGTH)   ; Column
    push LINE_ROW_TOP                 ; Row
    push topline                      ; Address of 3-tuple
    call draw_line

    push RED_BLACK
    push BOX_LENGTH
    push name
    push LINE_ROW_NAME
    push CENTER_VGA_TXT(BOX_LENGTH)
    call PRINT_SEGMENT:PRINT_OFFSET

    push RED_BLACK
    push BOX_LENGTH - 1       ; Repeat count
    push CENTER_VGA_TXT(BOX_LENGTH)   ; Column
    push LINE_ROW_BOTTOM     ; Row
    push bottomline             ; Address of 3-tuple
    call draw_line

    push YELLOW_BLACK
    push ANYKEY_LENGTH
    push anykey
    push LINE_ROW_ANYKEY
    push CENTER_VGA_TXT(ANYKEY_LENGTH)
    call PRINT_SEGMENT:PRINT_OFFSET

    push WHITE_BLACK
    push VGA_TXT_DISP_WIDTH - 1       ; Repeat count
    push 0   ; Column
    push LINE_ROW_ANYKEY + 4          ; Row
    push blockline                    ; Address of 3-tuple
    call draw_line

    call DISPLAY_TIME_SEGMENT:DISPLAY_TIME_OFFSET

    ; Wait for key press
    mov ah, 0x00
    int 0x16

    ; Switch back to text mode (80x25)
    mov ax, 0x0003
    int BIOS_VIDEO

    call CLEAR_SEGMENT:CLEAR_OFFSET

    push MAGENTA_BLACK
    push 1
    push prompt_sym
    push 0
    push 0
    call PRINT_SEGMENT:PRINT_OFFSET

    call SET_CURSOR_SEGMENT:SET_CURSOR_OFFSET
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

draw_line:
    push bp
    mov bp, sp

    ;left edge
    push word [bp + 12]
    push 1
    mov si, [bp + 4]
    push si
    mov si, [bp + 6]
    push si
    mov si, [bp + 8]
    push si
    call PRINT_SEGMENT:PRINT_OFFSET

    ; set up middle loop
    mov ax, 1                           ; break when == to cx
draw_line_middle:
    mov cx, [bp + 10]
    cmp ax, cx
    je draw_line_right
    push ax

    push word [bp + 12]
    push 1
    mov si, [bp + 4]
    inc si
    push si
    mov si, [bp + 6]
    push si
    mov si, [bp + 8]
    add si, ax
    push si
    call PRINT_SEGMENT:PRINT_OFFSET

    pop ax
    inc ax
    jmp draw_line_middle

draw_line_right:
    push word [bp + 12]
    push 1
    mov si, [bp + 4]
    add si, 2
    push si
    mov si, [bp + 6]
    push si
    add ax, [bp + 8]                    ; rightmostposition
    push ax
    call PRINT_SEGMENT:PRINT_OFFSET

    pop bp
    ret 10

set_red_gradient_palette:
    mov dx, 0x3C8   ; VGA color index port
    mov al, 32      ; Start setting colors from index 32
    out dx, al
    inc dx          ; Now dx = 0x3C9 (RGB color data port)

    mov cx, 9       ; 9 shades for 9 rows
    mov si, red_shades
next_color:
    mov al, [si]    ; Load Red intensity
    out dx, al      ; Set Red value
    xor al, al      ; Set Green=0
    out dx, al
    out dx, al      ; Set Blue=0
    inc si
    loop next_color
    ret

topline             db 0xC9
                    db 0xCD
                    db 0xBB
bottomline          db 0xC8
                    db 0xCD
                    db 0xBC
blockline           db 0xDE
                    db 0xDC
                    db 0xDD
welbos              db 0xBA, `    WelbOS v03   `, 0xBA
welboslen           equ ($ - welbos)
name                db 0xBA, `   Welby Seely   `, 0xBA
namelen             equ ($ - name)
anykey              db "Press any key to continue..."
anykeylen           equ ($ - anykey)
prompt_sym          db "$"
red_shades db 58, 55, 50, 45, 40, 35, 30, 25, 20; Bright to dark red
; Row color table, from top to bottom row
row_colors db 32, 33, 34, 35, 36, 37, 38, 39, 40  ; Use only custom red shades
w_bitmap db 02h, 80h
         db 02h, 80h
         db 04h, 40h
         db 04h, 40h
         db 08h, 21h
         db 88h, 22h
         db 50h, 14h
         db 50h, 14h
         db 20h, 08h

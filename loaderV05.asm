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

PRINT_SEGMENT       equ 0
PRINT_OFFSET        equ 0x7c90

LOAD_SECTOR_SEGMENT equ 0
LOAD_SECTOR_OFFSET  equ 0x7d00

DISPLAY_TIME_SEGMENT equ 0x0002
DISPLAY_TIME_OFFSET  equ 0x3456

%define CENTER_TXT(len) ((DISPLAY_WIDTH - len) / 2)
%define CENTER_VGA_TXT(len) ((VGA_TXT_DISP_WIDTH - len) / 2)

org 0x2345
main:
    push ds
    push cs
    pop ds

hide_cursor:
    mov ah, 0x01          ; BIOS Set Cursor Shape function
    mov ch, 0b00001000    ; Start scan line (set bit 5 to hide cursor)
    mov cl, 0x00          ; End scan line (N/A)
    int BIOS_VIDEO        ; BIOS video interrupt

load_time:
    push 1
    push 5
    push 0
    push DISPLAY_TIME_SEGMENT
    push DISPLAY_TIME_OFFSET
    call LOAD_SECTOR_SEGMENT:LOAD_SECTOR_OFFSET

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

show_time:
    call DISPLAY_TIME_SEGMENT:DISPLAY_TIME_OFFSET

    pop ds
    retf

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


topline             db 0xC9
                    db 0xCD
                    db 0xBB
bottomline          db 0xC8
                    db 0xCD
                    db 0xBC
blockline           db 0xDE
                    db 0xDC
                    db 0xDD
welbos              db 0xBA, `    WelbOS v04   `, 0xBA
welboslen           equ ($ - welbos)
name                db 0xBA, `   Welby Seely   `, 0xBA
namelen             equ ($ - name)
anykey              db "Press any key to continue..."
anykeylen           equ ($ - anykey)


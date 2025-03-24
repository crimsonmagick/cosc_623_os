PRINT_SEGMENT       equ 0
PRINT_OFFSET        equ 0x7c90

VGA_TXT_DISP_HEIGHT equ 25
VGA_TXT_DISP_WIDTH  equ 80

MESSAGE_ROW         equ VGA_TXT_DISP_HEIGHT / 2 + 3
LINE_ROW_TOP        equ MESSAGE_ROW - 1
LINE_ROW_NAME       equ MESSAGE_ROW + 1
LINE_ROW_BOTTOM     equ LINE_ROW_NAME + 1
LINE_ROW_ANYKEY     equ LINE_ROW_BOTTOM + 2
LIGHT_RED           equ 0x0C

%macro makedt 4
	mov bh,%1 			;dh/dl/chcl
	shr bh,4
	add bh,30h 			;add 30h to convert to ascii
	mov [%2 + %3],bh
	mov bh,%1
	and bh,0fh
	add bh,30h
	mov [%2 + %4],bh
%endmacro

%define CENTER_VGA_TXT(len) ((VGA_TXT_DISP_WIDTH - len) / 2)

bit16
org 0x3456

    push ds
    push cs
    pop ds

	mov ah,04h	 ;function 04h (get RTC date)
	int 1Ah		;BIOS Interrupt 1Ah (Read Real Time Clock)

	makedt dh, dtfld, 0, 1  ; month
	makedt dl, dtfld, 3, 4  ; day
	makedt ch, dtfld, 6, 7  ; century
	makedt cl, dtfld, 8, 9  ; year

	mov ah,02h
	int 1Ah

	makedt ch, tmfld, 0, 1  ; hours
	makedt cl, tmfld, 3, 4  ; minutes
	makedt dh, tmfld, 6, 7  ; seconds

    push LIGHT_RED
    push 10
    push dtfld
    push LINE_ROW_ANYKEY + 2
    push CENTER_VGA_TXT(10)
    call PRINT_SEGMENT:PRINT_OFFSET

    push LIGHT_RED
    push 8
    push tmfld
    push LINE_ROW_ANYKEY + 3
    push CENTER_VGA_TXT(8)
    call PRINT_SEGMENT:PRINT_OFFSET

	pop ds
	retf

dtfld: db '00/00/0000'
tmfld: db '00:00:00'


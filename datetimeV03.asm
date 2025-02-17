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
	lea ax, [dtfld]
	pop ds
	retf

dtfld: db '00/00/0000'
tmfld: db '00:00:00'


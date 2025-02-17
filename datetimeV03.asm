bit16
org 0x3456

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

%macro	dsp 4
	mov ah,13h		;Function 13h (Display String)
	mov al,0		;Write mode is zero
	mov bh,0		;Use video page of zero
	mov bl,0ah		;Attribute (lightgreen on black)
	mov cx,%1		;Characters in string
	mov dh,%2		;Position on row 1
	mov dl,%3		;and column
	lea bp,%4		;Load the offset address of string
	int 10h
%endmacro

    push ds
    push cs
    pop ds

	mov ah,04h	 ;function 04h (get RTC date)
	int 1Ah		;BIOS Interrupt 1Ah (Read Real Time Clock)

    ;CH - Century
    ;CL - Year
    ;DH - Month
    ;DL - Day

	makedt dh, dtfld, 0, 1
	makedt dl, dtfld, 3, 4
	makedt ch, dtfld, 6, 7
	makedt cl, dtfld, 8, 9
	;dsp 10, 1, 0, [dtfld]

	mov ah,02h
	int 1Ah

    ;CH - Hours
    ;CL - Minutes
    ;DH - Seconds

	makedt ch, tmfld, 0, 1
	makedt cl, tmfld, 3, 4
	makedt dh, tmfld, 6, 7
	;dsp 8, 2, 0, [tmfld]
	lea ax, [dtfld]
	pop ds
	retf

dtfld: db '00/00/0000'
tmfld: db '00:00:00'


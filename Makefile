##################################################
# Makefile of os623V0x.asm (x=[1,2,3])
##################################################

VER			= V02
ASM			= nasm
ASMFLAGS		= -f bin
IMG			= a.img

MBR			=  os623V.asm
MBR_SRC		= $(subst V,$(VER),$(MBR))
MBR_BIN		= $(subst .asm,.bin,$(MBR_SRC))

DATA_SRC	=  loaderV02.asm
DATA_BIN	=  data.bin

DATE_SRC	=  datetimeV03.asm
DATE_BIN	=  date.bin

.PHONY : everything

.PHONY : all everything clean reset blankimg

all: everything

everything : $(MBR_BIN) $(DATA_BIN) $(DATE_BIN)
 ifneq ($(wildcard $(IMG)), )
 else
		dd if=/dev/zero of=$(IMG) bs=512 count=2880
 endif

		dd if=$(MBR_BIN) of=$(IMG) bs=512 count=1 conv=notrunc
		dd if=$(DATA_BIN) of=$(IMG) bs=512 count=1 seek=37 conv=notrunc
		dd if=$(DATE_BIN) of=$(IMG) bs=512 count=1 seek=40 conv=notrunc

$(MBR_BIN) : $(MBR_SRC)
#	nasm -f bin $< -o $@
	$(ASM) $(ASMFLAGS) $< -o $@

$(DATA_BIN) : $(DATA_SRC)
	$(ASM) $(ASMFLAGS) $< -o $@

$(DATE_BIN) : $(DATE_SRC)
	$(ASM) $(ASMFLAGS) $< -o $@

clean :
	rm -f $(MBR_BIN) $(DATA_BIN)

reset:
	rm -f $(MBR_BIN) $(DATA_BIN) $(IMG)

blankimg:
	dd if=/dev/zero of=$(IMG) bs=512 count=2880


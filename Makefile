##################################################
# Makefile of os623V0x.asm (x=[1,2,3])
##################################################

VER			= V01
ASM			= nasm
ASMFLAGS		= -f bin
IMG			= a.img

MBR			=  os623V.asm
MBR_SRC		= $(subst V,$(VER),$(MBR))
MBR_BIN		= $(subst .asm,.bin,$(MBR_SRC))

.PHONY : everything

.PHONY : all everything clean reset blankimg

all: everything

everything : $(MBR_BIN)
 ifneq ($(wildcard $(IMG)), )
 else
		dd if=/dev/zero of=$(IMG) bs=512 count=2880
 endif

		dd if=$(MBR_BIN) of=$(IMG) bs=512 count=1 conv=notrunc

$(MBR_BIN) : $(MBR_SRC)
#	nasm -f bin $< -o $@
	$(ASM) $(ASMFLAGS) $< -o $@

clean :
	rm -f $(MBR_BIN)

reset:
	rm -f $(MBR_BIN) $(IMG)

blankimg:
	dd if=/dev/zero of=$(IMG) bs=512 count=2880


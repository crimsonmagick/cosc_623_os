bits 16

org 0x7e00
topline             db 0xC9
                    db 0xCD
                    db 0xBB
bottomline          db 0xC8
                    db 0xCD
                    db 0xBC
blockline           db 0xDE
                    db 0xDC
                    db 0xDD
welbos              db 0xBA, `    WelbOS v01   `, 0xBA
name                db 0xBA, `   Welby Seely   `, 0xBA
anykey              db "Press any key to continue..."
prompt_sym          db '$'
w_bitmap db 02h, 80h
         db 02h, 80h
         db 04h, 40h
         db 04h, 40h
         db 08h, 21h
         db 88h, 22h
         db 50h, 14h
         db 50h, 14h
         db 20h, 08h
red_shades db 58, 55, 50, 45, 40, 35, 30, 25, 20; Bright to dark red
; Row color table, from top to bottom row
row_colors db 32, 33, 34, 35, 36, 37, 38, 39, 40  ; Use only custom red shades
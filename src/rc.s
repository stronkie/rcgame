;------------------------------------------------------------------------------
;  RC TURBO CUP  -  isometric toy car racing for the Amiga 500.
;
;  Kickstart / Workbench 1.3, 512K chip + 512K trapdoor.  68000 assembly.
;  Created By Mark Stronks, Stronkie Soft (c) 2026
;
;  rc.s    : start-up, display, scrolling, sprites, unpacking, text, input,
;            sound and music, the main loop
;  race.s  : the race: cars, physics, the computer drivers, weapons, pickups,
;            laps, the HUD and the camera
;  menus.s : title, career, shop, results, practice, loading tracks, saving
;
;  Build: sh tools/build.sh
;------------------------------------------------------------------------------

	include	"layout.i"

CUSTOM		equ	$dff000
VIEW_H		equ	216			; the track view; the HUD is below it
TRK_PB		equ	WW/8			; track picture: bytes per plane row
TRK_RB		equ	TRK_PB*5		; ... per row (interleaved)
TRK_SIZE	equ	TRK_RB*WH
HUD_PB		equ	42			; HUD: 336 pixels (the first 16 hidden)
HUD_RB		equ	HUD_PB*5
HUD_SIZE	equ	HUD_RB*HUD_H
SCR_PB		equ	40			; menu screens: 320x256
SCR_RB		equ	SCR_PB*5
SCR_SIZE	equ	SCR_RB*256
SURF_SIZE	equ	SURF_W*SURF_H
SPRBUF		equ	4+CAR_H*4+4		; one sprite buffer: pos, ctl, rows, end
REC_SIZE	equ	128
NRACES		equ	9			; races in a cup (track 10 is the secret one)

; actions (bits in act: presses, and in held: held down)
A_FIRE		equ	0
A_LEFT		equ	1
A_RIGHT		equ	2
A_UP		equ	3
A_DOWN		equ	4
A_ESC		equ	5
A_FIRE2		equ	6
A_SPACE		equ	7
A_RET		equ	8
A_M		equ	9
A_P		equ	10
A_HELP		equ	11
A_DEV		equ	12

_LVOForbid	equ	-132
_LVOPermit	equ	-138
_LVOFindTask	equ	-294
_LVOGetMsg	equ	-372
_LVOReplyMsg	equ	-378
_LVOWaitPort	equ	-384
_LVOCloseLibrary equ	-414
_LVOOpenLibrary	equ	-552
_LVOLoadView	equ	-222
_LVOWaitBlit	equ	-228
_LVOWaitTOF	equ	-270
_LVOOwnBlitter	equ	-456
_LVODisownBlitter equ	-462
_LVOOpen	equ	-30
_LVOClose	equ	-36
_LVORead	equ	-42
_LVOWrite	equ	-48
_LVODelay	equ	-198

	section	code,code

;==============================================================================
;  start-up and shut-down
;==============================================================================
start:
	move.l	sp,stacksave
	move.l	4.w,a6
	sub.l	a1,a1
	jsr	_LVOFindTask(a6)
	move.l	d0,a4
	cmp.l	#'RCTC',d7		; started by the loader: it owns the WB message
	beq.s	.cli
	cmp.l	#'WHDL',d7		; started by the WHDLoad slave (no OS)
	bne.s	.nwhd
	st	whd_mode
	bra.s	.cli
.nwhd	tst.l	172(a4)
	bne.s	.cli
	lea	92(a4),a0
	jsr	_LVOWaitPort(a6)
	lea	92(a4),a0
	jsr	_LVOGetMsg(a6)
	move.l	d0,wbmsg
.cli	lea	gfxname,a1
	moveq	#0,d0
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,gfxbase
	beq	.exit
	lea	dosname,a1
	moveq	#0,d0
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,dosbase
	tst.b	demo_flag
	bne.s	.nrec
	bsr	load_records
.nrec

	move.l	gfxbase,a6
	move.l	34(a6),oldview
	move.l	50(a6),old_lof
	sub.l	a1,a1
	jsr	_LVOLoadView(a6)
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOWaitTOF(a6)
	bsr	hw_takeover

	bsr	game_init
	bsr	main_loop

	bsr	hw_restore
	move.l	gfxbase,a6
	move.l	old_lof,50(a6)
	move.l	oldview,a1
	jsr	_LVOLoadView(a6)
	jsr	_LVOWaitTOF(a6)
	jsr	_LVOWaitTOF(a6)
	move.l	38(a6),CUSTOM+$80
	move.l	4.w,a6
	move.l	dosbase,d0
	beq.s	.nodos
	move.l	d0,a1
	jsr	_LVOCloseLibrary(a6)
.nodos	move.l	gfxbase,a1
	jsr	_LVOCloseLibrary(a6)
.exit	tst.l	wbmsg
	beq.s	.ret
	move.l	4.w,a6
	jsr	_LVOForbid(a6)
	move.l	wbmsg,a1
	jsr	_LVOReplyMsg(a6)
.ret	move.l	stacksave,sp
	moveq	#0,d0
	rts

hw_takeover:
	move.l	gfxbase,a6
	jsr	_LVOOwnBlitter(a6)
	jsr	_LVOWaitBlit(a6)
	move.l	4.w,a6
	jsr	_LVOForbid(a6)
	lea	CUSTOM,a5
	move.w	$1c(a5),old_intena
	move.w	$02(a5),old_dmacon
	move.w	$10(a5),old_adkcon
	move.w	#$7fff,$9a(a5)
	move.w	#$7fff,$9c(a5)
	bsr	wait_vbl
	move.w	#$7fff,$96(a5)
	move.w	#$00ff,$9e(a5)
	moveq	#0,d0
	move.w	d0,$a8(a5)
	move.w	d0,$b8(a5)
	move.w	d0,$c8(a5)
	move.w	d0,$d8(a5)
	lea	$140(a5),a0		; disarm all sprites
	moveq	#7,d1
.spr	move.w	d0,4(a0)
	move.w	d0,6(a0)
	move.w	d0,(a0)
	move.w	d0,2(a0)
	addq.l	#8,a0
	dbf	d1,.spr
	move.w	#$ff00,$34(a5)		; POTGO: the second fire button
	move.l	cur_cop,$80(a5)
	move.w	d0,$88(a5)
	move.w	#$83e0,$96(a5)		; DMA: master, bitplanes, copper, blitter, sprites
	bsr	music_init
	bsr	get_vbr
	move.l	d0,a0
	move.l	$6c(a0),old_irq
	move.l	#vbl_irq,$6c(a0)
	move.w	#$0020,$9c(a5)
	move.w	#$c020,$9a(a5)		; master + vertical blank
	rts

; get_vbr -> d0 = the vector base (0 on a 68000; moved on 68010+ accelerators)
get_vbr:
	movem.l	d1/a5-a6,-(sp)
	moveq	#0,d0
	tst.b	whd_mode
	bne.s	.x
	move.l	4.w,a6
	btst	#0,297(a6)		; AttnFlags: 68010 or better?
	beq.s	.x
	lea	.super,a5
	jsr	-30(a6)			; Supervisor
.x	move.l	d0,vbr
	movem.l	(sp)+,d1/a5-a6
	rts
.super	dc.w	$4e7a,$0801		; movec vbr,d0
	rte

hw_restore:
	bsr	wait_blit
	lea	CUSTOM,a5
	tst.b	whd_mode		; WHDLoad: just switch everything off
	beq.s	.os
	move.w	#$7fff,$9a(a5)
	move.w	#$7fff,$9c(a5)
	move.w	#$7fff,$96(a5)
	moveq	#0,d0
	move.w	d0,$a8(a5)
	move.w	d0,$b8(a5)
	move.w	d0,$c8(a5)
	move.w	d0,$d8(a5)
	rts
.os	move.w	#$7fff,$9a(a5)		; our interrupt off, the old vector back
	move.l	vbr,a0
	move.l	old_irq,$6c(a0)
	bsr	wait_vbl
	move.w	#$7fff,$96(a5)
	move.w	#$7fff,$9a(a5)
	move.w	#$7fff,$9c(a5)
	moveq	#0,d0
	move.w	d0,$a8(a5)
	move.w	d0,$b8(a5)
	move.w	d0,$c8(a5)
	move.w	d0,$d8(a5)
	move.l	gfxbase,a6
	move.l	38(a6),$80(a5)
	move.w	d0,$88(a5)
	move.w	#$7fff,$9e(a5)
	move.w	old_adkcon,d0
	or.w	#$8000,d0
	move.w	d0,$9e(a5)
	move.w	old_dmacon,d0
	or.w	#$8000,d0
	move.w	d0,$96(a5)
	move.w	old_intena,d0
	or.w	#$c000,d0
	move.w	d0,$9a(a5)
	move.l	gfxbase,a6
	jsr	_LVODisownBlitter(a6)
	move.l	4.w,a6
	jsr	_LVOPermit(a6)
	rts

; os_on / os_off: give the machine back to the OS for a disk access, but keep
; our picture on the screen (the graphics interrupt shows gb_LOFlist)
os_on:
	tst.b	whd_mode
	bne.s	.x
	bsr	song_stop
	bsr	hw_restore
	move.l	gfxbase,a6
	move.l	cur_cop,50(a6)
	move.l	cur_cop,CUSTOM+$80
	move.w	#$8380,CUSTOM+$96
.x	rts

os_off:
	tst.b	whd_mode
	bne.s	.x
	move.l	gfxbase,a6
	move.l	old_lof,50(a6)
	bsr	hw_takeover
.x	rts

wait_vbl:
.w1	move.l	CUSTOM+4,d0
	and.l	#$1ff00,d0
	cmp.l	#303<<8,d0
	bne.s	.w1
.w2	move.l	CUSTOM+4,d0
	and.l	#$1ff00,d0
	cmp.l	#303<<8,d0
	beq.s	.w2
	rts

wait_lines:				; d3 = raster lines
	movem.l	d0/d3,-(sp)
	subq.w	#1,d3
.l	move.b	CUSTOM+6,d0
.w	cmp.b	CUSTOM+6,d0
	beq.s	.w
	dbf	d3,.l
	movem.l	(sp)+,d0/d3
	rts

wait_blit:
	tst.b	CUSTOM+2		; (early Agnus: read twice)
.w	btst	#6,CUSTOM+2
	bne.s	.w
	rts

;==============================================================================
;  the display: menu screens (320x256) and the race (scrolling track + HUD)
;==============================================================================
init_display:
	movem.l	d0-d2/a0-a1,-(sp)
	; the sprite pointers in both copper lists: our 8 sprite buffers
	lea	cop_spr,a0
	bsr	.spr
	lea	cr_spr,a0
	bsr.s	.spr
	bsr	hide_sprites
	; menu screen bitplanes
	move.l	#screen,d0
	lea	cop_bpl+2,a0
	moveq	#4,d1
.p	swap	d0
	move.w	d0,(a0)
	swap	d0
	move.w	d0,4(a0)
	addq.l	#8,a0
	add.l	#SCR_PB,d0
	dbf	d1,.p
	; HUD bitplanes
	move.l	#hudbm,d0
	lea	cr_hudbpl+2,a0
	moveq	#4,d1
.h	swap	d0
	move.w	d0,(a0)
	swap	d0
	move.w	d0,4(a0)
	addq.l	#8,a0
	add.l	#HUD_PB,d0
	dbf	d1,.h
	lea	hud_pal,a1
	lea	cr_hudcol,a0
	move.w	#$180,d0
	moveq	#15,d1
.hc	move.w	d0,(a0)+
	move.w	(a1)+,(a0)+
	addq.w	#2,d0
	dbf	d1,.hc
	; colour register numbers
	lea	cop_col,a0
	bsr.s	.cols
	lea	cr_col,a0
	bsr.s	.cols
	movem.l	(sp)+,d0-d2/a0-a1
	rts
.spr	move.w	#$120,d0
	lea	sprbufs,a1
	moveq	#7,d1
.s	move.l	a1,d2
	move.w	d0,(a0)+
	swap	d2
	move.w	d2,(a0)+
	addq.w	#2,d0
	move.w	d0,(a0)+
	swap	d2
	move.w	d2,(a0)+
	addq.w	#2,d0
	lea	SPRBUF(a1),a1
	dbf	d1,.s
	rts
.cols	move.w	#$180,d0
	moveq	#31,d1
.c	move.w	d0,(a0)
	addq.l	#4,a0
	addq.w	#2,d0
	dbf	d1,.c
	rts

; set_menu_pal: a0 = 32 colours for the menu screen
set_menu_pal:
	movem.l	d0/a0-a1,-(sp)
	lea	cop_col+2,a1
	moveq	#31,d0
.c	move.w	(a0)+,(a1)
	addq.l	#4,a1
	dbf	d0,.c
	movem.l	(sp)+,d0/a0-a1
	rts

; menu_black: all menu colours black (before a new picture is unpacked)
menu_black:
	movem.l	d0/a1,-(sp)
	lea	cop_col+2,a1
	moveq	#31,d0
.c	clr.w	(a1)
	addq.l	#4,a1
	dbf	d0,.c
	movem.l	(sp)+,d0/a1
	rts

show_menu_mode:
	move.l	#copperlist,cur_cop
	move.l	#copperlist,CUSTOM+$80
	clr.b	race_mode
	bsr	hide_sprites
	rts

show_race_mode:
	move.l	#cop_race,cur_cop
	move.l	#cop_race,CUSTOM+$80
	st	race_mode
	rts

; set_race_cols: a0 = 16 track colours (0-15); 16-31 from race_shared
set_race_cols:
	movem.l	d0/a0-a1,-(sp)
	lea	cr_col+2,a1
	moveq	#15,d0
.c	move.w	(a0)+,(a1)
	addq.l	#4,a1
	dbf	d0,.c
	lea	race_shared,a0
	moveq	#15,d0
.d	move.w	(a0)+,(a1)
	addq.l	#4,a1
	dbf	d0,.d
	movem.l	(sp)+,d0/a0-a1
	rts

race_black:
	movem.l	d0/a1,-(sp)
	lea	cr_col+2,a1
	moveq	#31,d0
.c	clr.w	(a1)
	addq.l	#4,a1
	dbf	d0,.c
	lea	cr_hudcol+2,a1
	moveq	#15,d0
.d	clr.w	(a1)
	addq.l	#4,a1
	dbf	d0,.d
	movem.l	(sp)+,d0/a1
	rts

hud_colours:
	movem.l	d0/a0-a1,-(sp)
	lea	hud_pal,a0
	lea	cr_hudcol+2,a1
	moveq	#15,d0
.c	move.w	(a0)+,(a1)
	addq.l	#4,a1
	dbf	d0,.c
	movem.l	(sp)+,d0/a0-a1
	rts

; set_scroll: d0 = camera x (16..WW-336), d1 = camera y: bitplane pointers + fine scroll
set_scroll:
	movem.l	d0-d4/a0,-(sp)
	move.w	d0,d2
	and.w	#15,d2			; fine part
	move.w	d0,d3
	subq.w	#1,d3
	asr.w	#4,d3			; first word fetched = (x - 1) >> 4
	add.w	d3,d3
	moveq	#0,d4
	tst.w	d2
	beq.s	.d
	moveq	#16,d4
	sub.w	d2,d4			; delay = 16 - fine
.d	move.w	d4,d2
	lsl.w	#4,d2
	or.w	d4,d2
	move.w	d2,cr_scroll+2
	and.l	#$ffff,d1
	mulu	#TRK_RB,d1
	ext.l	d3
	add.l	d3,d1
	add.l	#trackbm,d1
	lea	cr_bpl+2,a0
	moveq	#4,d2
.p	swap	d1
	move.w	d1,(a0)
	swap	d1
	move.w	d1,4(a0)
	addq.l	#8,a0
	add.l	#TRK_PB,d1
	dbf	d2,.p
	movem.l	(sp)+,d0-d4/a0
	rts

;==============================================================================
;  sprites: 8 buffers in chip memory, the copper lists point at them for good
;==============================================================================
hide_sprites:
	movem.l	d0/a0,-(sp)
	lea	sprbufs,a0
	moveq	#7,d0
.h	clr.l	(a0)
	clr.l	4(a0)
	lea	SPRBUF(a0),a0
	dbf	d0,.h
	movem.l	(sp)+,d0/a0
	rts

hide_sprite:				; d3 = sprite
	movem.l	d3/a0,-(sp)
	mulu	#SPRBUF,d3
	lea	sprbufs,a0
	clr.l	(a0,d3.l)
	movem.l	(sp)+,d3/a0
	rts

; put_car: d3 = car 0..3 (sprites 2*d3 and 2*d3+1, attached: 15 colours),
; a0 = 16 x CAR_H image (8 bytes a row: planes 0, 1, 2, 3), d4 = colour slot 0..3,
; d0 = x, d1 = y in the view (top left), clipped to the track view
put_car:
	movem.l	d0-d7/a0-a2,-(sp)
	move.w	d3,d5
	add.w	d5,d5
	mulu	#SPRBUF,d5
	lea	sprbufs,a1
	add.l	d5,a1			; the even sprite
	lea	SPRBUF(a1),a2		; the odd one
	cmp.w	#-15,d0
	blt	.hide
	cmp.w	#319,d0
	bgt	.hide
	moveq	#CAR_H,d2		; rows
	tst.w	d1
	bpl.s	.t
	add.w	d1,d2			; clip at the top
	ble	.hide
	move.w	d1,d6
	neg.w	d6
	lsl.w	#3,d6
	add.w	d6,a0
	moveq	#0,d1
.t	move.w	d1,d6
	add.w	d2,d6
	sub.w	#VIEW_H,d6		; clip at the bottom
	ble.s	.b
	sub.w	d6,d2
	ble	.hide
.b	add.w	#$2c,d1			; VSTART
	add.w	#$81,d0			; HSTART
	move.w	d1,d3
	add.w	d2,d3			; VSTOP
	move.w	d1,d6
	lsl.w	#8,d6
	move.w	d0,d7
	lsr.w	#1,d7
	and.w	#$ff,d7
	or.w	d7,d6
	move.w	d6,(a1)+		; pos
	move.w	d6,(a2)+
	move.w	d3,d6
	lsl.w	#8,d6
	btst	#8,d1
	beq.s	.n1
	bset	#2,d6
.n1	btst	#8,d3
	beq.s	.n2
	bset	#1,d6
.n2	btst	#0,d0
	beq.s	.n3
	bset	#0,d6
.n3	move.w	d6,(a1)+		; ctl
	bset	#7,d6			; attached
	move.w	d6,(a2)+
	subq.w	#1,d2
.c	move.l	(a0)+,(a1)+		; planes 0 and 1
	move.w	2-4(a0),d5		; plane 1 = the body colour pixels
	move.w	(a0)+,d6		; plane 2
	move.w	(a0)+,d7		; plane 3
	move.w	d5,d3
	not.w	d3
	and.w	d3,d6
	and.w	d3,d7
	btst	#0,d4
	beq.s	.s1
	or.w	d5,d6
.s1	btst	#1,d4
	beq.s	.s2
	or.w	d5,d7
.s2	move.w	d6,(a2)+
	move.w	d7,(a2)+
	dbf	d2,.c
	clr.l	(a1)			; end
	clr.l	(a2)
	bra.s	.x
.hide	clr.l	(a1)
	clr.l	(a2)
.x	movem.l	(sp)+,d0-d7/a0-a2
	rts

;==============================================================================
;  unpacking (tools/lz.py)
;==============================================================================
; unlz: a0 = packed, a1 = destination, d0.l = unpacked size
unlz:
	movem.l	d0-d3/a0-a3,-(sp)
	move.l	a1,a3
	add.l	d0,a3
.loop	cmp.l	a3,a1
	bhs.s	.done
	moveq	#0,d1
	move.b	(a0)+,d1
	bmi.s	.match
.lit	move.b	(a0)+,(a1)+
	dbf	d1,.lit
	bra.s	.loop
.match	cmp.b	#$ff,d1
	bne.s	.short
	moveq	#0,d2
	move.b	(a0)+,d2
	lsl.w	#8,d2
	move.b	(a0)+,d2
	bra.s	.off
.short	and.w	#$7f,d1
	addq.w	#3,d1
	move.w	d1,d2
.off	moveq	#0,d3
	move.b	(a0)+,d3
	lsl.w	#8,d3
	move.b	(a0)+,d3
	move.l	a1,a2
	sub.l	d3,a2
	subq.l	#1,d2
.cp	move.b	(a2)+,(a1)+
	dbf	d2,.cp
	bra.s	.loop
.done	movem.l	(sp)+,d0-d3/a0-a3
	rts

;==============================================================================
;  text: an 8x8 font into the menu screen or the HUD
;==============================================================================
tgt_screen:
	move.l	#screen,txt_base
	move.w	#SCR_RB,txt_rb
	move.w	#SCR_PB,txt_pb
	rts

tgt_hud:
	move.l	#hudbm+2,txt_base	; (column 0 = the first visible byte)
	move.w	#HUD_RB,txt_rb
	move.w	#HUD_PB,txt_pb
	rts

; txt_addr: d0 = x byte, d1 = y -> a1
txt_addr:
	move.l	d1,-(sp)
	and.l	#$ffff,d1
	mulu	txt_rb,d1
	add.w	d0,d1
	move.l	txt_base,a1
	add.l	d1,a1
	move.l	(sp)+,d1
	rts

; draw_text: a0 = string, d0 = x byte, d1 = y, d2 = colour, d3 = background (-1: none)
draw_text:
	movem.l	d0-d7/a0-a4,-(sp)
	bsr	txt_addr
	move.w	txt_pb,a4
.ch	moveq	#0,d4
	move.b	(a0)+,d4
	beq	.x
	cmp.w	#40,d0
	bhs	.x
	sub.w	#32,d4
	bpl.s	.okc
	moveq	#0,d4
.okc	lsl.w	#3,d4
	lea	font8,a2
	add.w	d4,a2
	move.l	a1,a3
	moveq	#7,d5
.row	move.b	(a2)+,d6
	moveq	#0,d7			; plane
.pl	tst.w	d3
	bpl.s	.opq
	move.b	(a3),d4			; transparent: keep the background
	btst	d7,d2
	beq.s	.tc
	or.b	d6,d4
	bra.s	.tw
.tc	move.b	d6,-(sp)
	not.b	(sp)
	and.b	(sp)+,d4
.tw	move.b	d4,(a3)
	bra.s	.np
.opq	moveq	#0,d4
	btst	d7,d2
	beq.s	.nf
	move.b	d6,d4
.nf	btst	d7,d3
	beq.s	.nb
	move.b	d6,-(sp)
	not.b	(sp)
	or.b	(sp)+,d4
.nb	move.b	d4,(a3)
.np	add.w	a4,a3
	addq.w	#1,d7
	cmp.w	#5,d7
	blo.s	.pl
	dbf	d5,.row
	addq.l	#1,a1
	addq.w	#1,d0
	bra	.ch
.x	movem.l	(sp)+,d0-d7/a0-a4
	rts

; draw_ctext: a0 = string centred on 40 columns, d1 = y, d2 = colour, d3 = background
draw_ctext:
	movem.l	d0/a1,-(sp)
	move.l	a0,a1
	moveq	#0,d0
.l	tst.b	(a1)+
	beq.s	.e
	addq.w	#1,d0
	bra.s	.l
.e	neg.w	d0
	add.w	#40,d0
	asr.w	#1,d0
	bpl.s	.ok
	moveq	#0,d0
.ok	bsr	draw_text
	movem.l	(sp)+,d0/a1
	rts

; fill_rect: d0 = x byte, d1 = y, d2 = width in bytes, d3 = height, d4 = colour
fill_rect:
	movem.l	d0-d7/a0-a2,-(sp)
	bsr	txt_addr
	subq.w	#1,d3
.row	moveq	#0,d5
	move.l	a1,a2
.pl	moveq	#0,d6
	btst	d5,d4
	beq.s	.z
	moveq	#-1,d6
.z	move.w	d2,d7
	subq.w	#1,d7
	move.l	a2,a0
.b	move.b	d6,(a0)+
	dbf	d7,.b
	add.w	txt_pb,a2
	addq.w	#1,d5
	cmp.w	#5,d5
	blo.s	.pl
	add.w	txt_rb,a1
	dbf	d3,.row
	movem.l	(sp)+,d0-d7/a0-a2
	rts

; strings: str_start, str_add (a0), str_char (d0), str_dec (d0.l), str_dec2 (d0 0-99), str_end
str_start:
	lea	strbuf,a1
	rts
str_add:
.l	move.b	(a0)+,(a1)+
	bne.s	.l
	subq.l	#1,a1
	rts
str_char:
	move.b	d0,(a1)+
	rts
str_end:
	clr.b	(a1)
	lea	strbuf,a0
	rts
str_dec:				; d0.l unsigned, no leading zeros
	movem.l	d0-d2/a0,-(sp)
	lea	numbuf+12,a0
	clr.b	-(a0)
.l	move.l	d0,d1
	clr.w	d1
	swap	d1			; high word
	divu	#10,d1
	move.w	d1,d2			; quotient of the high word
	move.w	d0,d1			; remainder:low word
	divu	#10,d1
	swap	d2
	move.w	d1,d2			; the whole quotient
	swap	d1
	add.b	#'0',d1
	move.b	d1,-(a0)
	move.l	d2,d0
	bne.s	.l
.c	move.b	(a0)+,(a1)+
	bne.s	.c
	subq.l	#1,a1
	movem.l	(sp)+,d0-d2/a0
	rts
str_dec2:				; two digits
	movem.l	d0-d1,-(sp)
	and.l	#$ffff,d0
	divu	#10,d0
	add.b	#'0',d0
	move.b	d0,(a1)+
	swap	d0
	add.b	#'0',d0
	move.b	d0,(a1)+
	movem.l	(sp)+,d0-d1
	rts
; str_time: d0.l = race steps (25 a second) -> M:SS.CC
str_time:
	movem.l	d0-d2,-(sp)
	and.l	#$ffff,d0
	divu	#25,d0			; seconds, remainder steps
	move.l	d0,d2
	swap	d2			; steps 0..24 -> hundredths
	mulu	#4,d2
	and.l	#$ffff,d0
	divu	#60,d0
	move.w	d0,d1			; minutes
	swap	d0			; seconds
	move.w	d0,-(sp)
	moveq	#0,d0
	move.w	d1,d0
	bsr	str_dec
	moveq	#':',d0
	bsr	str_char
	move.w	(sp)+,d0
	bsr	str_dec2
	moveq	#'.',d0
	bsr	str_char
	move.w	d2,d0
	bsr	str_dec2
	movem.l	(sp)+,d0-d2
	rts

;==============================================================================
;  input: joystick in port 2 (and its second button), the keyboard
;==============================================================================
read_input:
	moveq	#0,d0
	move.w	CUSTOM+$00c,d1		; joystick in port 2
	btst	#1,d1
	beq.s	.nr
	bset	#A_RIGHT,d0
.nr	btst	#9,d1
	beq.s	.nl
	bset	#A_LEFT,d0
.nl	move.w	d1,d2
	lsr.w	#1,d2
	eor.w	d1,d2
	btst	#0,d2
	beq.s	.nd
	bset	#A_DOWN,d0
.nd	btst	#8,d2
	beq.s	.nu
	bset	#A_UP,d0
.nu	btst	#7,$bfe001
	bne.s	.nf
	bset	#A_FIRE,d0
.nf	btst	#6,CUSTOM+$016		; POTINP bit 14: second button, port 2
	bne.s	.nf2
	bset	#A_FIRE2,d0
.nf2	; the keyboard: presses and held keys
	clr.b	i_key
	moveq	#3,d6
.kb	move.b	$bfed01,d1
	btst	#3,d1
	beq	.kdone
	move.b	$bfec01,d2
	bset	#6,$bfee01
	moveq	#3,d3
	bsr	wait_lines
	bclr	#6,$bfee01
	not.b	d2
	ror.b	#1,d2
	move.b	d2,d5			; bit 7: released
	and.w	#$7f,d2
	tst.b	d5
	bmi.s	.up
	move.b	d2,i_key
	cmp.b	#$59,d2			; WHDLoad: F10 quits to Workbench
	bne.s	.up
	tst.b	whd_mode
	beq.s	.up
	st	quit
.up	lea	keymap,a0
.km	move.b	(a0)+,d3
	bmi.s	.knext
	move.b	(a0)+,d4
	cmp.b	d2,d3
	bne.s	.km
	tst.b	d5
	bmi.s	.rel
	move.w	key_held,d3
	bset	d4,d3
	move.w	d3,key_held
	bset	d4,d0			; (a press shows as held this frame too)
	bra.s	.km
.rel	move.w	key_held,d3
	bclr	d4,d3
	move.w	d3,key_held
	bra.s	.km
.knext	dbf	d6,.kb
.kdone	or.w	key_held,d0
	move.w	d0,joy_now
	move.w	joy_prev,d1
	move.w	d0,joy_prev
	not.w	d1
	and.w	d1,d0			; new presses
	move.w	d0,i_act
	rts

;==============================================================================
;  random numbers
;==============================================================================
random:
	movem.l	d1-d2,-(sp)
	move.l	seed,d0
	move.l	d0,d1
	moveq	#13,d2
	lsl.l	d2,d1
	eor.l	d1,d0
	move.l	d0,d1
	moveq	#17,d2
	lsr.l	d2,d1
	eor.l	d1,d0
	move.l	d0,d1
	lsl.l	#5,d1
	eor.l	d1,d0
	move.l	d0,seed
	movem.l	(sp)+,d1-d2
	rts

rand_n:					; d0.w = n -> d0.l = 0..n-1
	move.l	d3,-(sp)
	move.w	d0,d3
	bsr	random
	swap	d0
	mulu	d3,d0
	clr.w	d0
	swap	d0
	move.l	(sp)+,d3
	rts

;==============================================================================
;  sound: music on channels 0 (lead) and 1 (bass), the motor on 2, effects on 3
;==============================================================================
music_init:
	movem.l	d0/a5,-(sp)
	lea	CUSTOM,a5
	move.l	#inst_lead,$a0(a5)
	move.w	#16,$a4(a5)
	move.w	#400,$a6(a5)
	clr.w	$a8(a5)
	move.l	#inst_bass,$b0(a5)
	move.w	#16,$b4(a5)
	move.w	#400,$b6(a5)
	clr.w	$b8(a5)
	move.l	#inst_engine,$c0(a5)
	move.w	#16,$c4(a5)
	move.w	#600,$c6(a5)
	clr.w	$c8(a5)
	move.w	#$8207,$96(a5)		; the instruments loop for ever
	clr.l	mus_ptr
	clr.l	mus_ptr+4
	clr.w	eng_vol
	movem.l	(sp)+,d0/a5
	rts

; play_song: d0 = song number (SONG_x), d1 = volume
play_song:
	movem.l	d0-d1/a0-a1,-(sp)
	cmp.w	cur_song,d0
	bne.s	.new
	tst.l	mus_ptr
	bne.s	.x
.new	move.w	d0,cur_song
	lsl.w	#3,d0
	lea	song_table,a0
	move.l	(a0,d0.w),a1
	move.l	4(a0,d0.w),a0
	exg	a0,a1
	move.w	#$4000,CUSTOM+$9a
	move.w	d1,mus_max
	move.w	d1,d0
	lsr.w	#2,d0
	move.w	d0,mus_floor
	move.l	a0,mus_ptr
	move.l	a1,mus_ptr+4
	move.l	a0,mus_start
	move.l	a1,mus_start+4
	move.w	#1,mus_left
	move.w	#1,mus_left+2
	move.w	#$c000,CUSTOM+$9a
.x	movem.l	(sp)+,d0-d1/a0-a1
	rts

song_stop:
	clr.l	mus_ptr
	clr.l	mus_ptr+4
	move.w	#-1,cur_song
	clr.w	CUSTOM+$a8
	clr.w	CUSTOM+$b8
	clr.w	eng_vol
	clr.w	CUSTOM+$c8
	rts

sfx:					; d0 = sound number
	movem.l	d0/a0,-(sp)
	lea	snd_table,a0
	lsl.w	#3,d0
	add.w	d0,a0
	move.l	a0,sfx_reqp
	move.b	#1,sfx_st
	movem.l	(sp)+,d0/a0
	rts

sound_tick:
	movem.l	d0-d3/a0-a1/a5,-(sp)
	lea	CUSTOM+$a0,a5
	; the effect on channel 3
	move.b	sfx_st,d2
	beq.s	.pn
	cmp.b	#1,d2
	bne.s	.p2
	move.w	#$0008,CUSTOM+$96	; 1: channel off, new sample in
	move.l	sfx_reqp,a1
	move.l	(a1)+,$30(a5)
	move.w	(a1)+,$34(a5)
	move.w	(a1)+,$36(a5)
	move.w	#64,$38(a5)
	move.b	#2,sfx_st
	bra.s	.pn
.p2	cmp.b	#2,d2
	bne.s	.p3
	move.w	#$8208,CUSTOM+$96	; 2: channel on
	move.b	#3,sfx_st
	bra.s	.pn
.p3	move.l	#snd_null,$30(a5)	; 3: after the sample, loop silence
	move.w	#2,$34(a5)
	clr.b	sfx_st
.pn	; the motor on channel 2
	move.w	eng_per,$26(a5)
	move.w	eng_vol,$28(a5)
	; the music channels
	moveq	#0,d1
.ch	move.w	d1,d0
	lsl.w	#2,d0
	lea	mus_ptr,a0
	move.l	(a0,d0.w),d2
	beq	.next
	move.l	d2,a1
	move.w	d1,d3
	add.w	d3,d3
	lea	mus_left,a0
	subq.w	#1,(a0,d3.w)
	bne.s	.decay
.note	move.w	(a1)+,d2		; period
	cmp.w	#$fffe,d2
	blo.s	.play
	beq.s	.end
	lea	mus_start,a0		; loop
	move.l	(a0,d0.w),a1
	bra.s	.note
.end	lea	mus_ptr,a0
	clr.l	(a0,d0.w)
	move.w	d1,d0
	lsl.w	#4,d0
	clr.w	8(a5,d0.w)
	bra.s	.next
.play	move.w	(a1)+,d3
	lea	mus_ptr,a0
	move.l	a1,(a0,d0.w)
	move.w	d1,d0
	add.w	d0,d0
	lea	mus_left,a0
	move.w	d3,(a0,d0.w)
	lea	mus_vol,a0
	move.w	mus_max,(a0,d0.w)
	tst.w	d2
	bne.s	.per
	clr.w	(a0,d0.w)		; rest
	bra.s	.setv
.per	move.w	d1,d3
	lsl.w	#4,d3
	move.w	d2,6(a5,d3.w)
	bra.s	.setv
.decay	lea	mus_vol,a0
	move.w	mus_floor,d2
	cmp.w	(a0,d3.w),d2
	bhs.s	.setv0
	subq.w	#1,(a0,d3.w)
.setv0	move.w	d3,d0
.setv	move.w	d1,d3
	add.w	d3,d3
	lea	mus_vol,a0
	move.w	(a0,d3.w),d2
	tst.b	music_on
	bne.s	.on
	moveq	#0,d2
.on	lsl.w	#3,d3
	move.w	d2,8(a5,d3.w)
.next	addq.w	#1,d1
	cmp.w	#2,d1
	blo	.ch
	movem.l	(sp)+,d0-d3/a0-a1/a5
	rts

;==============================================================================
;  the main loop
;==============================================================================
main_loop:
.loop	bsr	wait_frame
	move.w	d0,elapsed
	bsr	take_input
	move.w	act,d7
	btst	#A_M,d7
	beq.s	.nom
	not.b	music_on
	bsr	music_changed
.nom	move.l	state,a0
	jsr	(a0)
	tst.b	quit
	beq.s	.loop
	rts

; wait_frame -> d0 = frames since the last call (1..4), counted by the interrupt
wait_frame:
	move.l	last_fc,d1
.w	move.l	framecount,d0
	cmp.l	d1,d0
	beq.s	.w
	move.l	d0,last_fc
	sub.l	d1,d0
	cmp.l	#4,d0
	bls.s	.ok
	moveq	#4,d0
.ok	rts

; take_input: what the interrupt collected since the last pass
take_input:
	move.w	#$4000,CUSTOM+$9a
	move.w	acc_act,act
	clr.w	acc_act
	move.b	acc_key,key_last
	clr.b	acc_key
	move.w	joy_now,held
	move.w	#$c000,CUSTOM+$9a
	rts

; the vertical blank interrupt: input, sound, music
vbl_irq:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	CUSTOM,a5
	move.w	#$0020,$9c(a5)
	move.w	#$0020,$9c(a5)
	addq.l	#1,framecount
	bsr	sound_tick
	bsr	read_input
	move.w	i_act,d0
	or.w	d0,acc_act
	move.b	i_key,d0
	beq.s	.nk
	move.b	d0,acc_key
.nk	movem.l	(sp)+,d0-d7/a0-a6
	rte

set_state:				; a0 = the new state
	move.l	a0,state
	clr.w	state_timer
	rts

	include	"race.s"
	include	"menus.s"

;==============================================================================
;  data
;==============================================================================
	section	data,data

gfxname		dc.b	'graphics.library',0
dosname		dc.b	'dos.library',0
recname		dc.b	'RCTurbo.dat',0
demo_flag	dc.b	DEMO
	even
; keyboard: raw key code, action
keymap		dc.b	$40,A_SPACE,$44,A_RET,$43,A_RET
		dc.b	$4f,A_LEFT,$4e,A_RIGHT,$4c,A_UP,$4d,A_DOWN
		dc.b	$45,A_ESC,$37,A_M,$19,A_P,$5f,A_HELP,$64,A_FIRE2,$65,A_FIRE2
		dc.b	-1
	even

	include	"gfx.i"
	include	"tracks.i"
	include	"strings.s"

;==============================================================================
	section	chip,data_c
copperlist				; the menu screens
	dc.w	$008e,$2c81,$0090,$2cc1,$0092,$0038,$0094,$00d0
	dc.w	$0100,$5200,$0102,$0000,$0104,$0024
	dc.w	$0108,SCR_RB-SCR_PB,$010a,SCR_RB-SCR_PB
cop_spr	ds.w	8*4
cop_bpl	dc.w	$00e0,0,$00e2,0,$00e4,0,$00e6,0,$00e8,0,$00ea,0
	dc.w	$00ec,0,$00ee,0,$00f0,0,$00f2,0
cop_col	ds.w	32*2
	dc.w	$ffff,$fffe

cop_race				; the race: the scrolling track, then the HUD
	dc.w	$008e,$2c81,$0090,$2cc1,$0092,$0030,$0094,$00d0
	dc.w	$0100,$5200
cr_scroll
	dc.w	$0102,$0000,$0104,$0024
	dc.w	$0108,TRK_RB-42,$010a,TRK_RB-42
cr_spr	ds.w	8*4
cr_bpl	dc.w	$00e0,0,$00e2,0,$00e4,0,$00e6,0,$00e8,0,$00ea,0
	dc.w	$00ec,0,$00ee,0,$00f0,0,$00f2,0
cr_col	ds.w	32*2
	dc.w	$ffdf,$fffe		; past line 255
	dc.w	$03d9,$fffe		; the end of line 259: the HUD starts on 260
cr_hudbpl
	dc.w	$00e0,0,$00e2,0,$00e4,0,$00e6,0,$00e8,0,$00ea,0
	dc.w	$00ec,0,$00ee,0,$00f0,0,$00f2,0
	dc.w	$0102,$0000,$0108,HUD_RB-42,$010a,HUD_RB-42
cr_hudcol
	ds.w	16*2
	dc.w	$ffff,$fffe

;==============================================================================
	section	vars,bss
stacksave	ds.l	1
wbmsg		ds.l	1
gfxbase		ds.l	1
dosbase		ds.l	1
oldview		ds.l	1
old_lof		ds.l	1
vbr		ds.l	1
old_irq		ds.l	1
last_fc		ds.l	1
framecount	ds.l	1
seed		ds.l	1
state		ds.l	1
cur_cop		ds.l	1
txt_base	ds.l	1
sfx_reqp	ds.l	1
mus_ptr		ds.l	2
mus_start	ds.l	2
txt_rb		ds.w	1
txt_pb		ds.w	1
old_intena	ds.w	1
old_dmacon	ds.w	1
old_adkcon	ds.w	1
mus_left	ds.w	2
mus_vol		ds.w	2
mus_max		ds.w	1
mus_floor	ds.w	1
cur_song	ds.w	1
eng_per		ds.w	1
eng_vol		ds.w	1
act		ds.w	1
held		ds.w	1
acc_act		ds.w	1
i_act		ds.w	1
joy_now		ds.w	1
joy_prev	ds.w	1
key_held	ds.w	1
i_kpress	ds.w	1
elapsed		ds.w	1
state_timer	ds.w	1
sfx_st		ds.b	1
music_on	ds.b	1
quit		ds.b	1
whd_mode	ds.b	1
race_mode	ds.b	1
acc_key		ds.b	1
i_key		ds.b	1
key_last	ds.b	1
numbuf		ds.b	12
strbuf		ds.b	80
	even
	include	"vars.s"

	section	scr,bss_c
trackbm		ds.b	TRK_SIZE		; the track picture (and the menu screen)
screen		equ	trackbm
hudbm		ds.b	HUD_SIZE+16
sprbufs		ds.b	SPRBUF*8

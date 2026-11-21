;==============================================================================
;  retro.s - the STRONKIE POCKET: the race on a little handheld with a
;  4 shade LCD.  Dual playfield: playfield 1 (planes 1, 3, 5) is the handheld
;  (colours 1-7, 0 lets the LCD through), playfield 2 (planes 2, 4) the track
;  in 4 shades (colours 0, 9, 10, 11), the cars are sprites in LCD greens.
;==============================================================================

RS_H		equ	16			; the conversion works in strips of 16 lines
RS_T		equ	40*2*RS_H		; one strip of one plane (bytes)

; retro_convert: after race_palette - the shade table, the handheld picture,
; and the track picture turned into 2 planes of shades (planes 1 and 3)
retro_convert:
	movem.l	d0-d7/a0-a6,-(sp)
	bsr	retro_lut
	lea	pocket_lz,a0
	lea	pocketbm,a1
	move.l	#POCKET_RAW,d0
	bsr	unlz
	; the minterms: for each output plane (k) and each of the 4 (plane 3, plane 4)
	; quarters, which of the 8 colours of planes 0-2 have bit k of their shade
	lea	retro_mt,a1
	moveq	#0,d7			; k
.mk	moveq	#0,d6			; quarter
.mq	moveq	#0,d0			; the minterm
	moveq	#7,d5
.mb	move.w	d6,d1
	lsl.w	#3,d1
	add.w	d5,d1
	lea	retro_tab,a0
	move.b	(a0,d1.w),d2
	btst	d7,d2
	beq.s	.m0
	bset	d5,d0
.m0	dbf	d5,.mb
	move.b	d0,(a1)+
	addq.w	#1,d6
	cmp.w	#4,d6
	blo.s	.mq
	addq.w	#1,d7
	cmp.w	#2,d7
	blo.s	.mk
	; the blitter, strip by strip
	lea	CUSTOM,a5
	lea	trackbm,a4		; the strip in the track picture
	moveq	#512/RS_H-1,d7
.strip	lea	retro_mt,a3
	lea	ovl_img+RS_T*4,a6	; the result for k = 0, then k = 1
	moveq	#1,d6
.k	; T0..T3 = f(plane 2, plane 1, plane 0) for each quarter
	lea	ovl_img,a2
	moveq	#3,d5
.q	bsr	wait_blit
	moveq	#0,d0
	move.b	(a3)+,d0
	or.w	#$0f00,d0
	move.w	d0,$40(a5)
	clr.w	$42(a5)
	move.l	#-1,$44(a5)
	lea	TRK_PB*2(a4),a0
	move.l	a0,$50(a5)		; A = plane 2
	lea	TRK_PB(a4),a0
	move.l	a0,$4c(a5)		; B = plane 1
	move.l	a4,$48(a5)		; C = plane 0
	move.l	a2,$54(a5)
	move.w	#TRK_RB-80,$64(a5)
	move.w	#TRK_RB-80,$62(a5)
	move.w	#TRK_RB-80,$60(a5)
	clr.w	$66(a5)
	move.w	#RS_H<<6|40,$58(a5)
	lea	RS_T(a2),a2
	dbf	d5,.q
	; plane 3 picks T0/T1 and T2/T3, plane 4 picks between those
	lea	TRK_PB*3(a4),a0
	lea	ovl_img+RS_T,a1
	lea	ovl_img,a2
	move.l	a2,d0
	bsr	.mux			; T0 = plane 3 ? T1 : T0
	lea	ovl_img+RS_T*3,a1
	lea	ovl_img+RS_T*2,a2
	move.l	a2,d0
	bsr	.mux			; T2 = plane 3 ? T3 : T2
	lea	TRK_PB*4(a4),a0
	lea	ovl_img+RS_T*2,a1
	lea	ovl_img,a2
	move.l	a6,d0
	bsr	.mux			; result = plane 4 ? T2 : T0
	lea	RS_T(a6),a6
	dbf	d6,.k
	; the results into planes 1 and 3
	lea	ovl_img+RS_T*4,a0
	lea	TRK_PB(a4),a1
	bsr	.copy
	lea	ovl_img+RS_T*5,a0
	lea	TRK_PB*3(a4),a1
	bsr	.copy
	lea	TRK_RB*RS_H(a4),a4
	dbf	d7,.strip
	bsr	wait_blit
	move.w	#-1,ovl_built		; (the overlay buffers were used)
	; the colours
	bsr	retro_colours
	movem.l	(sp)+,d0-d7/a0-a6
	rts
; .mux: d0 = destination = a0 (a track plane) ? a1 : a2
.mux	bsr	wait_blit
	move.w	#$0fca,$40(a5)
	clr.w	$42(a5)
	move.l	#-1,$44(a5)
	move.l	a0,$50(a5)
	move.l	a1,$4c(a5)
	move.l	a2,$48(a5)
	move.l	d0,$54(a5)
	move.w	#TRK_RB-80,$64(a5)
	clr.w	$62(a5)
	clr.w	$60(a5)
	clr.w	$66(a5)
	move.w	#RS_H<<6|40,$58(a5)
	rts
; .copy: a0 (a strip) -> a1 (a track plane)
.copy	bsr	wait_blit
	move.w	#$09f0,$40(a5)
	clr.w	$42(a5)
	move.l	#-1,$44(a5)
	move.l	a0,$50(a5)
	move.l	a1,$54(a5)
	clr.w	$64(a5)
	move.w	#TRK_RB-80,$66(a5)
	move.w	#RS_H<<6|40,$58(a5)
	rts

; retro_lut: retro_tab = the shade (0 light .. 3 dark) of colours 0-31.
; Simple, like a handheld: every track uses the same 16 roles (tools/tracks.py),
; so the ground is one flat light grey, the road white, the walls and the
; props keep 3 shades for their shape, outlines black.
retro_lut:
	movem.l	d0/a0-a1,-(sp)
	lea	.tab(pc),a0
	lea	retro_tab,a1
	moveq	#31,d0
.c	move.b	(a0)+,(a1)+
	dbf	d0,.c
	movem.l	(sp)+,d0/a0-a1
	rts
;		G0 G1 G2 RD RM RL W0 W1 W2 P0 P1 P2 PA WA0 WA1 SA
.tab	dc.b	1,1,1,0,0,0,3,2,1,3,2,1,2,2,1,1
;		black outline car car white glass ... red fx ... yellow light-glass ...
	dc.b	3,3,2,1,0,2,2,1,2,2,2,1,1,1,2,1
	even

; retro_colours: retro_cols = the 32 colours of the race in the handheld
retro_colours:
	movem.l	d0-d1/a0-a2,-(sp)
	lea	retro_cols,a1
	lea	lcd_shades,a2
	move.w	(a2),(a1)+		; 0: the lightest shade (the LCD)
	lea	pocket_pal+2,a0		; 1-7: the handheld
	moveq	#6,d0
.p	move.w	(a0)+,(a1)+
	dbf	d0,.p
	move.w	(a2),(a1)+		; 8: (clear)
	move.w	2(a2),(a1)+		; 9, 10, 11: the shades
	move.w	4(a2),(a1)+
	move.w	6(a2),(a1)+
	moveq	#3,d0
.u	move.w	(a2),(a1)+		; 12-15: not used
	dbf	d0,.u
	lea	retro_tab+16,a0		; 16-31: the sprites in shades
	moveq	#15,d0
.s	moveq	#0,d1
	move.b	(a0)+,d1
	add.w	d1,d1
	move.w	(a2,d1.w),(a1)+
	dbf	d0,.s
	movem.l	(sp)+,d0-d1/a0-a2
	rts

; race_display: the copper list for the normal or the handheld race screen
race_display:
	tst.b	r_retro
	bne.s	.r
	move.w	#$5200,cr_scroll-2
	move.w	#$0024,cr_scroll+6
	move.w	#TRK_RB-42,cr_scroll+10
	rts
.r	move.w	#$5600,cr_scroll-2	; dual playfield
	move.w	#$0020,cr_scroll+6	; the handheld over the cars, the cars over the track
	move.w	#42*3-42,cr_scroll+10	; (playfield 1: the handheld picture)
	rts

; retro_race_cols: the handheld's colours in the copper list
retro_race_cols:
	movem.l	d0/a0-a1,-(sp)
	lea	retro_cols,a0
	lea	cr_col+2,a1
	moveq	#31,d0
.c	move.w	(a0)+,(a1)
	addq.l	#4,a1
	dbf	d0,.c
	lea	hud_retro,a0
	lea	cr_hudcol+2,a1
	moveq	#15,d0
.h	move.w	(a0)+,(a1)
	addq.l	#4,a1
	dbf	d0,.h
	movem.l	(sp)+,d0/a0-a1
	rts

; retro_ovl: d0 = a colour (16-31) -> the colour that shows its shade in playfield 2
retro_ovl:
	movem.l	a0,-(sp)
	lea	retro_tab,a0
	move.b	(a0,d0.w),d0
	and.w	#3,d0
	move.b	.idx(pc,d0.w),d0
	movem.l	(sp)+,a0
	rts
.idx	dc.b	0,2,8,10

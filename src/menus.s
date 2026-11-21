;==============================================================================
;  menus.s - title, career, cup intro, results, shop, cups, practice,
;  loading the tracks and saving the career
;==============================================================================

game_init:
	move.l	#$5a17c3e1,d0
	add.l	CUSTOM+4,d0
	move.l	d0,seed
	st	music_on
	move.w	#-1,cur_song
	move.w	#-1,loaded_track
	lea	ovl_lz,a0		; the overlay pictures
	lea	ovl_buf,a1
	move.l	#OVL_RAW,d0
	bsr	unlz
	bsr	init_display
	lea	st_title_in,a0
	bra	set_state

music_changed:
	rts

;------------------------------------------------------------------------------
; helpers
;------------------------------------------------------------------------------
show_menu_bg:
	movem.l	d0/a0-a1,-(sp)
	bsr	show_menu_mode
	bsr	menu_black
	lea	menu_lz,a0
	lea	screen,a1
	move.l	#SCR_SIZE,d0
	bsr	unlz
	lea	menu_pal,a0
	bsr	set_menu_pal
	bsr	tgt_screen
	movem.l	(sp)+,d0/a0-a1
	rts

; mtext: a0 = text, d0 = column, d1 = y, d2 = colour (no background)
mtext:
	move.l	d3,-(sp)
	moveq	#-1,d3
	bsr	draw_text
	move.l	(sp)+,d3
	rts
mctext:
	move.l	d3,-(sp)
	moveq	#-1,d3
	bsr	draw_ctext
	move.l	(sp)+,d3
	rts

; header: a0 = title text under the logo strip
header:
	movem.l	d1-d2,-(sp)
	moveq	#46,d1
	moveq	#M_YELLOW,d2
	bsr	mctext
	movem.l	(sp)+,d1-d2
	rts

; bar: d0 = column, d1 = y, d4 = level 0..5 (five blocks)
bar5:
	movem.l	d0-d5/a0-a1,-(sp)
	lea	strbuf,a1
	moveq	#0,d5
.l	moveq	#'[',d2
	cmp.w	d4,d5
	blt.s	.f
	moveq	#'@',d2
.f	move.b	d2,(a1)+
	addq.w	#1,d5
	cmp.w	#5,d5
	blo.s	.l
	clr.b	(a1)
	lea	strbuf,a0
	moveq	#M_GREEN,d2
	bsr	mtext
	movem.l	(sp)+,d0-d5/a0-a1
	rts

; menu_keys: up/down move menu_sel in 0..menu_n-1 -> d0 = 1 if it moved
menu_keys:
	moveq	#0,d0
	move.w	act,d1
	btst	#A_UP,d1
	beq.s	.nu
	subq.w	#1,menu_sel
	bpl.s	.m
	move.w	menu_n,menu_sel
	subq.w	#1,menu_sel
	bra.s	.m
.nu	btst	#A_DOWN,d1
	beq.s	.x
	addq.w	#1,menu_sel
	move.w	menu_sel,d1
	cmp.w	menu_n,d1
	blo.s	.m
	clr.w	menu_sel
.m	moveq	#S_CLICK,d0
	bsr	sfx
	moveq	#1,d0
.x	rts

fire_pressed:				; -> Z clear when fire / return / space
	move.w	act,d0
	and.w	#(1<<A_FIRE)|(1<<A_RET)|(1<<A_SPACE)|(1<<A_FIRE2),d0
	rts

;------------------------------------------------------------------------------
; the title screen and its menu
;------------------------------------------------------------------------------
st_title_in:
	bsr	show_menu_mode
	bsr	menu_black
	lea	title_lz,a0
	lea	screen,a1
	move.l	#SCR_SIZE,d0
	bsr	unlz
	lea	title_pal,a0
	bsr	set_menu_pal
	lea	shared_pal,a0		; the car lane: the car colours
	lea	cop_fx+COP_STRIP1+2,a1
	moveq	#15,d0
.lc	move.w	(a0)+,(a1)
	addq.l	#4,a1
	dbf	d0,.lc
	bsr	title_cars_init
	bsr	tgt_screen
	moveq	#SONG_TITLE,d0
	moveq	#48,d1
	bsr	play_song
	tst.b	said_title
	bne.s	.s
	st	said_title
	moveq	#S_V_TITLE,d0
	bsr	sfx
.s	clr.w	menu_sel
	move.w	#6,menu_n
	bsr	draw_title_menu
	lea	st_title,a0
	bra	set_state

; the title: toy cars racing across, the logo wobbling on the beat
TCAR_DIR	equ	14			; facing right on the screen
title_cars_init:
	movem.l	d0-d1/a0,-(sp)
	lea	tcars,a0
	moveq	#3,d1
.c	bsr	title_car_new
	move.w	d1,d0			; spread out at the start
	mulu	#80*16,d0
	add.w	#20*16,d0
	neg.w	d0
	move.w	d0,(a0)
	lea	6(a0),a0
	dbf	d1,.c
	clr.w	wob_amp
	movem.l	(sp)+,d0-d1/a0
	rts

title_car_new:				; a0 = car: x (1/16 px), speed, design
	move.l	d0,-(sp)
	moveq	#120,d0
	bsr	rand_n
	add.w	#40,d0
	lsl.w	#4,d0
	neg.w	d0
	move.w	d0,(a0)
	moveq	#40,d0
	bsr	rand_n
	add.w	#36,d0
	move.w	d0,2(a0)
	moveq	#5,d0
	bsr	rand_n
	move.w	d0,4(a0)
	move.l	(sp)+,d0
	rts

title_anim:
	movem.l	d0-d7/a0-a2,-(sp)
	lea	tcars,a2
	moveq	#0,d7
.car	move.w	2(a2),d0
	move.w	elapsed,d1
	beq.s	.e
	mulu	d1,d0
.e	add.w	d0,(a2)
	cmp.w	#340*16,(a2)
	blt.s	.in
	move.l	a2,a0
	bsr	title_car_new
.in	move.w	4(a2),d0		; the picture: design, facing right
	lsl.w	#5,d0
	add.w	#TCAR_DIR,d0
	mulu	#CARSPR,d0
	lea	cars_gfx,a0
	add.l	d0,a0
	move.w	(a2),d0
	asr.w	#4,d0
	moveq	#3,d1			; car 0 in the front lane
	sub.w	d7,d1
	lsl.w	#2,d1
	add.w	#TSTRIP_Y+3,d1
	move.w	d7,d3
	move.w	d7,d4
	bsr	put_car
	lea	6(a2),a2
	addq.w	#1,d7
	cmp.w	#4,d7
	blo.s	.car
	; the wobble: big on a kick, dying away
	tst.b	beat_flag
	beq.s	.nb
	clr.b	beat_flag
	move.w	#15<<8,wob_amp
.nb	move.w	wob_amp,d0
	move.w	d0,d1
	lsr.w	#3,d1
	sub.w	d1,d0
	move.w	d0,wob_amp
	lsr.w	#8,d0			; amplitude 0..15
	addq.w	#5,wob_phase
	lea	cop_fx+6,a0
	lea	sintab,a1
	move.w	wob_phase,d2
	moveq	#TWOB_N-1,d6
.w	move.w	d2,d1
	and.w	#255,d1
	add.w	d1,d1
	move.w	(a1,d1.w),d1		; -256..256
	add.w	#256,d1
	mulu	d0,d1
	lsr.l	#8,d1
	lsr.w	#1,d1			; 0..amplitude
	cmp.w	#15,d1
	bls.s	.ok
	moveq	#15,d1
.ok	move.w	d1,d3
	lsl.w	#4,d3
	or.w	d3,d1
	move.w	d1,(a0)
	addq.l	#8,a0
	add.w	#11,d2
	dbf	d6,.w
	movem.l	(sp)+,d0-d7/a0-a2
	rts

draw_title_menu:
	movem.l	d0-d7/a0,-(sp)
	moveq	#6,d0
	move.w	#118,d1
	moveq	#28,d2
	move.w	#114,d3
	moveq	#M_BG,d4
	bsr	fill_rect
	moveq	#0,d7
.l	bsr	str_start
	move.w	d7,d0
	lsl.w	#2,d0
	lea	title_items,a0
	move.l	(a0,d0.w),a0
	bsr	str_add
	cmp.w	#3,d7
	bne.s	.n3
	lea	str_ctrl0,a0
	tst.b	r_ctrl
	beq.s	.c
	lea	str_ctrl1,a0
.c	bsr	str_add
.n3	cmp.w	#4,d7
	bne.s	.n4
	lea	str_on,a0
	tst.b	music_on
	bne.s	.mo
	lea	str_off,a0
.mo	bsr	str_add
.n4	bsr	str_end
	move.w	d7,d1
	mulu	#16,d1
	add.w	#124,d1
	moveq	#M_WHITE,d2
	cmp.w	#1,d7
	bne.s	.na
	tst.b	r_active
	bne.s	.na
	moveq	#M_GREY,d2
.na	cmp.w	menu_sel,d7
	bne.s	.ns
	moveq	#M_YELLOW,d2
.ns	bsr	mctext
	addq.w	#1,d7
	cmp.w	#6,d7
	blo	.l
	lea	str_hint,a0
	tst.b	demo_flag
	beq.s	.h
	lea	str_demohint,a0
.h	move.w	#222,d1
	moveq	#M_LBLUE,d2
	bsr	mctext
	movem.l	(sp)+,d0-d7/a0
	rts

st_title:
	bsr	title_anim
	bsr	menu_keys
	tst.w	d0
	beq.s	.k
	bsr	draw_title_menu
.k	move.w	act,d0
	btst	#A_M,d0
	beq.s	.f
	bsr	draw_title_menu
.f	bsr	fire_pressed
	beq	.x
	move.w	menu_sel,d0
	bne.s	.n0
	bsr	new_career		; start a new career
	lea	st_intro_in,a0
	bra	set_state
.n0	cmp.w	#1,d0
	bne.s	.n1
	tst.b	r_active
	beq	.x
	clr.b	practice
	lea	st_shop_in,a0		; continue: to the shop, then the next race
	bra	set_state
.n1	cmp.w	#2,d0
	bne.s	.n2
	lea	st_practice_in,a0
	bra	set_state
.n2	cmp.w	#3,d0
	bne.s	.n3
	not.b	r_ctrl
	and.b	#1,r_ctrl
	bra.s	.redraw
.n3	cmp.w	#4,d0
	bne.s	.n4
	not.b	music_on
	bra.s	.redraw
.n4	lea	st_howto_in,a0
	bra	set_state
.redraw	moveq	#S_CLICK,d0
	bsr	sfx
	bsr	draw_title_menu
.x	rts

new_career:
	movem.l	d0/a0,-(sp)
	move.b	r_ctrl,-(sp)
	lea	records,a0		; keep the best laps
	moveq	#0,d0
	move.l	d0,r_cash
	move.b	#1,r_active
	clr.b	r_cup
	clr.b	r_race
	move.b	#3,r_spares
	clr.b	r_motor
	clr.b	r_tires
	clr.b	r_battery
	clr.b	r_armor
	clr.b	r_cap
	clr.b	r_class
	clr.b	r_paint
	clr.b	r_letters
	move.b	#1,r_weap
	move.b	#2,r_ammo
	clr.b	r_erik
	lea	r_points,a0
	moveq	#4,d0
.p	clr.w	(a0)+
	dbf	d0,.p
	clr.b	r_trophy
	clr.b	r_trophy+1
	clr.b	r_trophy+2
	move.b	(sp)+,r_ctrl
	clr.b	practice
	movem.l	(sp)+,d0/a0
	rts

;------------------------------------------------------------------------------
; how to play
;------------------------------------------------------------------------------
st_howto_in:
	bsr	show_menu_bg
	lea	str_howto_h,a0
	bsr	header
	lea	howto_text,a0
	moveq	#62,d1
.l	tst.b	(a0)
	beq.s	.e
	moveq	#M_WHITE,d2
	cmp.b	#'*',(a0)
	bne.s	.w
	addq.l	#1,a0
	moveq	#M_YELLOW,d2
.w	moveq	#1,d0
	bsr	mtext
.n	tst.b	(a0)+
	bne.s	.n
	add.w	#9,d1
	bra.s	.l
.e	lea	st_back_title,a0
	bra	set_state

st_back_title:
	bsr	fire_pressed
	bne.s	.t
	btst	#A_ESC,act+1
	beq.s	.x
.t	lea	st_title_in,a0
	bra	set_state
.x	rts

;------------------------------------------------------------------------------
; before a race: the cup, the track, the weather, the drivers
;------------------------------------------------------------------------------
st_intro_in:
	clr.b	practice
	clr.b	ttrial
	moveq	#0,d0
	move.b	r_race,d0
	move.w	d0,cur_track
	; National Cup: the tracks the other way round; World: every second race
	clr.b	race_reverse
	cmp.b	#1,r_cup
	bne.s	.nr
	st	race_reverse
.nr	cmp.b	#2,r_cup
	bne.s	.wr
	btst	#0,r_race
	beq.s	.wr
	st	race_reverse
.wr
	bsr	choose_drivers
	bsr	choose_weather
	bsr	show_menu_bg
	moveq	#SONG_SHOP,d0
	moveq	#40,d1
	bsr	play_song
	; the cup and the race
	bsr	str_start
	moveq	#0,d0
	move.b	r_cup,d0
	lsl.w	#2,d0
	lea	cup_names,a0
	move.l	(a0,d0.w),a0
	bsr	str_add
	lea	str_race,a0
	bsr	str_add
	moveq	#0,d0
	move.b	r_race,d0
	addq.w	#1,d0
	bsr	str_dec
	lea	str_of8,a0
	bsr	str_add
	bsr	str_end
	bsr	header
	bsr	draw_track_info
	; the drivers
	lea	str_against,a0
	moveq	#2,d0
	move.w	#122,d1
	moveq	#M_LBLUE,d2
	bsr	mtext
	moveq	#0,d7
.d	move.w	d7,d0
	add.w	d0,d0
	lea	race_pers,a0
	move.w	(a0,d0.w),d0
	lsl.w	#2,d0
	lea	pers_desc,a0
	move.l	(a0,d0.w),a0
	moveq	#3,d0
	move.w	d7,d1
	mulu	#10,d1
	add.w	#134,d1
	moveq	#M_WHITE,d2
	bsr	mtext
	addq.w	#1,d7
	cmp.w	#3,d7
	blo.s	.d
	bsr	draw_car_info
	lea	str_firerace,a0
	move.w	#240,d1
	moveq	#M_YELLOW,d2
	bsr	mctext
	lea	st_intro,a0
	bra	set_state

; draw_track_info: track name, weather, best lap (y 62..100)
draw_track_info:
	movem.l	d0-d2/a0,-(sp)
	bsr	str_start
	lea	str_track,a0
	bsr	str_add
	moveq	#0,d0
	move.w	cur_track,d0
	addq.w	#1,d0
	bsr	str_dec
	moveq	#':',d0
	bsr	str_char
	moveq	#' ',d0
	bsr	str_char
	move.w	cur_track,d0
	mulu	#TE_SIZE,d0
	lea	track_table,a0
	move.l	(a0,d0.l),a0
	bsr	str_add
	bsr	str_end
	moveq	#64,d1
	moveq	#M_WHITE,d2
	bsr	mctext
	bsr	str_start
	lea	str_weather,a0
	bsr	str_add
	moveq	#0,d0
	move.b	race_weather,d0
	lsl.w	#2,d0
	lea	weather_names,a0
	move.l	(a0,d0.w),a0
	bsr	str_add
	tst.b	race_reverse
	beq.s	.nrv
	lea	str_reverse,a0
	bsr	str_add
.nrv	bsr	str_end
	moveq	#80,d1
	moveq	#M_LBLUE,d2
	bsr	mctext
	bsr	str_start
	lea	str_bestlap,a0
	bsr	str_add
	move.w	cur_track,d0
	add.w	d0,d0
	lea	r_best,a0
	moveq	#0,d1
	move.w	(a0,d0.w),d1
	beq.s	.none
	move.l	d1,d0
	bsr	str_time
	bra.s	.e
.none	lea	str_none,a0
	bsr	str_add
.e	bsr	str_end
	moveq	#96,d1
	moveq	#M_GREY,d2
	bsr	mctext
	movem.l	(sp)+,d0-d2/a0
	rts

; draw_car_info: your car and its upgrades (y 170..230)
draw_car_info:
	movem.l	d0-d4/a0,-(sp)
	bsr	str_start
	lea	str_yourcar,a0
	bsr	str_add
	moveq	#0,d0
	move.b	r_class,d0
	bsr	design_name
	bsr	str_add
	bsr	str_end
	moveq	#2,d0
	move.w	#172,d1
	moveq	#M_LBLUE,d2
	bsr	mtext
	moveq	#0,d3
.l	move.w	d3,d0
	lsl.w	#2,d0
	lea	stat_names,a0
	move.l	(a0,d0.w),a0
	move.w	d3,d1
	mulu	#10,d1
	add.w	#184,d1
	moveq	#3,d0
	moveq	#M_GREY,d2
	bsr	mtext
	lea	r_motor,a0
	moveq	#0,d4
	move.b	(a0,d3.w),d4
	moveq	#13,d0
	bsr	bar5
	addq.w	#1,d3
	cmp.w	#4,d3
	blo.s	.l
	bsr	str_start
	moveq	#'$',d0
	bsr	str_char
	move.l	r_cash,d0
	bsr	str_dec
	bsr	str_end
	moveq	#24,d0
	move.w	#184,d1
	moveq	#M_YELLOW,d2
	bsr	mtext
	bsr	str_start
	lea	str_spares,a0
	bsr	str_add
	moveq	#0,d0
	move.b	r_spares,d0
	bsr	str_dec
	bsr	str_end
	moveq	#24,d0
	move.w	#194,d1
	moveq	#M_WHITE,d2
	bsr	mtext
	bsr	str_start
	lea	str_letters,a0
	bsr	str_add
	moveq	#0,d0
	move.b	r_letters,d0
	beq.s	.nl
	lea	str_stronkie,a0
	subq.w	#1,d0
.lc	move.b	(a0)+,(a1)+
	dbf	d0,.lc
.nl	bsr	str_end
	moveq	#24,d0
	move.w	#204,d1
	moveq	#M_ORANGE,d2
	bsr	mtext
	bsr	str_start
	move.w	r_points,d0
	ext.l	d0
	bsr	str_dec
	lea	str_pts,a0
	bsr	str_add
	bsr	str_end
	moveq	#24,d0
	move.w	#214,d1
	moveq	#M_GREEN,d2
	bsr	mtext
	movem.l	(sp)+,d0-d4/a0
	rts

; design_name: d0 = design -> a0 = its name
design_name:
	lea	design_names,a0
.l	subq.w	#1,d0
	bmi.s	.x
.s	tst.b	(a0)+
	bne.s	.s
	bra.s	.l
.x	rts

; choose_drivers: three of the four, a different one sits out each race
choose_drivers:
	movem.l	d0-d2/a0,-(sp)
	move.w	cur_track,d1
	and.w	#3,d1			; this one sits out
	lea	race_pers,a0
	moveq	#0,d0
.l	cmp.w	d1,d0
	beq.s	.n
	move.w	d0,(a0)+
.n	addq.w	#1,d0
	cmp.w	#4,d0
	blo.s	.l
	move.w	cur_track,d0
	lsr.w	#1,d0
	and.w	#3,d0
	add.w	#SONG_RACE1,d0
	move.w	d0,cur_race_song
	movem.l	(sp)+,d0-d2/a0
	rts

choose_weather:
	movem.l	d0-d1,-(sp)
	clr.b	race_weather
	clr.w	wind_x
	clr.w	wind_y
	tst.b	practice
	bne.s	.x
	tst.b	r_cup
	beq.s	.x
	moveq	#10,d0
	bsr	rand_n
	cmp.w	#3,d0
	bhs.s	.nr
	move.b	#1,race_weather		; rain
	bra.s	.x
.nr	cmp.w	#5,d0
	bhs.s	.x
	move.b	#2,race_weather		; wind
	moveq	#4,d0
	bsr	rand_n
	lsl.w	#2,d0
	lea	wind_dirs,a0
	move.w	(a0,d0.w),wind_x
	move.w	2(a0,d0.w),wind_y
.x	movem.l	(sp)+,d0-d1
	rts

st_intro:
	btst	#A_ESC,act+1
	beq.s	.f
	tst.b	practice
	bne.s	.pr
	lea	st_title_in,a0
	bra	set_state
.pr	lea	st_practice_in,a0
	bra	set_state
.f	bsr	fire_pressed
	beq.s	.x
	bra	start_race
.x	rts

;------------------------------------------------------------------------------
; loading and starting a race
;------------------------------------------------------------------------------
start_race:
	move.w	cur_track,d0
	cmp.w	loaded_track,d0
	beq.s	.have
	moveq	#2,d0
	move.w	#228,d1
	moveq	#36,d2
	moveq	#10,d3
	moveq	#M_BG,d4
	bsr	fill_rect
	lea	str_loading,a0
	move.w	#229,d1
	moveq	#M_LBLUE,d2
	bsr	mctext
	bsr	load_track
	tst.l	d0
	bne.s	.have
	moveq	#2,d0			; the disk could not be read
	move.w	#228,d1
	moveq	#36,d2
	moveq	#10,d3
	moveq	#M_BG,d4
	bsr	fill_rect
	lea	str_diskerr,a0
	move.w	#229,d1
	moveq	#M_RED,d2
	bsr	mctext
	moveq	#S_ERROR,d0
	bra	sfx
.have	bsr	song_stop
	bsr	race_black
	bsr	show_race_mode
	bsr	hide_sprites
	lea	trkfile+12,a0		; unpack the picture and the surface map
	lea	trackbm,a1
	move.l	#TRK_SIZE,d0
	bsr	unlz
	lea	trkfile+12,a0
	add.l	trkfile+4,a0
	lea	surfmap,a1
	move.l	#SURF_SIZE,d0
	bsr	unlz
	bsr	race_setup
	bsr	race_colours_on
	clr.w	sub_frame
	clr.w	step_act
	clr.b	race_quit
	move.w	#-1,cur_song
	lea	st_race,a0
	bra	set_state

; load_track: Tracks/Track<n> into trkfile -> d0 = 1 when it worked
load_track:
	movem.l	d1-d7/a0-a6,-(sp)
	bsr	os_on
	moveq	#0,d6
	move.l	dosbase,d0
	beq.s	.done
	move.l	d0,a6
	move.w	cur_track,d1
	mulu	#16,d1
	add.l	#track_files,d1
	move.l	#1005,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.done
	move.l	d4,d1
	move.l	#trkfile,d2
	move.l	#MAXTRK+16,d3
	jsr	_LVORead(a6)
	move.l	d0,d5
	move.l	d4,d1
	jsr	_LVOClose(a6)
	cmp.l	#12,d5
	ble.s	.done
	cmp.l	#'RCT1',trkfile
	bne.s	.done
	moveq	#1,d6
	move.w	cur_track,loaded_track
.done	bsr	os_off
	move.l	d6,d0
	movem.l	(sp)+,d1-d7/a0-a6
	rts

;------------------------------------------------------------------------------
; after a race: places, prize money, points
;------------------------------------------------------------------------------
st_results_in:
	bsr	hide_sprites
	clr.w	eng_vol
	clr.b	letters_done
	tst.b	race_quit
	beq.s	.done
	lea	st_title_in,a0		; quit: back to the title (no change)
	tst.b	practice
	beq	set_state
	lea	st_practice_in,a0
	bra	set_state
.done	lea	cars,a2
	move.w	C_RANK(a2),d0
	move.w	d0,res_place
	; best lap on this track
	move.w	cur_track,d1
	add.w	d1,d1
	lea	r_best,a0
	move.w	C_BEST(a2),d2
	cmp.w	#9999,d2
	beq.s	.nb
	tst.w	(a0,d1.w)
	beq.s	.setb
	cmp.w	(a0,d1.w),d2
	bhs.s	.nb
.setb	move.w	d2,(a0,d1.w)
.nb	clr.w	res_prize
	tst.b	practice
	bne	.show
	; prize money: 1000 / 600 / 300 / 0, more in the later cups
	move.w	res_place,d0
	subq.w	#1,d0
	add.w	d0,d0
	lea	prize_table,a0
	move.w	(a0,d0.w),d1
	moveq	#0,d2
	move.b	r_cup,d2
	addq.w	#2,d2
	mulu	d2,d1
	lsr.l	#1,d1
	move.w	d1,res_prize
	add.l	d1,r_cash
	; points for everybody
	lea	cars,a2
	moveq	#3,d7
.pt	move.w	C_RANK(a2),d0
	subq.w	#1,d0
	add.w	d0,d0
	lea	points_table,a0
	move.w	(a0,d0.w),d1
	move.w	C_PERS(a2),d0
	addq.w	#1,d0			; you = 0
	add.w	d0,d0
	lea	r_points,a0
	add.w	d1,(a0,d0.w)
	lea	CARSZ(a2),a2
	dbf	d7,.pt
	addq.w	#1,r_races
	cmp.w	#1,res_place
	bne.s	.nw
	addq.w	#1,r_wins
.nw	; your weapon goes with you to the next race
	move.w	cars+C_WEAP,d0
	move.b	d0,r_weap
	move.w	cars+C_AMMO,d0
	move.b	d0,r_ammo
	; all STRONKIE letters: a better car
	cmp.b	#8,r_letters
	blo.s	.nl
	clr.b	r_letters
	st	letters_done
	add.l	#2000,r_cash
	cmp.b	#4,r_class
	bhs.s	.nl
	addq.b	#1,r_class
	move.b	r_class,r_paint
.nl	; qualified (top 3)?
	cmp.w	#3,res_place
	bhi.s	.notq
	addq.b	#1,r_race
	bra.s	.save
.notq	tst.b	r_spares
	beq.s	.out
	subq.b	#1,r_spares
	bra.s	.save
.out	clr.b	r_active		; no spare cars left: game over
.save	bsr	save_records
.show	bsr	show_menu_bg
	moveq	#SONG_WIN,d0
	cmp.w	#3,res_place
	bls.s	.sw
	moveq	#SONG_LOSE,d0
.sw	moveq	#48,d1
	bsr	play_song
	move.w	res_place,d0
	cmp.w	#1,d0
	bne.s	.nc
	moveq	#S_CHEER,d0
	bsr	sfx
.nc	lea	str_results,a0
	bsr	header
	bsr	draw_track_info
	; the table, in finishing order
	lea	str_res_head,a0
	moveq	#2,d0
	move.w	#112,d1
	moveq	#M_LBLUE,d2
	bsr	mtext
	moveq	#1,d6			; place
.rows	lea	cars,a2
	moveq	#3,d7
.find	cmp.w	C_RANK(a2),d6
	beq.s	.got
	lea	CARSZ(a2),a2
	dbf	d7,.find
	bra	.nextr
.got	move.w	d6,d1
	mulu	#11,d1
	add.w	#114,d1
	bsr	str_start
	move.w	d6,d0
	subq.w	#1,d0
	lsl.w	#2,d0
	lea	str_places,a0
	add.w	d0,a0
	bsr	str_add
	moveq	#' ',d0
	bsr	str_char
	lea	str_you,a0
	move.w	C_PERS(a2),d0
	bmi.s	.nm
	lsl.w	#2,d0
	lea	pers_short,a0
	move.l	(a0,d0.w),a0
.nm	bsr	str_add
	bsr	str_end
	moveq	#2,d0
	moveq	#M_WHITE,d2
	tst.w	C_PERS(a2)
	bpl.s	.cw
	moveq	#M_YELLOW,d2
.cw	bsr	mtext
	bsr	str_start
	moveq	#0,d0
	move.w	C_BEST(a2),d0
	cmp.w	#9999,d0
	beq.s	.nob
	bsr	str_time
.nob	bsr	str_end
	moveq	#23,d0
	moveq	#M_GREY,d2
	bsr	mtext
	tst.b	practice
	bne.s	.nextr
	bsr	str_start
	move.w	d6,d0
	subq.w	#1,d0
	add.w	d0,d0
	lea	points_table,a0
	move.w	(a0,d0.w),d0
	ext.l	d0
	bsr	str_dec
	lea	str_pts,a0
	bsr	str_add
	bsr	str_end
	moveq	#32,d0
	moveq	#M_GREEN,d2
	bsr	mtext
.nextr	addq.w	#1,d6
	cmp.w	#5,d6
	blo	.rows
	tst.b	practice
	bne	.fin
	; prize, qualification
	bsr	str_start
	lea	str_prize,a0
	bsr	str_add
	moveq	#0,d0
	move.w	res_prize,d0
	bsr	str_dec
	bsr	str_end
	move.w	#174,d1
	moveq	#M_YELLOW,d2
	bsr	mctext
	lea	str_qual,a0
	moveq	#M_GREEN,d2
	cmp.w	#3,res_place
	bls.s	.q
	lea	str_notq,a0
	moveq	#M_RED,d2
	tst.b	r_active
	bne.s	.q
	lea	str_nocars,a0
.q	move.w	#190,d1
	bsr	mctext
	tst.b	letters_done
	beq.s	.fin
	lea	str_lettersdone,a0
	move.w	#206,d1
	moveq	#M_ORANGE,d2
	bsr	mctext
.fin	lea	str_fire,a0
	move.w	#240,d1
	moveq	#M_LBLUE,d2
	bsr	mctext
	lea	st_results,a0
	bra	set_state

st_results:
	bsr	fire_pressed
	beq.s	.x
	tst.b	practice
	beq.s	.c
	lea	st_practice_in,a0
	bra	set_state
.c	tst.b	r_active
	bne.s	.a
	lea	st_gameover_in,a0
	bra	set_state
.a	cmp.w	#3,res_place
	bls.s	.q
	lea	st_intro_in,a0		; try again (one spare car less)
	bra	set_state
.q	tst.b	demo_flag
	beq.s	.full
	cmp.b	#2,r_race
	blo.s	.full
	lea	st_demoend_in,a0
	bra	set_state
.full	cmp.b	#NRACES,r_race
	blo.s	.shop
	lea	st_cupend_in,a0
	bra	set_state
.shop	lea	st_shop_in,a0
	bra	set_state
.x	rts

;------------------------------------------------------------------------------
; the shop
;------------------------------------------------------------------------------
NSHOP		equ	10
st_shop_in:
	bsr	show_menu_bg
	moveq	#SONG_SHOP,d0
	moveq	#40,d1
	bsr	play_song
	lea	str_shop,a0
	bsr	header
	clr.w	menu_sel
	move.w	#NSHOP,menu_n
	bsr	draw_shop
	lea	st_shop,a0
	bra	set_state

; shop_price: d0 = item -> d1.l = price (0 = not for sale)
shop_price:
	movem.l	d0/d2/a0,-(sp)
	moveq	#0,d1
	cmp.w	#5,d0
	bhs.s	.other
	lea	r_motor,a0		; motor, tires, battery, armor, rack
	moveq	#0,d2
	move.b	(a0,d0.w),d2
	cmp.w	#5,d2
	cmp.w	#4,d0
	bne.s	.lim5
	cmp.w	#4,d2			; the weapon rack goes to 6 (2 + 4)
	bhs.s	.x
	bra.s	.ok
.lim5	cmp.w	#5,d2
	bhs.s	.x
.ok	addq.w	#1,d2
	add.w	d0,d0
	lea	shop_base,a0
	move.w	(a0,d0.w),d1
	mulu	d2,d1
	bra.s	.x
.other	cmp.w	#5,d0
	beq.s	.ammo
	cmp.w	#6,d0
	bne.s	.n6
.ammo	move.l	#150,d1
	bra.s	.x
.n6	cmp.w	#7,d0
	bne.s	.x
	move.l	#2500,d1
.x	movem.l	(sp)+,d0/d2/a0
	rts

draw_shop:
	movem.l	d0-d7/a0,-(sp)
	moveq	#1,d0
	moveq	#58,d1
	moveq	#38,d2
	move.w	#122,d3
	moveq	#M_BG,d4
	bsr	fill_rect
	moveq	#0,d7
.l	move.w	d7,d1
	mulu	#12,d1
	add.w	#60,d1
	move.w	d1,d6
	moveq	#M_WHITE,d2
	cmp.w	menu_sel,d7
	bne.s	.c
	moveq	#M_YELLOW,d2
	lea	str_arrow,a0
	moveq	#1,d0
	bsr	mtext
.c	bsr	str_start
	move.w	d7,d0
	lsl.w	#2,d0
	lea	shop_items,a0
	move.l	(a0,d0.w),a0
	bsr	str_add
	cmp.w	#8,d7			; paint: its name
	bne.s	.np
	moveq	#0,d0
	move.b	r_paint,d0
	lea	paint_names,a0
.pn	subq.w	#1,d0
	bmi.s	.pg
.ps	tst.b	(a0)+
	bne.s	.ps
	bra.s	.pn
.pg	bsr	str_add
.np	bsr	str_end
	moveq	#3,d0
	move.w	d6,d1
	bsr	mtext
	cmp.w	#5,d7			; level bars for the upgrades
	bhs.s	.nb
	lea	r_motor,a0
	moveq	#0,d4
	move.b	(a0,d7.w),d4
	moveq	#18,d0
	bsr	bar5
.nb	move.w	d7,d0
	bsr	shop_price
	tst.l	d1
	beq.s	.nopr
	bsr	str_start
	moveq	#'$',d0
	bsr	str_char
	move.l	d1,d0
	bsr	str_dec
	bsr	str_end
	moveq	#30,d0
	move.w	d6,d1
	moveq	#M_ORANGE,d2
	bsr	mtext
	bra.s	.nx
.nopr	cmp.w	#5,d7
	bhs.s	.nx
	lea	str_max,a0
	moveq	#30,d0
	move.w	d6,d1
	moveq	#M_GREEN,d2
	bsr	mtext
.nx	addq.w	#1,d7
	cmp.w	#NSHOP,d7
	blo	.l
	; cash, ammo, spares
	moveq	#1,d0
	move.w	#190,d1
	moveq	#38,d2
	moveq	#40,d3
	moveq	#M_BG,d4
	bsr	fill_rect
	bsr	str_start
	lea	str_cash,a0
	bsr	str_add
	move.l	r_cash,d0
	bsr	str_dec
	lea	str_sp2,a0
	bsr	str_add
	lea	str_spares,a0
	bsr	str_add
	moveq	#0,d0
	move.b	r_spares,d0
	bsr	str_dec
	bsr	str_end
	move.w	#194,d1
	moveq	#M_YELLOW,d2
	bsr	mctext
	bsr	str_start
	lea	str_carry,a0
	bsr	str_add
	moveq	#0,d0
	move.b	r_weap,d0
	lsl.w	#2,d0
	lea	weap_names,a0
	move.l	(a0,d0.w),a0
	bsr	str_add
	tst.b	r_weap
	beq.s	.nw
	moveq	#'x',d0
	bsr	str_char
	moveq	#0,d0
	move.b	r_ammo,d0
	bsr	str_dec
.nw	lea	str_rack,a0
	bsr	str_add
	moveq	#0,d0
	move.b	r_cap,d0
	addq.w	#2,d0
	bsr	str_dec
	bsr	str_end
	move.w	#206,d1
	moveq	#M_LBLUE,d2
	bsr	mctext
	lea	str_shophint,a0
	move.w	#222,d1
	moveq	#M_GREY,d2
	bsr	mctext
	movem.l	(sp)+,d0-d7/a0
	rts

st_shop:
	bsr	menu_keys
	tst.w	d0
	beq.s	.f
	bsr	draw_shop
.f	btst	#A_ESC,act+1
	beq.s	.nesc
	bsr	save_records
	lea	st_title_in,a0
	bra	set_state
.nesc	bsr	fire_pressed
	beq	.x
	move.w	menu_sel,d0
	cmp.w	#9,d0			; next race
	bne.s	.buy
	bsr	save_records
	lea	st_intro_in,a0
	bra	set_state
.buy	cmp.w	#8,d0			; paint: cycle through the unlocked ones
	bne.s	.np
	move.b	r_paint,d0
	addq.b	#1,d0
	cmp.b	#6,d0
	bhs.s	.gold
	cmp.b	r_class,d0
	bls.s	.p
.gold	cmp.b	#6,d0			; after the unlocked paints: the golden car
	bhi.s	.p0
	btst	#1,r_unlock
	beq.s	.p0
	moveq	#6,d0
	bra.s	.p
.p0	moveq	#0,d0
.p	move.b	d0,r_paint
	moveq	#S_CLICK,d0
	bsr	sfx
	bra	.redraw
.np	bsr	shop_price
	tst.l	d1
	beq.s	.no
	cmp.l	r_cash,d1
	bhi.s	.no
	sub.l	d1,r_cash
	cmp.w	#5,d0
	bhs.s	.other
	lea	r_motor,a0
	addq.b	#1,(a0,d0.w)
	bra.s	.ok
.other	cmp.w	#7,d0
	bne.s	.am
	addq.b	#1,r_spares
	bra.s	.ok
.am	subq.w	#4,d0			; 5 -> missiles (1), 6 -> bombs (2)
	cmp.b	r_weap,d0
	beq.s	.same
	move.b	d0,r_weap
	clr.b	r_ammo
.same	addq.b	#2,r_ammo
	move.b	r_cap,d0
	addq.b	#2,d0
	cmp.b	r_ammo,d0
	bhs.s	.ok
	move.b	d0,r_ammo
.ok	moveq	#S_BUY,d0
	bsr	sfx
	bra.s	.redraw
.no	moveq	#S_ERROR,d0
	bsr	sfx
	rts
.redraw	bsr	draw_shop
.x	rts

;------------------------------------------------------------------------------
; the end of a cup, the championship, game over
;------------------------------------------------------------------------------
st_cupend_in:
	bsr	show_menu_bg
	bsr	str_start
	moveq	#0,d0
	move.b	r_cup,d0
	lsl.w	#2,d0
	lea	cup_names,a0
	move.l	(a0,d0.w),a0
	bsr	str_add
	lea	str_standings,a0
	bsr	str_add
	bsr	str_end
	bsr	header
	; your place among the five
	moveq	#1,d6
	move.w	r_points,d0
	lea	r_points+2,a0
	moveq	#3,d1
.c	cmp.w	(a0)+,d0
	bhs.s	.n
	addq.w	#1,d6
.n	dbf	d1,.c
	move.w	d6,res_place
	moveq	#0,d0
	move.b	r_cup,d0
	lea	r_trophy,a0
	cmp.w	#3,d6
	bhi.s	.nt
	move.b	d6,(a0,d0.w)
.nt	clr.b	unlock_new
	cmp.w	#1,d6			; gold: the secret track, all three: the golden car
	bne.s	.ng
	btst	#0,r_unlock
	bne.s	.g1
	bset	#0,r_unlock
	bset	#0,unlock_new
.g1	cmp.b	#1,r_trophy
	bne.s	.ng
	cmp.b	#1,r_trophy+1
	bne.s	.ng
	cmp.b	#1,r_trophy+2
	bne.s	.ng
	btst	#1,r_unlock
	bne.s	.ng
	bset	#1,r_unlock
	bset	#1,unlock_new
.ng	; the table: you and the four drivers
	moveq	#0,d7
.t	move.w	d7,d1
	mulu	#12,d1
	add.w	#70,d1
	lea	str_you,a0
	tst.w	d7
	beq.s	.y
	move.w	d7,d0
	subq.w	#1,d0
	lsl.w	#2,d0
	lea	pers_short,a0
	move.l	(a0,d0.w),a0
.y	moveq	#8,d0
	moveq	#M_WHITE,d2
	tst.w	d7
	bne.s	.w
	moveq	#M_YELLOW,d2
.w	bsr	mtext
	bsr	str_start
	move.w	d7,d0
	add.w	d0,d0
	lea	r_points,a0
	move.w	(a0,d0.w),d0
	ext.l	d0
	bsr	str_dec
	lea	str_pts,a0
	bsr	str_add
	bsr	str_end
	moveq	#26,d0
	bsr	mtext
	addq.w	#1,d7
	cmp.w	#5,d7
	blo.s	.t
	move.w	res_place,d0
	subq.w	#1,d0
	cmp.w	#3,d0
	bls.s	.tr
	moveq	#3,d0
.tr	lsl.w	#2,d0
	lea	trophy_texts,a0
	move.l	(a0,d0.w),a0
	move.w	#150,d1
	moveq	#M_YELLOW,d2
	bsr	mctext
	lea	str_cupdone,a0
	move.w	#170,d1
	moveq	#M_WHITE,d2
	bsr	mctext
	btst	#0,unlock_new
	beq.s	.u1
	lea	str_unl_track,a0
	move.w	#192,d1
	moveq	#M_ORANGE,d2
	bsr	mctext
.u1	btst	#1,unlock_new
	beq.s	.u2
	lea	str_unl_car,a0
	move.w	#206,d1
	moveq	#M_ORANGE,d2
	bsr	mctext
.u2	lea	str_fire,a0
	move.w	#240,d1
	moveq	#M_LBLUE,d2
	bsr	mctext
	moveq	#SONG_WIN,d0
	moveq	#48,d1
	bsr	play_song
	moveq	#S_CHEER,d0
	bsr	sfx
	; on to the next cup
	addq.b	#1,r_cup
	clr.b	r_race
	lea	r_points,a0
	moveq	#4,d0
.p	clr.w	(a0)+
	dbf	d0,.p
	cmp.b	#3,r_cup
	blo.s	.more
	clr.b	r_active
	addq.w	#1,r_titles
.more	bsr	save_records
	lea	st_cupend,a0
	bra	set_state

st_cupend:
	bsr	fire_pressed
	beq.s	.x
	tst.b	r_active
	bne.s	.shop
	lea	st_champion_in,a0
	bra	set_state
.shop	lea	st_shop_in,a0
	bra	set_state
.x	rts

st_champion_in:
	bsr	show_menu_bg
	lea	str_champ_h,a0
	bsr	header
	lea	champ_text,a0
	moveq	#80,d1
.l	tst.b	(a0)
	beq.s	.e
	moveq	#M_WHITE,d2
	bsr	mctext
.n	tst.b	(a0)+
	bne.s	.n
	add.w	#14,d1
	bra.s	.l
.e	moveq	#SONG_WIN,d0
	moveq	#56,d1
	bsr	play_song
	moveq	#S_CHEER,d0
	bsr	sfx
	lea	st_back_title,a0
	bra	set_state

st_gameover_in:
	bsr	show_menu_bg
	lea	str_gameover,a0
	bsr	header
	lea	str_gameover2,a0
	moveq	#100,d1
	moveq	#M_WHITE,d2
	bsr	mctext
	lea	str_gameover3,a0
	moveq	#116,d1
	moveq	#M_GREY,d2
	bsr	mctext
	moveq	#SONG_LOSE,d0
	moveq	#48,d1
	bsr	play_song
	lea	st_back_title,a0
	bra	set_state

;------------------------------------------------------------------------------
; the end of the demo
;------------------------------------------------------------------------------
st_demoend_in:
	clr.b	r_active
	bsr	show_menu_bg
	lea	str_demoend_h,a0
	bsr	header
	lea	demoend_text,a0
	moveq	#70,d1
.l	tst.b	(a0)
	beq.s	.e
	moveq	#M_WHITE,d2
	cmp.b	#'*',(a0)
	bne.s	.w
	addq.l	#1,a0
	moveq	#M_YELLOW,d2
.w	bsr	mctext
.n	tst.b	(a0)+
	bne.s	.n
	add.w	#12,d1
	bra.s	.l
.e	moveq	#SONG_WIN,d0
	moveq	#48,d1
	bsr	play_song
	lea	st_back_title,a0
	bra	set_state

;------------------------------------------------------------------------------
; wrap_track: d0 = track (may be -1 or too high) -> a track you may choose:
; 1-9, the secret 10th once unlocked, only 1-2 in the demo
wrap_track:
	movem.l	d1,-(sp)
	moveq	#NRACES,d1
	btst	#0,r_unlock
	beq.s	.n
	moveq	#NTRACKS,d1
.n	tst.b	demo_flag
	beq.s	.d
	moveq	#2,d1
.d	tst.w	d0
	bpl.s	.p
	add.w	d1,d0
.p	cmp.w	d1,d0
	blo.s	.x
	moveq	#0,d0
.x	movem.l	(sp)+,d1
	rts

;------------------------------------------------------------------------------
; practice: any track, no money
;------------------------------------------------------------------------------
st_practice_in:
	st	practice
	move.w	cur_track,d0
	bsr	wrap_track
	move.w	d0,cur_track
	clr.b	race_weather
	clr.w	wind_x
	clr.w	wind_y
	move.w	#0,race_pers
	move.w	#1,race_pers+2
	move.w	#2,race_pers+4
	bsr	show_menu_bg
	moveq	#SONG_SHOP,d0
	moveq	#40,d1
	bsr	play_song
	lea	str_practice,a0
	bsr	header
	bsr	draw_practice
	lea	st_practice,a0
	bra	set_state

draw_practice:
	movem.l	d0-d4/a0,-(sp)
	moveq	#1,d0
	moveq	#60,d1
	moveq	#38,d2
	moveq	#60,d3
	moveq	#M_BG,d4
	bsr	fill_rect
	bsr	draw_track_info
	bsr	str_start		; the mode: race / backwards / time trial
	lea	str_mode,a0
	bsr	str_add
	move.w	prac_mode,d0
	lsl.w	#2,d0
	lea	mode_names,a0
	move.l	(a0,d0.w),a0
	bsr	str_add
	bsr	str_end
	move.w	#112,d1
	moveq	#M_YELLOW,d2
	bsr	mctext
	lea	str_prachint,a0
	move.w	#130,d1
	moveq	#M_LBLUE,d2
	bsr	mctext
	lea	str_prachint2,a0
	move.w	#146,d1
	moveq	#M_GREY,d2
	bsr	mctext
	bsr	draw_car_info
	movem.l	(sp)+,d0-d4/a0
	rts

st_practice:
	move.w	act,d1
	btst	#A_ESC,d1
	beq.s	.n
	clr.b	practice
	lea	st_title_in,a0
	bra	set_state
.n	moveq	#0,d0
	btst	#A_LEFT,d1
	beq.s	.r
	moveq	#-1,d0
.r	btst	#A_RIGHT,d1
	beq.s	.c
	moveq	#1,d0
.c	tst.w	d0
	beq.s	.ud
	add.w	cur_track,d0
	bsr	wrap_track
	move.w	d0,cur_track
.clk	moveq	#S_CLICK,d0
	bsr	sfx
	bsr	draw_practice
	rts
.ud	btst	#A_UP,d1		; up / down: the mode
	beq.s	.dn
	subq.w	#1,prac_mode
	bpl.s	.clk
	move.w	#2,prac_mode
	bra.s	.clk
.dn	btst	#A_DOWN,d1
	beq.s	.f
	addq.w	#1,prac_mode
	cmp.w	#3,prac_mode
	blo.s	.clk
	clr.w	prac_mode
	bra.s	.clk
.f	bsr	fire_pressed
	beq	.x
	clr.b	race_reverse
	clr.b	ttrial
	cmp.w	#1,prac_mode
	bne.s	.m2
	st	race_reverse
.m2	cmp.w	#2,prac_mode
	bne.s	.m3
	st	ttrial
	bsr	ghost_load
.m3	move.w	cur_track,d0
	lsr.w	#1,d0
	and.w	#3,d0
	add.w	#SONG_RACE1,d0
	move.w	d0,cur_race_song
	bra	start_race
.x	rts


;------------------------------------------------------------------------------
; the time trial: the ghost on disk (RCGhost0..9), the end screen
;------------------------------------------------------------------------------
ghost_load:
	movem.l	d0-d7/a0-a6,-(sp)
	clr.w	gh_best_t
	clr.b	gh_new
	move.w	cur_track,d0
	add.b	#'0',d0
	move.b	d0,ghost_name+7
	bsr	os_on
	move.l	dosbase,d0
	beq.s	.x
	move.l	d0,a6
	move.l	#ghost_name,d1
	move.l	#1005,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#gh_file,d2
	move.l	#8+GH_MAX*6,d3
	jsr	_LVORead(a6)
	move.l	d4,d1
	jsr	_LVOClose(a6)
	cmp.l	#'RCG1',gh_file		; is it a good one, for this track?
	bne.s	.bad
	move.w	gh_track,d0
	cmp.w	cur_track,d0
	bne.s	.bad
	cmp.w	#GH_MAX,gh_best_t
	blo.s	.x
.bad	clr.w	gh_best_t
.x	bsr	os_off
	movem.l	(sp)+,d0-d7/a0-a6
	rts

ghost_save:
	tst.b	demo_flag		; the demo saves nothing
	bne	.r
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	#'RCG1',gh_file
	move.w	cur_track,gh_track
	move.w	cur_track,d0
	add.b	#'0',d0
	move.b	d0,ghost_name+7
	bsr	os_on
	move.l	dosbase,d0
	beq.s	.x
	move.l	d0,a6
	move.l	#ghost_name,d1
	move.l	#1006,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#gh_file,d2
	moveq	#0,d3
	move.w	gh_best_t,d3
	mulu	#6,d3
	addq.l	#8,d3
	jsr	_LVOWrite(a6)
	move.l	d4,d1
	jsr	_LVOClose(a6)
	tst.b	whd_mode
	bne.s	.x
	moveq	#25,d1			; let the disk finish
	jsr	_LVODelay(a6)
.x	bsr	os_off
	movem.l	(sp)+,d0-d7/a0-a6
.r	rts

st_ttend_in:
	bsr	show_menu_bg
	lea	str_tt_h,a0
	bsr	header
	bsr	str_start		; the track
	move.w	cur_track,d0
	mulu	#TE_SIZE,d0
	lea	track_table,a0
	move.l	(a0,d0.l),a0
	bsr	str_add
	bsr	str_end
	moveq	#64,d1
	moveq	#M_WHITE,d2
	bsr	mctext
	bsr	str_start		; your best lap
	lea	str_tt_best,a0
	bsr	str_add
	move.w	cars+C_BEST,d0
	cmp.w	#9999,d0
	beq.s	.nl
	bsr	str_time
	bra.s	.bl
.nl	moveq	#'-',d0
	bsr	str_char
.bl	bsr	str_end
	moveq	#96,d1
	moveq	#M_YELLOW,d2
	bsr	mctext
	tst.w	gh_best_t		; the ghost
	beq.s	.ng
	bsr	str_start
	lea	str_tt_ghost,a0
	bsr	str_add
	move.w	gh_best_t,d0
	bsr	str_time
	bsr	str_end
	moveq	#112,d1
	moveq	#M_LBLUE,d2
	bsr	mctext
.ng	lea	str_tt_beat,a0
	tst.b	gh_new
	beq.s	.nn
	bsr	ghost_save
	lea	str_tt_saved,a0
.nn	move.w	#144,d1
	moveq	#M_GREEN,d2
	bsr	mctext
	; the best lap ever on this track
	move.w	cur_track,d1
	add.w	d1,d1
	lea	r_best,a0
	move.w	cars+C_BEST,d2
	cmp.w	#9999,d2
	beq.s	.nb
	tst.w	(a0,d1.w)
	beq.s	.sb
	cmp.w	(a0,d1.w),d2
	bhs.s	.nb
.sb	move.w	d2,(a0,d1.w)
	bsr	save_records
.nb	lea	str_tt_fire,a0
	move.w	#240,d1
	moveq	#M_LBLUE,d2
	bsr	mctext
	moveq	#SONG_WIN,d0
	moveq	#48,d1
	bsr	play_song
	lea	st_ttend,a0
	bra	set_state

st_ttend:
	bsr	fire_pressed
	bne.s	.b
	btst	#A_ESC,act+1
	beq.s	.x
.b	lea	st_practice_in,a0
	bra	set_state
.x	rts
;------------------------------------------------------------------------------
; the career on disk: RCTurbo.dat
;------------------------------------------------------------------------------
load_records:
	movem.l	d0-d5/a0-a1/a6,-(sp)
	move.l	dosbase,d0
	beq.s	.none
	move.l	d0,a6
	move.l	#recname,d1
	move.l	#1005,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.none
	move.l	d4,d1
	move.l	#rec_load,d2
	move.l	#REC_SIZE,d3
	jsr	_LVORead(a6)
	move.l	d0,d5
	move.l	d4,d1
	jsr	_LVOClose(a6)
	cmp.l	#REC_SIZE,d5
	bne.s	.none
	cmp.l	#'RCT2',rec_load
	bne.s	.none
	lea	rec_load,a0
	lea	records,a1
	moveq	#REC_SIZE/2-1,d0
.c	move.w	(a0)+,(a1)+
	dbf	d0,.c
.none	movem.l	(sp)+,d0-d5/a0-a1/a6
	rts

save_records:
	tst.b	demo_flag		; the demo saves nothing
	bne.s	.demo
	bra.s	.go
.demo	rts
.go	movem.l	d0-d7/a0-a6,-(sp)
	move.l	#'RCT2',records
	bsr	os_on
	move.l	dosbase,d0
	beq.s	.fail
	move.l	d0,a6
	move.l	#recname,d1
	move.l	#1006,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.fail
	move.l	d4,d1
	move.l	#records,d2
	move.l	#REC_SIZE,d3
	jsr	_LVOWrite(a6)
	move.l	d4,d1
	jsr	_LVOClose(a6)
	tst.b	whd_mode
	bne.s	.fail
	moveq	#25,d1			; let the disk finish
	jsr	_LVODelay(a6)
.fail	bsr	os_off
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;------------------------------------------------------------------------------
; menu texts and tables
;------------------------------------------------------------------------------
	section	data,data
said_title	dc.b	0
	even
title_items	dc.l	ti_new,ti_cont,ti_prac,ti_ctrl,ti_music,ti_howto
ti_new		dc.b	'START NEW CAREER',0
ti_cont		dc.b	'CONTINUE CAREER',0
ti_prac		dc.b	'PRACTICE RACE',0
ti_ctrl		dc.b	'CONTROLS: ',0
ti_music	dc.b	'MUSIC: ',0
ti_howto	dc.b	'HOW TO PLAY',0
str_ctrl0	dc.b	'UP = GAS',0
str_ctrl1	dc.b	'FIRE = GAS',0
str_on		dc.b	'ON',0
str_off		dc.b	'OFF',0
str_hint	dc.b	'JOYSTICK UP/DOWN AND FIRE',0
str_demohint	dc.b	'FREE DEMO: 2 OF THE 8 TRACKS',0
str_demoend_h	dc.b	'THE END OF THE DEMO',0
demoend_text
	dc.b	'*WELL DRIVEN!',0
	dc.b	' ',0
	dc.b	'THE FULL GAME HAS:',0
	dc.b	'8 TRACKS IN 8 TOY WORLDS',0
	dc.b	'3 CUPS: AMATEUR, NATIONAL, WORLD',0
	dc.b	'THE SHOP, 5 CARS, RAIN AND WIND',0
	dc.b	'AND YOUR CAREER SAVED ON DISK',0
	dc.b	' ',0
	dc.b	'*GET IT ON STRONKIE.ITCH.IO',0
	dc.b	' ',0
	dc.b	'CREATED BY MARK STRONKS, STRONKIE SOFT',0
	dc.b	0
str_howto_h	dc.b	'HOW TO PLAY',0
howto_text
	dc.b	'*RACE YOUR RC CAR AGAINST 3 RIVALS.',0
	dc.b	'4 LAPS. FINISH IN THE TOP 3 TO GO ON.',0
	dc.b	'4TH PLACE COSTS A SPARE CAR AND A RETRY.',0
	dc.b	' ',0
	dc.b	'*CONTROLS (UP = GAS):',0
	dc.b	'LEFT/RIGHT STEER, UP GAS, DOWN BRAKE,',0
	dc.b	'FIRE OR SPACE: WEAPON.  P/ESC: PAUSE',0
	dc.b	'(SET FIRE = GAS ON THE TITLE SCREEN)',0
	dc.b	' ',0
	dc.b	'*PICKUP BOXES ON THE TRACK:',0
	dc.b	'M MOTOR, TIRES, BATTERY: FASTER CAR',0
	dc.b	'MISSILES, BOMBS, HOMING MISSILE, CASH,',0
	dc.b	'ROLL CAGE, TURBO, SHIELD, REPAIR',0
	dc.b	' ',0
	dc.b	'*COLLECT S-T-R-O-N-K-I-E (RED BOXES):',0
	dc.b	'ALL 8 = A BETTER CAR + $2000 + PAINT',0
	dc.b	' ',0
	dc.b	'*YELLOW ZIPPERS SPEED YOU UP. RAMPS JUMP.',0
	dc.b	'AVOID OIL, SAND, WATER AND MARBLES.',0
	dc.b	'SPEND PRIZE MONEY IN THE SHOP.',0
	dc.b	0
str_race	dc.b	' - RACE ',0
str_of8		dc.b	' OF 9',0
str_reverse	dc.b	' - BACKWARDS!',0
str_unl_track	dc.b	'SECRET TRACK UNLOCKED! (PRACTICE)',0
str_unl_car	dc.b	'THE GOLDEN CAR IS UNLOCKED! (SHOP)',0
str_track	dc.b	'TRACK ',0
str_weather	dc.b	'WEATHER: ',0
str_bestlap	dc.b	'BEST LAP: ',0
str_none	dc.b	'-',0
str_against	dc.b	'YOUR RIVALS:',0
str_yourcar	dc.b	'YOUR CAR: ',0
str_spares	dc.b	'SPARE CARS: ',0
str_letters	dc.b	'LETTERS: ',0
str_pts		dc.b	' PTS',0
str_firerace	dc.b	'FIRE: RACE!   ESC: TITLE',0
str_loading	dc.b	'LOADING TRACK...',0
str_diskerr	dc.b	'CANNOT LOAD THE TRACK! (DISK?)',0
str_results	dc.b	'RACE RESULTS',0
str_res_head	dc.b	'PLACE DRIVER         BEST LAP  POINTS',0
str_you		dc.b	'YOU',0
str_prize	dc.b	'PRIZE MONEY: $',0
str_qual	dc.b	'QUALIFIED! ON TO THE NEXT RACE',0
str_notq	dc.b	'NOT QUALIFIED - ONE SPARE CAR LOST',0
str_nocars	dc.b	'NO SPARE CARS LEFT!',0
str_lettersdone	dc.b	'STRONKIE! YOUR CAR IS UPGRADED!',0
str_fire	dc.b	'PRESS FIRE',0
str_shop	dc.b	'THE SHOP',0
str_arrow	dc.b	'}',0
str_max		dc.b	'MAX',0
str_cash	dc.b	'CASH: $',0
str_carry	dc.b	'WEAPON: ',0
str_rack	dc.b	'  RACK: ',0
str_shophint	dc.b	'FIRE: BUY   ESC: SAVE + TITLE',0
str_standings	dc.b	' - FINAL',0
str_cupdone	dc.b	'THE CUP IS OVER!',0
str_champ_h	dc.b	'WORLD RC CHAMPION!',0
str_gameover	dc.b	'GAME OVER',0
str_gameover2	dc.b	'NO SPARE CARS LEFT.',0
str_gameover3	dc.b	'THE CAREER IS OVER - TRY AGAIN!',0
str_practice	dc.b	'PRACTICE',0
str_mode	dc.b	'MODE: ',0
	even
mode_names	dc.l	mn_race,mn_back,mn_tt
mn_race		dc.b	'RACE',0
mn_back		dc.b	'RACE BACKWARDS',0
mn_tt		dc.b	'TIME TRIAL (GHOST)',0
str_tt_h	dc.b	'TIME TRIAL',0
str_tt_best	dc.b	'YOUR BEST LAP: ',0
str_tt_ghost	dc.b	'THE GHOST LAP: ',0
str_tt_saved	dc.b	'NEW GHOST SAVED!',0
str_tt_beat	dc.b	'BEAT THE GHOST NEXT TIME!',0
str_tt_fire	dc.b	'FIRE: BACK TO PRACTICE',0
ghost_name	dc.b	'RCGhost0',0
str_prachint	dc.b	'{ } TRACK    ^ ` MODE',0
str_prachint2	dc.b	'FIRE: RACE   ESC: TITLE',0
champ_text
	dc.b	'YOU WON ALL THREE CUPS!',0
	dc.b	'THE BEST RC DRIVER IN THE WORLD.',0
	dc.b	' ',0
	dc.b	'THANK YOU FOR PLAYING',0
	dc.b	'RC TURBO CUP',0
	dc.b	' ',0
	dc.b	'CREATED BY MARK STRONKS, STRONKIE SOFT',0
	dc.b	0
cup_amateur	dc.b	'AMATEUR CUP',0
cup_national	dc.b	'NATIONAL CUP',0
cup_world	dc.b	'WORLD CHAMPIONSHIP',0
w_dry		dc.b	'DRY',0
w_rain		dc.b	'RAIN (SLIPPERY)',0
w_wind		dc.b	'WINDY',0
ps_sam		dc.b	'SPEEDY SAM',0
ps_carla	dc.b	'CAREFUL CARLA',0
ps_max		dc.b	'MAD MAX',0
ps_erik		dc.b	'ENGINEER ERIK',0
pd_sam		dc.b	'SPEEDY SAM    - FAST, CRASHES',0
pd_carla	dc.b	'CAREFUL CARLA - STEADY RACER',0
pd_max		dc.b	'MAD MAX       - ATTACKS YOU',0
pd_erik		dc.b	'ENGINEER ERIK - GRABS POWER-UPS',0
st_motor	dc.b	'MOTOR',0
st_tires	dc.b	'TIRES',0
st_batt		dc.b	'BATTERY',0
st_armor	dc.b	'ARMOR',0
sh_motor	dc.b	'MOTOR',0
sh_tires	dc.b	'TIRES',0
sh_batt		dc.b	'BATTERY',0
sh_armor	dc.b	'ARMOR',0
sh_rack		dc.b	'WEAPON RACK',0
sh_mis		dc.b	'2 MISSILES',0
sh_bomb		dc.b	'2 BOMBS',0
sh_spare	dc.b	'SPARE CAR',0
sh_paint	dc.b	'PAINT: ',0
sh_next		dc.b	'START NEXT RACE',0
tr_gold		dc.b	'GOLD TROPHY - CUP WINNER!',0
tr_silver	dc.b	'SILVER TROPHY - 2ND',0
tr_bronze	dc.b	'BRONZE TROPHY - 3RD',0
tr_none		dc.b	'NO TROPHY THIS TIME',0
	even
cup_names	dc.l	cup_amateur,cup_national,cup_world
weather_names	dc.l	w_dry,w_rain,w_wind
pers_short	dc.l	ps_sam,ps_carla,ps_max,ps_erik
pers_desc	dc.l	pd_sam,pd_carla,pd_max,pd_erik
stat_names	dc.l	st_motor,st_tires,st_batt,st_armor
shop_items	dc.l	sh_motor,sh_tires,sh_batt,sh_armor,sh_rack,sh_mis,sh_bomb,sh_spare,sh_paint,sh_next
trophy_texts	dc.l	tr_gold,tr_silver,tr_bronze,tr_none
shop_base	dc.w	500,350,400,300,400
prize_table	dc.w	1000,600,300,0
points_table	dc.w	10,6,3,1
wind_dirs	dc.w	9,0,0,9,-9,0,0,-9
	section	code,code

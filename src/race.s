;==============================================================================
;  race.s - the race: cars, physics, computer drivers, weapons, pickups, laps,
;  the HUD and the camera.  Runs 25 steps a second (every second frame).
;==============================================================================

; a car
C_X		equ	0	; .l world x * 256
C_Y		equ	4	; .l
C_VX		equ	8	; velocity (1/256 units a step)
C_VY		equ	10
C_ANG		equ	12	; heading 0..255 (0 = +x)
C_SPD		equ	14	; forward speed (1/256 units a step)
C_LAP		equ	16
C_WP		equ	18	; the nearest racing line point
C_HALF		equ	20	; passed half the lap
C_STUN		equ	22	; spinning
C_AIR		equ	24	; in the air
C_AIRMAX	equ	26
C_ZIP		equ	28
C_SHLD		equ	30
C_CAGE		equ	32
C_DMG		equ	34
C_AMMO		equ	36
C_WEAP		equ	38	; 0 none, 1 missiles, 2 bombs, 3 homing
C_TOP		equ	40
C_ACC		equ	42
C_GRIP		equ	44
C_TURN		equ	46
C_DES		equ	48	; car design 0..4
C_PERS		equ	50	; driver 0..3, -1 = you
C_FIN		equ	52	; finishing place (0 = still racing)
C_SX		equ	54	; position in the track picture
C_SY		equ	56
C_SURF		equ	58
C_LANE		equ	60
C_COOL		equ	62	; weapon cool down (computer)
C_SLIP		equ	64
C_ERR		equ	66
C_ERRT		equ	68
C_TURBO		equ	70
C_PROG		equ	72	; .l progress (for the places)
C_RANK		equ	76
C_LAPT		equ	78	; this lap (steps)
C_BEST		equ	80	; best lap (steps)
C_ARMOR		equ	82
C_ID		equ	84
C_GAS		equ	86
C_STEER		equ	88
C_BRAKE		equ	90
C_LASTS		equ	92
C_JH		equ	94
C_CAP		equ	96
C_TOTAL		equ	98	; .l race time (steps)
C_STUCK		equ	102
C_REV		equ	104
C_BAND		equ	106	; rubber band: top speed change
CARSZ		equ	128

; a weapon in flight (one per car)
W_ACT		equ	0	; 0 none, 1 missile, 2 bomb, 3 homing missile, 4 explosion
W_X		equ	2
W_Y		equ	6
W_VX		equ	10
W_VY		equ	12
W_T		equ	14
W_ANG		equ	16
W_TGT		equ	18
W_FR		equ	20
W_ARM		equ	22
W_OWN		equ	24
WSZ		equ	32

; a pickup spot
SP_TYPE		equ	0	; 0 empty, else icon + 1
SP_T		equ	2
SP_X		equ	4
SP_Y		equ	6
SP_BX		equ	8
SP_BY		equ	10
SP_WP		equ	12
SP_BG		equ	16	; the picture under the icon
SPSZ		equ	16+160
NSPOTS		equ	6

LAPS		equ	4
; a track_table entry
TE_NAME		equ	0
TE_PAL		equ	4
TE_WP		equ	8
TE_SPOTS	equ	12
TE_MM		equ	16
TE_GRID		equ	20
TE_WPR		equ	24
TE_GRIDR	equ	28
TE_NWP		equ	32
TE_MMK		equ	34
TE_MMX		equ	36
TE_MMY		equ	38
TE_LEN		equ	40
TE_SIZE		equ	42

;------------------------------------------------------------------------------
; race_setup: the track is unpacked; set up cars, pickups, HUD, colours
;------------------------------------------------------------------------------
race_setup:
	movem.l	d0-d7/a0-a6,-(sp)
	move.w	#-1,ovl_built
	clr.b	ovl_drawn
	moveq	#OVL_LIGHT0,d0		; the start lights, all off
	moveq	#0,d1
	bsr	show_ovl
	move.w	cur_track,d0
	mulu	#TE_SIZE,d0
	lea	track_table,a0
	add.l	d0,a0
	move.l	a0,trk_ptr
	move.l	TE_WP(a0),wp_ptr
	tst.b	race_reverse		; the other way round
	beq.s	.fw
	move.l	TE_WPR(a0),wp_ptr
.fw	move.w	TE_NWP(a0),nwp
	clr.l	race_step
	clr.w	race_phase
	clr.w	fin_count
	clr.w	msg_t
	clr.b	paused
	clr.w	ending_t
	; the cars
	lea	cars,a2
	moveq	#3,d7
.cl	move.w	#CARSZ/2-1,d0
	move.l	a2,a1
.z	clr.w	(a1)+
	dbf	d0,.z
	lea	CARSZ(a2),a2
	dbf	d7,.cl
	lea	weaps,a1
	move.w	#WSZ*4/2-1,d0
.zw	clr.w	(a1)+
	dbf	d0,.zw
	lea	bobsave,a1
	moveq	#3,d0
.zb	clr.w	BB_ON(a1)
	lea	BBSZ(a1),a1
	dbf	d0,.zb
	move.l	trk_ptr,a0
	move.l	TE_GRID(a0),a1		; the grid: 4 x (x.l, y.l, a.w)
	tst.b	race_reverse
	beq.s	.fg
	move.l	TE_GRIDR(a0),a1
.fg
	lea	cars,a2
	moveq	#0,d7
.grid	move.w	d7,C_ID(a2)
	; the grid place: you start last, the computer cars in front
	moveq	#3,d0
	tst.w	d7
	beq.s	.gp
	move.w	d7,d0
	subq.w	#1,d0
.gp	mulu	#10,d0
	move.l	(a1,d0.w),C_X(a2)
	move.l	4(a1,d0.w),C_Y(a2)
	move.w	8(a1,d0.w),C_ANG(a2)
	move.w	#9999,C_BEST(a2)
	bsr	car_stats
	bsr	car_screen
	bsr	find_wp
	lea	CARSZ(a2),a2
	addq.w	#1,d7
	cmp.w	#4,d7
	blo.s	.grid
	; lanes for the computer cars
	move.w	#-7,cars+CARSZ+C_LANE
	move.w	#0,cars+CARSZ*2+C_LANE
	move.w	#7,cars+CARSZ*3+C_LANE
	; colours: the track, the weather, the car paints
	bsr	race_palette
	; pickups and HUD
	bsr	spots_init
	bsr	hud_init
	; camera on your car
	lea	cars,a2
	move.w	C_SX(a2),d0
	sub.w	#160,d0
	move.w	C_SY(a2),d1
	sub.w	#108,d1
	move.w	d0,cam_x
	move.w	d1,cam_y
	bsr	clamp_cam
	move.w	cam_x,d0
	move.w	cam_y,d1
	bsr	set_scroll
	bsr	race_draw
	clr.w	eng_vol
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; car_stats: a2 = car, d7 = index (0 = you)
car_stats:
	movem.l	d0-d2/a0,-(sp)
	move.w	#-1,C_PERS(a2)
	tst.w	d7
	bne	.ai
	; you: the car class and the upgrades from the shop and the pickups
	moveq	#0,d0
	move.b	r_class,d0
	move.w	d0,C_DES(a2)
	move.w	d0,d1
	mulu	#40,d1
	add.w	#720,d1
	moveq	#0,d2
	move.b	r_motor,d2
	mulu	#44,d2
	add.w	d2,d1
	cmp.b	#6,r_paint		; the golden car: a little faster
	bne.s	.ng
	add.w	#30,d1
.ng	move.w	d1,C_TOP(a2)
	moveq	#0,d1
	move.b	r_battery,d1
	mulu	#3,d1
	add.w	#12,d1
	add.w	d0,d1
	move.w	d1,C_ACC(a2)
	moveq	#0,d1
	move.b	r_tires,d1
	move.w	d1,d2
	mulu	#14,d1
	add.w	#44,d1
	add.w	d0,d1
	add.w	d0,d1
	add.w	d0,d1
	add.w	d0,d1
	move.w	d1,C_GRIP(a2)
	lsr.w	#1,d2
	addq.w	#6,d2
	move.w	d0,d1
	lsr.w	#1,d1
	add.w	d1,d2
	move.w	d2,C_TURN(a2)
	moveq	#0,d1
	move.b	r_armor,d1
	move.w	d1,C_ARMOR(a2)
	moveq	#0,d1
	move.b	r_cap,d1
	addq.w	#2,d1
	move.w	d1,C_CAP(a2)
	moveq	#0,d1
	move.b	r_weap,d1
	move.w	d1,C_WEAP(a2)
	move.b	r_ammo,d1
	cmp.w	C_CAP(a2),d1
	bls.s	.am
	move.w	C_CAP(a2),d1
.am	move.w	d1,C_AMMO(a2)
	bra	.x
.ai	; a computer driver: who drives which car is set by the menus (race_pers)
	lea	race_pers,a0
	move.w	d7,d0
	subq.w	#1,d0
	add.w	d0,d0
	move.w	(a0,d0.w),d0
	move.w	d0,C_PERS(a2)
	moveq	#0,d1
	move.b	r_cup,d1
	add.w	d1,d1
	lea	ai_top,a0
	move.w	(a0,d1.w),d2		; base top speed for the cup
	lea	pers_top,a0
	add.w	d0,d0
	mulu	(a0,d0.w),d2
	lsr.l	#8,d2
	cmp.w	#3,C_PERS(a2)		; Engineer Erik: his upgrades
	bne.s	.ne
	moveq	#0,d0
	move.b	r_erik,d0
	mulu	#12,d0
	add.w	d0,d2
.ne	tst.b	practice
	beq.s	.np
	sub.w	#40,d2
.np	move.w	d2,C_TOP(a2)
	lea	ai_acc,a0
	move.w	(a0,d1.w),C_ACC(a2)
	lea	ai_grip,a0
	move.w	(a0,d1.w),C_GRIP(a2)
	lea	ai_turn,a0
	move.w	(a0,d1.w),C_TURN(a2)
	lea	ai_des,a0
	move.w	(a0,d1.w),d0
	add.w	d7,d0
	and.w	#1,d0
	lsr.w	#1,d1
	add.w	d1,d0
	add.w	d1,d0
	cmp.w	#4,d0
	bls.s	.dd
	moveq	#4,d0
.dd	move.w	d0,C_DES(a2)
	move.w	#4,C_CAP(a2)
	move.w	#1,C_WEAP(a2)		; one missile to start with
	move.w	#1,C_AMMO(a2)
	move.w	#40,C_COOL(a2)
	move.w	#1,C_ARMOR(a2)
.x	movem.l	(sp)+,d0-d2/a0
	rts

; race_palette: track colours (rain: darker and bluer), the car colours
race_palette:
	movem.l	d0-d4/a0-a1,-(sp)
	move.l	trk_ptr,a0
	move.l	4(a0),a0
	lea	race_cols,a1
	moveq	#15,d4
.c	move.w	(a0)+,d0
	cmp.b	#1,race_weather
	bne.s	.st
	move.w	d0,d1			; rain: r,g * 3/4, b * 3/4 + 3
	lsr.w	#8,d1
	and.w	#15,d1
	mulu	#3,d1
	lsr.w	#2,d1
	move.w	d0,d2
	lsr.w	#4,d2
	and.w	#15,d2
	mulu	#3,d2
	lsr.w	#2,d2
	move.w	d0,d3
	and.w	#15,d3
	mulu	#3,d3
	lsr.w	#2,d3
	addq.w	#3,d3
	cmp.w	#15,d3
	bls.s	.b
	moveq	#15,d3
.b	lsl.w	#8,d1
	lsl.w	#4,d2
	or.w	d2,d1
	or.w	d3,d1
	move.w	d1,d0
.st	move.w	d0,(a1)+
	dbf	d4,.c
	; 16-31: black, your paint, white, three drivers, red, yellow
	lea	race_shared,a1
	lea	shared_pal,a0
	moveq	#15,d0
.s	move.w	(a0)+,(a1)+
	dbf	d0,.s
	lea	race_shared,a1
	moveq	#0,d0
	move.b	r_paint,d0
	lsl.w	#2,d0
	lea	paint_pal,a0
	add.w	d0,a0
	move.w	(a0)+,4(a1)		; 18, 19: your car
	move.w	(a0)+,6(a1)
	lea	race_pers,a0
	moveq	#0,d1
.p	move.w	(a0)+,d0
	lsl.w	#2,d0
	lea	pers_pal,a1
	add.w	d0,a1
	lea	race_shared+12,a2	; 22, 23 / 26, 27 / 30, 31
	move.w	d1,d2
	lsl.w	#3,d2
	add.w	d2,a2
	move.w	(a1)+,(a2)+
	move.w	(a1)+,(a2)+
	addq.w	#1,d1
	cmp.w	#3,d1
	blo.s	.p
	movem.l	(sp)+,d0-d4/a0-a1
	rts

race_colours_on:
	lea	race_cols,a0
	bsr	set_race_cols
	bsr	hud_colours
	rts

;------------------------------------------------------------------------------
; the race state (every frame); a step every second frame
;------------------------------------------------------------------------------
st_race:
	move.w	act,d7
	tst.b	paused
	beq.s	.np
	btst	#A_ESC,d7
	bne.s	.quit
	move.w	d7,d0
	and.w	#(1<<A_FIRE)|(1<<A_P)|(1<<A_RET)|(1<<A_SPACE),d0
	beq.s	.rts
	clr.b	paused
	bsr	hud_msg_clear
.rts	rts
.quit	clr.b	paused
	st	race_quit
	bra	race_over
.np	move.w	d7,d0
	and.w	#(1<<A_ESC)|(1<<A_P),d0
	beq.s	.go
	tst.w	race_phase
	beq.s	.go
	st	paused
	clr.w	eng_vol
	lea	str_paused,a0
	move.w	#30000,d0
	bsr	hud_msg
	rts
.go	move.w	act,d0			; weapon presses are kept for the next step
	or.w	d0,step_act
	addq.w	#1,sub_frame
	btst	#0,sub_frame+1
	beq.s	.rts
	bsr	do_step
	bsr	race_draw
	clr.w	step_act
	rts

do_step:
	bsr	ovl_restore
	addq.l	#1,race_step
	move.w	race_phase,d0
	beq	countdown
	; racing (phase 1) or after your finish (phase 2)
	bsr	bobs_restore
	lea	cars,a2
	moveq	#3,d7
.cars	tst.w	C_PERS(a2)
	bpl.s	.ai
	cmp.w	#2,race_phase
	beq.s	.ai			; after the finish the computer drives your car
	bsr	player_control
	bra.s	.phys
.ai	bsr	ai_drive
.phys	bsr	car_physics
	bsr	car_progress
	lea	CARSZ(a2),a2
	dbf	d7,.cars
	bsr	car_collisions
	bsr	weapons_update
	bsr	spots_update
	bsr	rank_cars
	bsr	engine_sound
	bsr	hud_update
	cmp.w	#2,race_phase
	bne.s	.x
	addq.w	#1,ending_t
	cmp.w	#75,ending_t
	bhs	race_over
.x	rts

countdown:
	move.l	race_step,d0
	cmp.w	#1,d0
	beq.s	.three
	cmp.w	#26,d0
	beq.s	.two
	cmp.w	#51,d0
	beq.s	.one
	cmp.w	#76,d0
	beq.s	.go
	bsr	engine_sound
	bra	hud_update
.three	moveq	#OVL_LIGHT1,d0
	moveq	#S_V_THREE,d2
	lea	str_3,a0
	bra.s	.say
.two	moveq	#OVL_LIGHT2,d0
	moveq	#S_V_TWO,d2
	lea	str_2,a0
	bra.s	.say
.one	moveq	#OVL_LIGHT3,d0
	moveq	#S_V_ONE,d2
	lea	str_1,a0
.say	moveq	#0,d1
	bsr	show_ovl
	move.w	d2,d0
	bsr	sfx
	moveq	#30,d0
	bsr	hud_msg
	bra	hud_update
.go	moveq	#OVL_LIGHTGO,d0
	moveq	#30,d1
	bsr	show_ovl
	moveq	#S_V_GO,d0
	bsr	sfx
	lea	str_go,a0
	moveq	#30,d0
	bsr	hud_msg
	move.w	#1,race_phase
	move.w	cur_race_song,d0
	moveq	#40,d1
	bsr	play_song
	bra	hud_update

; race_over: to the results
race_over:
	clr.w	eng_vol
	bsr	rank_cars
	lea	st_results_in,a0
	bra	set_state

;------------------------------------------------------------------------------
; your controls
;------------------------------------------------------------------------------
player_control:
	move.w	held,d0
	move.w	step_act,d1
	clr.w	C_GAS(a2)
	clr.w	C_BRAKE(a2)
	clr.w	C_STEER(a2)
	tst.b	r_ctrl			; 0: up = gas, fire = weapon; 1: fire = gas, up = weapon
	bne.s	.alt
	btst	#A_UP,d0
	beq.s	.ng
	move.w	#1,C_GAS(a2)
.ng	btst	#A_FIRE,d1
	beq.s	.dir
	bsr	fire_weapon
	bra.s	.dir
.alt	btst	#A_FIRE,d0
	beq.s	.ng2
	move.w	#1,C_GAS(a2)
.ng2	btst	#A_UP,d1
	beq.s	.dir
	bsr	fire_weapon
.dir	move.w	d1,d2
	and.w	#(1<<A_FIRE2)|(1<<A_SPACE),d2
	beq.s	.nw
	bsr	fire_weapon
.nw	btst	#A_DOWN,d0
	beq.s	.nb
	move.w	#1,C_BRAKE(a2)
.nb	btst	#A_LEFT,d0
	beq.s	.nl
	move.w	#-1,C_STEER(a2)
.nl	btst	#A_RIGHT,d0
	beq.s	.nr
	move.w	#1,C_STEER(a2)
.nr	rts

;------------------------------------------------------------------------------
; the computer drivers
;------------------------------------------------------------------------------
ai_drive:
	movem.l	d0-d7/a0-a1/a3-a4,-(sp)
	clr.w	C_GAS(a2)
	clr.w	C_BRAKE(a2)
	clr.w	C_STEER(a2)
	move.w	C_PERS(a2),d6
	bpl.s	.p
	moveq	#1,d6			; your car after the finish: driven like Carla
.p	; stuck? back up for a moment
	tst.w	C_REV(a2)
	beq.s	.nrev
	subq.w	#1,C_REV(a2)
	move.w	#1,C_BRAKE(a2)
	move.w	#1,C_STEER(a2)
	bra	.x
.nrev	move.w	C_SPD(a2),d0
	bpl.s	.sp
	neg.w	d0
.sp	cmp.w	#50,d0
	bhs.s	.moving
	tst.w	C_STUN(a2)
	bne.s	.target
	addq.w	#1,C_STUCK(a2)
	cmp.w	#25,C_STUCK(a2)
	blo.s	.target
	clr.w	C_STUCK(a2)
	move.w	#14,C_REV(a2)
	bra	.x
.moving	clr.w	C_STUCK(a2)
.target	; the point to drive to: the racing line a few points ahead (more when fast), plus the lane
	move.w	C_SPD(a2),d0
	asr.w	#8,d0
	bpl.s	.lk
	moveq	#0,d0
.lk	addq.w	#2,d0
	add.w	C_WP(a2),d0
	bsr	wp_point		; d1 = x, d2 = y, d3 = tangent x*64, d4 = tangent y*64
	move.w	C_LANE(a2),d5
	muls	d5,d4			; lane * -ty / 64
	asr.l	#6,d4
	sub.w	d4,d1
	muls	d5,d3
	asr.l	#6,d3
	add.w	d3,d2
	; Engineer Erik: drive over the pickups
	cmp.w	#3,d6
	bne.s	.nerik
	bsr	ai_pickup_target
.nerik	; Mad Max: drive into you when you are just ahead
	cmp.w	#2,d6
	bne.s	.nmax
	bsr	ai_ram_target
.nmax	move.w	d1,d0
	move.l	C_X(a2),d3
	asr.l	#8,d3
	sub.w	d3,d0			; dx
	move.w	d2,d1
	move.l	C_Y(a2),d3
	asr.l	#8,d3
	sub.w	d3,d1			; dy
	bsr	atan2
	sub.w	C_ANG(a2),d0
	ext.w	d0			; (byte arithmetic: -128..127)
	; Speedy Sam makes mistakes
	tst.w	C_ERRT(a2)
	beq.s	.noerr
	subq.w	#1,C_ERRT(a2)
	add.w	C_ERR(a2),d0
	bra.s	.steer
.noerr	tst.w	d6
	bne.s	.steer
	move.w	d0,-(sp)
	move.w	#300,d0
	bsr	rand_n
	tst.w	d0
	bne.s	.nomis
	move.w	#16,C_ERRT(a2)
	move.w	#44,C_ERR(a2)
	bsr	random
	btst	#4,d0
	beq.s	.nomis
	neg.w	C_ERR(a2)
.nomis	move.w	(sp)+,d0
.steer	move.w	d0,d5			; d5 = the angle still to turn
	cmp.w	#2,d0
	ble.s	.nr
	move.w	#1,C_STEER(a2)
.nr	cmp.w	#-2,d0
	bge.s	.nl
	move.w	#-1,C_STEER(a2)
.nl	; speed: slow down for the bends ahead (each driver his own way)
	move.w	C_WP(a2),d0
	addq.w	#5,d0
	bsr	wp_point
	move.w	d3,d0
	move.w	d4,d1
	bsr	atan2
	sub.w	C_ANG(a2),d0
	ext.w	d0
	bpl.s	.ab
	neg.w	d0
.ab	lea	pers_caution,a0
	move.w	d6,d1
	add.w	d1,d1
	mulu	(a0,d1.w),d0		; bend * caution
	move.w	C_TOP(a2),d1
	add.w	C_BAND(a2),d1
	sub.w	d0,d1
	move.w	C_TOP(a2),d0
	lsr.w	#1,d0
	cmp.w	d0,d1
	bge.s	.mx
	move.w	d0,d1
.mx	move.w	C_SPD(a2),d0
	move.w	d5,d2
	bpl.s	.a2
	neg.w	d2
.a2	cmp.w	#70,d2			; a sharp turn: off the gas
	bhi.s	.coast
	sub.w	d1,d0
	cmp.w	#40,d0
	bgt.s	.brake
	tst.w	d0
	bgt.s	.coast
	move.w	#1,C_GAS(a2)
	bra.s	.weap
.brake	move.w	#1,C_BRAKE(a2)
.coast
.weap	; rubber band: close the gap to you a little
	bsr	ai_band
	; weapons
	tst.w	C_COOL(a2)
	beq.s	.cw
	subq.w	#1,C_COOL(a2)
	bra.s	.x
.cw	tst.w	C_AMMO(a2)
	beq.s	.x
	cmp.w	#1,race_phase
	bne.s	.x
	bsr	ai_weapons
.x	movem.l	(sp)+,d0-d7/a0-a1/a3-a4
	rts

; wp_point: d0 = racing line index (any) -> d1 = x, d2 = y, d3 = tx*64, d4 = ty*64
wp_point:
	move.l	a0,-(sp)
	ext.l	d0
	divs	nwp,d0
	swap	d0
	tst.w	d0
	bpl.s	.p
	add.w	nwp,d0
.p	mulu	#6,d0
	move.l	wp_ptr,a0
	add.l	d0,a0
	move.w	(a0)+,d1
	move.w	(a0)+,d2
	move.w	(a0),d3
	asr.w	#8,d3			; (tx, ty packed as two signed bytes)
	move.b	1(a0),d4
	ext.w	d4
	move.l	(sp)+,a0
	rts

; Erik: aim for a power-up 1..5 points ahead (d1/d2 = target, changed if found)
ai_pickup_target:
	movem.l	d0/d3-d5/a0,-(sp)
	lea	spots,a0
	moveq	#NSPOTS-1,d5
.l	move.w	SP_TYPE(a0),d0
	beq.s	.n
	bsr	ai_can_take
	beq.s	.n
	move.w	SP_WP(a0),d3
	sub.w	C_WP(a2),d3
	bpl.s	.d
	add.w	nwp,d3
.d	cmp.w	#1,d3
	blo.s	.n
	cmp.w	#5,d3
	bhi.s	.n
	move.w	SP_X(a0),d1
	move.w	SP_Y(a0),d2
	bra.s	.x
.n	lea	SPSZ(a0),a0
	dbf	d5,.l
.x	movem.l	(sp)+,d0/d3-d5/a0
	rts

; Max: ram you when you are 1..3 points ahead
ai_ram_target:
	movem.l	d0/d3,-(sp)
	move.w	cars+C_WP,d3
	sub.w	C_WP(a2),d3
	bpl.s	.d
	add.w	nwp,d3
.d	cmp.w	#1,d3
	blo.s	.x
	cmp.w	#3,d3
	bhi.s	.x
	move.l	cars+C_X,d1
	asr.l	#8,d1
	move.l	cars+C_Y,d2
	asr.l	#8,d2
.x	movem.l	(sp)+,d0/d3
	rts

; rubber band: d = your progress - mine (racing line points)
ai_band:
	movem.l	d0-d1,-(sp)
	clr.w	C_BAND(a2)
	tst.b	practice
	bne.s	.x
	move.l	cars+C_PROG,d0
	sub.l	C_PROG(a2),d0
	asr.l	#8,d0
	move.w	nwp,d1
	lsr.w	#2,d1
	cmp.w	d1,d0
	ble.s	.n1
	move.w	C_TOP(a2),d0		; far behind you: faster
	lsr.w	#3,d0
	move.w	d0,C_BAND(a2)
	bra.s	.x
.n1	neg.w	d1
	cmp.w	d1,d0
	bge.s	.x
	move.w	C_TOP(a2),d0		; far ahead of you: slower
	lsr.w	#4,d0
	neg.w	d0
	move.w	d0,C_BAND(a2)
.x	movem.l	(sp)+,d0-d1
	rts

; ai_weapons: fire at a car ahead, drop a bomb for a car behind
ai_weapons:
	movem.l	d0-d7/a0/a4,-(sp)
	lea	cars,a4
	moveq	#3,d7
.l	cmp.l	a4,a2
	beq	.n
	tst.w	C_FIN(a4)
	bne	.n
	move.l	C_X(a4),d0
	sub.l	C_X(a2),d0
	asr.l	#8,d0			; dx
	move.l	C_Y(a4),d1
	sub.l	C_Y(a2),d1
	asr.l	#8,d1			; dy
	move.w	C_ANG(a2),d2
	bsr	sincos			; d3 = cos, d4 = sin (*256)
	move.w	d0,d5
	muls	d3,d5
	move.w	d1,d6
	muls	d4,d6
	add.l	d6,d5
	asr.l	#8,d5			; along
	move.w	d1,d6
	muls	d3,d6
	move.w	d0,d2
	muls	d4,d2
	sub.l	d2,d6
	asr.l	#8,d6			; across
	bpl.s	.ac
	neg.w	d6
.ac	cmp.w	#2,C_WEAP(a2)
	beq.s	.bomb
	cmp.w	#20,d5
	blt.s	.n
	cmp.w	#150,d5
	bgt.s	.n
	moveq	#14,d2
	cmp.w	#3,C_WEAP(a2)
	bne.s	.w
	moveq	#60,d2
.w	cmp.w	d2,d6
	bgt.s	.n
	bra.s	.maybe
.bomb	cmp.w	#-60,d5
	blt.s	.n
	cmp.w	#-12,d5
	bgt.s	.n
	cmp.w	#16,d6
	bgt.s	.n
.maybe	moveq	#10,d0			; Mad Max fires at once, the others now and then
	cmp.w	#2,C_PERS(a2)
	bne.s	.r
	moveq	#2,d0
.r	bsr	rand_n
	tst.w	d0
	bne.s	.x
	bsr	fire_weapon
	move.w	#60,C_COOL(a2)
	cmp.w	#2,C_PERS(a2)
	bne.s	.x
	move.w	#30,C_COOL(a2)
	bra.s	.x
.n	lea	CARSZ(a4),a4
	dbf	d7,.l
.x	movem.l	(sp)+,d0-d7/a0/a4
	rts

;------------------------------------------------------------------------------
; maths
;------------------------------------------------------------------------------
; sincos: d2 = angle -> d3 = cos*256, d4 = sin*256
sincos:
	move.l	a0,-(sp)
	and.w	#255,d2
	add.w	d2,d2
	lea	sintab,a0
	move.w	(a0,d2.w),d4
	lea	128(a0),a0
	move.w	(a0,d2.w),d3
	lsr.w	#1,d2
	move.l	(sp)+,a0
	rts

; atan2: d0 = dx, d1 = dy (words) -> d0 = angle 0..255
atan2:
	movem.l	d1-d4/a0,-(sp)
	move.w	d0,d3			; signs
	move.w	d1,d4
	tst.w	d0
	bpl.s	.a
	neg.w	d0
.a	tst.w	d1
	bpl.s	.b
	neg.w	d1
.b	move.w	d0,d2
	or.w	d1,d2
	beq.s	.zero
	lea	atantab,a0
	cmp.w	d1,d0
	blo.s	.steep
	moveq	#0,d2			; |dy| <= |dx|: atan(dy/dx)
	move.w	d1,d2
	lsl.l	#6,d2
	divu	d0,d2
	moveq	#0,d0
	move.b	(a0,d2.w),d0
	bra.s	.q
.steep	moveq	#0,d2
	move.w	d0,d2
	lsl.l	#6,d2
	divu	d1,d2
	moveq	#64,d0
	moveq	#0,d1
	move.b	(a0,d2.w),d1
	sub.w	d1,d0
.q	tst.w	d3
	bpl.s	.qx
	neg.w	d0
	add.w	#128,d0
.qx	tst.w	d4
	bpl.s	.qy
	neg.w	d0
.qy	and.w	#255,d0
	movem.l	(sp)+,d1-d4/a0
	rts
.zero	moveq	#0,d0
	movem.l	(sp)+,d1-d4/a0
	rts

; surf_at: d0 = x, d1 = y (world * 256, longs) -> d0 = the surface there
surf_at:
	movem.l	d1-d2/a0,-(sp)
	move.l	d0,d2
	sub.l	d1,d2
	asr.l	#8,d2
	add.l	#320,d2			; screen x
	add.l	d1,d0
	asr.l	#8,d0
	asr.l	#1,d0			; screen y
	cmp.l	#WW,d2
	bhs.s	.wall
	cmp.l	#WH,d0
	bhs.s	.wall
	lsr.w	#1,d0
	mulu	#SURF_W,d0
	lsr.w	#2,d2
	add.w	d2,d0
	lea	surfmap,a0
	moveq	#0,d1
	move.b	(a0,d0.l),d1
	move.l	d1,d0
	movem.l	(sp)+,d1-d2/a0
	rts
.wall	moveq	#SURF_WALL,d0
	movem.l	(sp)+,d1-d2/a0
	rts

; car_screen: a2 = car -> C_SX, C_SY
car_screen:
	movem.l	d0-d1,-(sp)
	move.l	C_X(a2),d0
	sub.l	C_Y(a2),d0
	asr.l	#8,d0
	add.w	#320,d0
	move.w	d0,C_SX(a2)
	move.l	C_X(a2),d0
	add.l	C_Y(a2),d0
	asr.l	#8,d0
	asr.w	#1,d0
	move.w	d0,C_SY(a2)
	movem.l	(sp)+,d0-d1
	rts

; find_wp: the nearest racing line point (all of them)
find_wp:
	movem.l	d0-d6/a0,-(sp)
	move.l	C_X(a2),d3
	asr.l	#8,d3
	move.l	C_Y(a2),d4
	asr.l	#8,d4
	move.l	wp_ptr,a0
	move.w	#$7fff,d5		; best distance
	moveq	#0,d6
	moveq	#0,d0
.l	move.w	(a0),d1
	sub.w	d3,d1
	bpl.s	.a
	neg.w	d1
.a	move.w	2(a0),d2
	sub.w	d4,d2
	bpl.s	.b
	neg.w	d2
.b	add.w	d2,d1
	cmp.w	d5,d1
	bge.s	.n
	move.w	d1,d5
	move.w	d0,d6
.n	addq.l	#6,a0
	addq.w	#1,d0
	cmp.w	nwp,d0
	blo.s	.l
	move.w	d6,C_WP(a2)
	movem.l	(sp)+,d0-d6/a0
	rts

;------------------------------------------------------------------------------
; physics: one step for car a2 (C_GAS, C_BRAKE, C_STEER set)
;------------------------------------------------------------------------------
car_physics:
	movem.l	d0-d7/a0-a1,-(sp)
	addq.w	#1,C_LAPT(a2)
	tst.w	C_FIN(a2)
	bne.s	.tt
	addq.l	#1,C_TOTAL(a2)
.tt	tst.w	C_SHLD(a2)
	beq.s	.nsh
	subq.w	#1,C_SHLD(a2)
.nsh	tst.w	C_STUN(a2)		; spinning: no control
	beq.s	.nst
	subq.w	#1,C_STUN(a2)
	add.w	#22,C_ANG(a2)
	and.w	#255,C_ANG(a2)
	clr.w	C_GAS(a2)
	clr.w	C_STEER(a2)
	move.w	#1,C_BRAKE(a2)
.nst	; the top speed now: damage, turbo, zippers, rubber band
	move.w	C_TOP(a2),d6
	add.w	C_BAND(a2),d6
	move.w	C_DMG(a2),d0
	mulu	d6,d0
	moveq	#9,d1
	lsr.l	d1,d0
	sub.w	d0,d6
	tst.w	C_TURBO(a2)
	beq.s	.ntu
	subq.w	#1,C_TURBO(a2)
	move.w	d6,d0
	lsr.w	#2,d0
	add.w	d0,d6
.ntu	tst.w	C_ZIP(a2)
	beq.s	.nzi
	subq.w	#1,C_ZIP(a2)
	move.w	d6,d0
	lsr.w	#1,d0
	add.w	d0,d6
.nzi	move.w	C_GRIP(a2),d5		; d5 = grip
	cmp.b	#1,race_weather
	bne.s	.dry
	move.w	d5,d0
	lsr.w	#2,d0
	sub.w	d0,d5
.dry	; the ground
	tst.w	C_AIR(a2)
	beq	.ground
	subq.w	#1,C_AIR(a2)
	bne.s	.inair
	tst.w	C_PERS(a2)
	bpl.s	.inair
	moveq	#S_DROP,d0
	bsr	sfx
.inair	moveq	#0,d5			; no grip in the air
	clr.w	C_STEER(a2)
	move.w	#SURF_ROAD,C_SURF(a2)
	bra	.drive
.ground	move.l	C_X(a2),d0
	move.l	C_Y(a2),d1
	bsr	surf_at
	move.w	d0,C_SURF(a2)
	move.w	C_LASTS(a2),d4
	move.w	d0,C_LASTS(a2)
	cmp.w	#SURF_GRASS,d0
	bne.s	.s1
	mulu	#9,d6
	lsr.l	#4,d6
	bra	.drive
.s1	cmp.w	#SURF_SAND,d0
	bne.s	.s2
	mulu	#7,d6
	lsr.l	#4,d6
	bra	.drive
.s2	cmp.w	#SURF_WATER,d0
	bne.s	.s3
	mulu	#10,d6
	lsr.l	#4,d6
	lsr.w	#1,d5
	cmp.w	d0,d4
	beq	.drive
	moveq	#S_SPLASH,d0
	bsr	car_sfx
	bra	.drive
.s3	cmp.w	#SURF_OIL,d0
	bne.s	.s4
	cmp.w	d0,d4
	beq.s	.oil
	moveq	#S_SKID,d0
	bsr	car_sfx
.oil	move.w	#16,C_SLIP(a2)
	bra	.drive
.s4	cmp.w	#SURF_MARBLE,d0
	bne.s	.s5
	moveq	#11,d0
	bsr	rand_n
	subq.w	#5,d0
	add.w	d0,C_ANG(a2)
	and.w	#255,C_ANG(a2)
	lsr.w	#1,d5
	bra	.drive
.s5	cmp.w	#SURF_BUMP,d0
	bne.s	.s6
	cmp.w	d0,d4
	beq	.drive
	move.w	C_SPD(a2),d0
	asr.w	#2,d0
	sub.w	d0,C_SPD(a2)
	move.w	#4,C_AIR(a2)
	move.w	#4,C_AIRMAX(a2)
	moveq	#S_BONK,d0
	bsr	car_sfx
	bra	.drive
.s6	cmp.w	#SURF_ZAP,d0
	bne.s	.s7
	cmp.w	d0,d4
	beq	.drive
	tst.w	C_SHLD(a2)
	bne	.drive
	move.w	#16,C_STUN(a2)
	moveq	#S_ZAP,d0
	bsr	car_sfx
	bra	.drive
.s7	cmp.w	#SURF_ZIP,d0
	bne.s	.s8
	cmp.w	d0,d4
	beq	.drive
	move.w	#22,C_ZIP(a2)
	move.w	d6,d0
	lsr.w	#1,d0
	add.w	d0,d6
	tst.w	C_SPD(a2)
	ble.s	.zs
	move.w	d6,C_SPD(a2)
.zs	moveq	#S_ZIP,d0
	bsr	car_sfx
	bra.s	.drive
.s8	cmp.w	#SURF_RAMP,d0
	bne.s	.drive
	move.w	d6,d0
	lsr.w	#2,d0
	cmp.w	C_SPD(a2),d0
	bge.s	.drive
	move.w	C_SPD(a2),d0		; into the air: longer when faster
	lsr.w	#6,d0
	addq.w	#5,d0
	move.w	d0,C_AIR(a2)
	move.w	d0,C_AIRMAX(a2)
	moveq	#S_BOING,d0
	bsr	car_sfx
.drive	; oil: no grip for a while
	tst.w	C_SLIP(a2)
	beq.s	.nsl
	subq.w	#1,C_SLIP(a2)
	moveq	#6,d5
	moveq	#5,d0
	bsr	rand_n
	subq.w	#2,d0
	add.w	d0,C_ANG(a2)
	and.w	#255,C_ANG(a2)
.nsl	; steering (less when slow, reversed when backing up)
	move.w	C_STEER(a2),d0
	beq.s	.nost
	move.w	C_TURN(a2),d1
	move.w	C_SPD(a2),d2
	bpl.s	.sp
	neg.w	d2
	neg.w	d0
.sp	cmp.w	#220,d2
	bhs.s	.full
	cmp.w	#110,d2			; at least half the steering, even standing still
	bhs.s	.lo
	move.w	#110,d2
.lo	mulu	d2,d1
	divu	#220,d1
.full	muls	d1,d0
	add.w	d0,C_ANG(a2)
	and.w	#255,C_ANG(a2)
.nost	; gas, brake, coasting
	move.w	C_SPD(a2),d0
	tst.w	C_GAS(a2)
	beq.s	.nogas
	cmp.w	d6,d0
	bge.s	.over
	add.w	C_ACC(a2),d0
	cmp.w	d6,d0
	ble.s	.spd
	move.w	d6,d0
	bra.s	.spd
.nogas	tst.w	C_BRAKE(a2)
	beq.s	.coast
	tst.w	d0
	ble.s	.rev
	sub.w	#28,d0
	bra.s	.spd
.rev	move.w	C_ACC(a2),d1
	lsr.w	#1,d1
	sub.w	d1,d0
	move.w	d6,d1
	lsr.w	#2,d1
	neg.w	d1
	cmp.w	d1,d0
	bge.s	.spd
	move.w	d1,d0
	bra.s	.spd
.coast	move.w	d0,d1
	asr.w	#5,d1
	sub.w	d1,d0
	bra	.lim
.over	; faster than the top speed (zipper ended, onto the grass): slow down
.lim	cmp.w	d6,d0
	ble.s	.spd
	move.w	d0,d1
	sub.w	d6,d1
	asr.w	#3,d1
	addq.w	#4,d1
	sub.w	d1,d0
.spd	move.w	d0,C_SPD(a2)
	; velocity follows the heading as much as the grip allows
	move.w	C_ANG(a2),d2
	bsr	sincos
	muls	d0,d3
	asr.l	#8,d3			; wanted vx
	muls	d0,d4
	asr.l	#8,d4			; wanted vy
	sub.w	C_VX(a2),d3
	muls	d5,d3
	asr.l	#8,d3
	add.w	d3,C_VX(a2)
	sub.w	C_VY(a2),d4
	muls	d5,d4
	asr.l	#8,d4
	add.w	d4,C_VY(a2)
	move.w	wind_x,d0
	add.w	d0,C_VX(a2)
	move.w	wind_y,d0
	add.w	d0,C_VY(a2)
	; move, with the walls
	move.w	C_VX(a2),d2
	ext.l	d2
	move.w	C_VY(a2),d3
	ext.l	d3
	move.l	C_X(a2),d0
	move.l	C_Y(a2),d1
	bsr	surf_at
	cmp.w	#SURF_WALL,d0
	beq	.free			; (stuck in a wall: let it out)
	move.l	C_X(a2),d0
	add.l	d2,d0
	move.l	C_Y(a2),d1
	add.l	d3,d1
	bsr	surf_at
	cmp.w	#SURF_WALL,d0
	bne	.free
	; a wall: slide along it if one direction is free
	move.l	C_X(a2),d0
	add.l	d2,d0
	move.l	C_Y(a2),d1
	bsr	surf_at
	cmp.w	#SURF_WALL,d0
	beq.s	.try_y
	add.l	d2,C_X(a2)
	move.w	C_VY(a2),d0
	bsr	wall_hit
	move.w	C_VY(a2),d0
	neg.w	d0
	asr.w	#1,d0
	move.w	d0,C_VY(a2)
	bsr	wall_unstick
	bra.s	.moved
.try_y	move.l	C_X(a2),d0
	move.l	C_Y(a2),d1
	add.l	d3,d1
	bsr	surf_at
	cmp.w	#SURF_WALL,d0
	beq.s	.stop
	add.l	d3,C_Y(a2)
	move.w	C_VX(a2),d0
	bsr	wall_hit
	move.w	C_VX(a2),d0
	neg.w	d0
	asr.w	#1,d0
	move.w	d0,C_VX(a2)
	bsr	wall_unstick
	bra.s	.moved
.stop	move.w	C_SPD(a2),d0
	bsr	wall_hit
	move.w	C_VX(a2),d0
	neg.w	d0
	asr.w	#1,d0
	move.w	d0,C_VX(a2)
	move.w	C_VY(a2),d0
	neg.w	d0
	asr.w	#1,d0
	move.w	d0,C_VY(a2)
	move.w	C_SPD(a2),d0
	asr.w	#2,d0
	neg.w	d0
	move.w	d0,C_SPD(a2)
	bsr	wall_unstick
	bra.s	.moved
.free	add.l	d2,C_X(a2)
	add.l	d3,C_Y(a2)
.moved	; the jump height for the picture
	moveq	#0,d0
	move.w	C_AIR(a2),d1
	beq.s	.jh
	move.w	C_AIRMAX(a2),d0
	sub.w	d1,d0
	mulu	d1,d0
	lsr.w	#2,d0
	cmp.w	#14,d0
	bls.s	.jh
	moveq	#14,d0
.jh	move.w	d0,C_JH(a2)
	bsr	car_screen
	movem.l	(sp)+,d0-d7/a0-a1
	rts

; wall_unstick: after a wall hit, push the car 3/4 unit towards the racing line
; (the point after its nearest one), so it does not stay stuck against the wall
wall_unstick:
	movem.l	d0-d4,-(sp)
	move.w	C_WP(a2),d0
	addq.w	#1,d0
	bsr	wp_point		; d1, d2 = the point
	move.l	C_X(a2),d0
	asr.l	#8,d0
	sub.w	d0,d1
	move.l	C_Y(a2),d0
	asr.l	#8,d0
	sub.w	d0,d2
	move.w	d1,d0
	move.w	d2,d1
	bsr	atan2
	move.w	d0,d2
	; slow against the wall: turn a little towards the track by itself
	move.w	C_SPD(a2),d1
	bpl.s	.ab
	neg.w	d1
.ab	cmp.w	#250,d1
	bhs.s	.noturn
	move.w	d0,d1
	sub.w	C_ANG(a2),d1
	ext.w	d1
	moveq	#5,d3
	cmp.w	d3,d1
	ble.s	.t1
	move.w	d3,d1
.t1	neg.w	d3
	cmp.w	d3,d1
	bge.s	.t2
	move.w	d3,d1
.t2	add.w	d1,C_ANG(a2)
	and.w	#255,C_ANG(a2)
.noturn	bsr	sincos			; d3 = cos, d4 = sin (*256)
	muls	#3,d3
	asr.l	#2,d3
	muls	#3,d4
	asr.l	#2,d4
	move.l	C_X(a2),d0		; only into free space
	add.l	d3,d0
	move.l	C_Y(a2),d1
	add.l	d4,d1
	bsr	surf_at
	cmp.w	#SURF_WALL,d0
	beq.s	.x
	add.l	d3,C_X(a2)
	add.l	d4,C_Y(a2)
.x	movem.l	(sp)+,d0-d4
	rts

; wall_hit: d0 = the speed into the wall: slow down, damage, a bump sound
wall_hit:
	movem.l	d0-d1,-(sp)
	tst.w	d0
	bpl.s	.p
	neg.w	d0
.p	move.w	C_SPD(a2),d1
	asr.w	#1,d1
	move.w	d1,C_SPD(a2)
	lsr.w	#5,d0			; impact
	cmp.w	#7,d0
	blo.s	.x
	tst.w	C_SHLD(a2)
	bne.s	.snd
	tst.w	C_CAGE(a2)		; the roll cage takes the hard knocks
	beq.s	.dmg
	cmp.w	#20,d0
	blo.s	.snd
	subq.w	#1,C_CAGE(a2)
	bra.s	.snd
.dmg	moveq	#6,d1
	sub.w	C_ARMOR(a2),d1
	mulu	d1,d0
	divu	#12,d0
	add.w	d0,C_DMG(a2)
	cmp.w	#100,C_DMG(a2)
	blo.s	.snd
	move.w	#50,C_DMG(a2)		; broken down: a long spin
	move.w	#40,C_STUN(a2)
	moveq	#S_BOOM,d0
	bsr	car_sfx
	bra.s	.x
.snd	moveq	#S_BONK,d0
	bsr	car_sfx
.x	movem.l	(sp)+,d0-d1
	rts

; car_sfx: d0 = sound, only for your car (and only racing)
car_sfx:
	tst.w	C_PERS(a2)
	bpl.s	.x
	bsr	sfx
.x	rts

;------------------------------------------------------------------------------
; laps and places
;------------------------------------------------------------------------------
car_progress:
	movem.l	d0-d7/a0,-(sp)
	move.l	C_X(a2),d3
	asr.l	#8,d3
	move.l	C_Y(a2),d4
	asr.l	#8,d4
	move.w	C_WP(a2),d6		; old
	move.w	#$7fff,d5
	moveq	#-2,d7			; search old-2 .. old+24
	move.w	d6,d2			; best
.l	move.w	d6,d0
	add.w	d7,d0
	bpl.s	.p
	add.w	nwp,d0
.p	cmp.w	nwp,d0
	blo.s	.q
	sub.w	nwp,d0
.q	move.w	d0,-(sp)
	mulu	#6,d0
	move.l	wp_ptr,a0
	add.l	d0,a0
	move.w	(a0),d0
	sub.w	d3,d0
	bpl.s	.a
	neg.w	d0
.a	move.w	2(a0),d1
	sub.w	d4,d1
	bpl.s	.b
	neg.w	d1
.b	add.w	d1,d0
	move.w	(sp)+,d1
	cmp.w	d5,d0
	bge.s	.n
	move.w	d0,d5
	move.w	d1,d2
.n	addq.w	#1,d7
	cmp.w	#24,d7
	ble.s	.l
	move.w	d2,C_WP(a2)
	; crossing the line forwards?
	move.w	nwp,d0
	lsr.w	#2,d0			; N/4
	move.w	nwp,d1
	sub.w	d0,d1			; 3N/4
	cmp.w	d1,d6
	blo.s	.nocross
	cmp.w	d0,d2
	bhs.s	.nocross
	tst.w	C_HALF(a2)
	beq.s	.nocross
	clr.w	C_HALF(a2)
	tst.w	C_FIN(a2)
	bne.s	.nocross
	bsr	lap_done
.nocross
	move.w	nwp,d0
	lsr.w	#1,d0
	cmp.w	d0,d2
	blo.s	.nh
	cmp.w	d1,d2
	bhs.s	.nh
	move.w	#1,C_HALF(a2)
.nh	; progress = (lap * N + point) * 256 + nearness (behind the line at the start: negative)
	move.w	d2,d7
	move.w	C_LAP(a2),d0
	mulu	nwp,d0
	add.w	d7,d0
	ext.l	d0
	cmp.w	d1,d7
	blo.s	.pr2
	tst.w	C_HALF(a2)
	bne.s	.pr2
	move.w	nwp,d1
	ext.l	d1
	sub.l	d1,d0
.pr2	asl.l	#8,d0
	move.w	d7,d1
	addq.w	#1,d1
	cmp.w	nwp,d1
	blo.s	.nx
	moveq	#0,d1
.nx	mulu	#6,d1
	move.l	wp_ptr,a0
	add.l	d1,a0
	move.w	(a0),d1
	sub.w	d3,d1
	bpl.s	.c
	neg.w	d1
.c	move.w	2(a0),d5
	sub.w	d4,d5
	bpl.s	.e
	neg.w	d5
.e	add.w	d5,d1
	cmp.w	#255,d1
	bls.s	.f
	move.w	#255,d1
.f	neg.w	d1
	add.w	#255,d1
	ext.l	d1
	add.l	d1,d0
	tst.w	C_FIN(a2)		; finished cars: by their place
	beq.s	.g
	move.l	#$7fff0000,d0
	move.w	C_FIN(a2),d1
	swap	d1
	clr.w	d1
	sub.l	d1,d0
.g	move.l	d0,C_PROG(a2)
	movem.l	(sp)+,d0-d7/a0
	rts

; lap_done: car a2 crossed the line after a full lap
lap_done:
	movem.l	d0-d1/a0,-(sp)
	move.w	C_LAPT(a2),d0
	move.w	d0,lap_last
	cmp.w	C_BEST(a2),d0
	bhs.s	.nb
	move.w	d0,C_BEST(a2)
.nb	clr.w	C_LAPT(a2)
	addq.w	#1,C_LAP(a2)
	cmp.w	#LAPS,C_LAP(a2)
	blo.s	.more
	addq.w	#1,fin_count
	move.w	fin_count,C_FIN(a2)
	tst.w	C_PERS(a2)
	bpl	.x
	move.w	#2,race_phase		; you finished
	clr.w	ending_t
	moveq	#OVL_FINISH,d0
	moveq	#0,d1
	bsr	show_ovl
	moveq	#S_V_FINISH,d0
	bsr	sfx
	moveq	#S_CHEER,d0		; and the crowd goes wild
	bsr	sfx_after
	lea	str_finish,a0
	moveq	#100,d0
	bsr	hud_msg
	bra.s	.x
.more	tst.w	C_PERS(a2)
	bpl.s	.x
	moveq	#S_BEEP,d0
	bsr	sfx
	; the big text: LAP 2, LAP 3, FINAL LAP! (or NEW RECORD!)
	move.w	C_LAP(a2),d0
	add.w	#OVL_LAP2-1,d0
	move.w	cur_track,d1		; faster than the best lap ever here?
	add.w	d1,d1
	lea	r_best,a0
	add.w	d1,a0
	tst.w	(a0)
	beq.s	.nr
	move.w	lap_last,d1
	cmp.w	(a0),d1
	bhs.s	.nr
	moveq	#OVL_RECORD,d0
.nr	moveq	#40,d1
	bsr	show_ovl
	lea	str_lap,a0
	cmp.w	#LAPS-1,C_LAP(a2)
	bne.s	.m
	lea	str_lastlap,a0
.m	moveq	#40,d0
	bsr	hud_msg
.x	movem.l	(sp)+,d0-d1/a0
	rts

; rank_cars: C_RANK 1..4 by progress
rank_cars:
	movem.l	d0-d3/a0-a1,-(sp)
	lea	cars,a0
	moveq	#3,d3
.l	moveq	#1,d0
	lea	cars,a1
	moveq	#3,d2
.k	cmp.l	a0,a1
	beq.s	.s
	move.l	C_PROG(a1),d1
	cmp.l	C_PROG(a0),d1
	blt.s	.s
	bgt.s	.ahead
	cmp.l	a0,a1			; a tie: the lower number first
	bhi.s	.s
.ahead	addq.w	#1,d0
.s	lea	CARSZ(a1),a1
	dbf	d2,.k
	move.w	d0,C_RANK(a0)
	lea	CARSZ(a0),a0
	dbf	d3,.l
	movem.l	(sp)+,d0-d3/a0-a1
	rts

;------------------------------------------------------------------------------
; cars bumping into each other
;------------------------------------------------------------------------------
car_collisions:
	movem.l	d0-d7/a3-a4,-(sp)
	lea	cars,a3
	moveq	#0,d6
.i	lea	CARSZ(a3),a4
	move.w	d6,d7
	addq.w	#1,d7
.j	cmp.w	#4,d7
	bhs	.ni
	tst.w	C_AIR(a3)
	bne	.nj
	tst.w	C_AIR(a4)
	bne	.nj
	move.l	C_X(a4),d0
	sub.l	C_X(a3),d0
	asr.l	#8,d0
	move.l	C_Y(a4),d1
	sub.l	C_Y(a3),d1
	asr.l	#8,d1
	move.w	d0,d2
	bpl.s	.a
	neg.w	d2
.a	cmp.w	#9,d2
	bge.s	.nj
	move.w	d1,d3
	bpl.s	.b
	neg.w	d3
.b	cmp.w	#9,d3
	bge.s	.nj
	add.w	d3,d2
	cmp.w	#12,d2
	bge.s	.nj
	; push apart, swap some speed
	move.w	d0,d2
	lsl.w	#5,d2
	move.w	d1,d3
	lsl.w	#5,d3
	ext.l	d2
	ext.l	d3
	sub.l	d2,C_X(a3)
	sub.l	d3,C_Y(a3)
	add.l	d2,C_X(a4)
	add.l	d3,C_Y(a4)
	move.w	C_VX(a3),d2
	move.w	C_VX(a4),d3
	add.w	d2,d3
	asr.w	#1,d3
	move.w	d3,C_VX(a3)
	move.w	d3,C_VX(a4)
	move.w	C_VY(a3),d2
	move.w	C_VY(a4),d3
	add.w	d2,d3
	asr.w	#1,d3
	move.w	d3,C_VY(a3)
	move.w	d3,C_VY(a4)
	move.w	C_SPD(a3),d2
	sub.w	C_SPD(a4),d2
	bpl.s	.c
	neg.w	d2
.c	cmp.w	#200,d2
	blo.s	.nj
	move.l	a2,-(sp)
	move.l	a3,a2
	moveq	#S_BONK,d0
	bsr	car_sfx
	move.l	a4,a2
	bsr	car_sfx
	move.l	(sp)+,a2
.nj	lea	CARSZ(a4),a4
	addq.w	#1,d7
	bra	.j
.ni	lea	CARSZ(a3),a3
	addq.w	#1,d6
	cmp.w	#3,d6
	blo	.i
	movem.l	(sp)+,d0-d7/a3-a4
	rts

;------------------------------------------------------------------------------
; weapons
;------------------------------------------------------------------------------
; fire_weapon: car a2 uses its weapon
fire_weapon:
	movem.l	d0-d4/a3,-(sp)
	tst.w	C_AMMO(a2)
	beq	.x
	tst.w	C_STUN(a2)
	bne	.x
	cmp.w	#1,race_phase
	bne	.x
	move.w	C_ID(a2),d0
	mulu	#WSZ,d0
	lea	weaps,a3
	add.l	d0,a3
	tst.w	W_ACT(a3)
	bne	.x
	move.w	C_ID(a2),W_OWN(a3)
	move.w	C_ANG(a2),d2
	move.w	d2,W_ANG(a3)
	bsr	sincos
	move.w	C_WEAP(a2),d0
	move.w	d0,W_ACT(a3)
	cmp.w	#2,d0
	beq.s	.bomb
	; a missile: in front of the car
	move.w	d3,d0
	muls	#12,d0
	add.l	C_X(a2),d0
	move.l	d0,W_X(a3)
	move.w	d4,d0
	muls	#12,d0
	add.l	C_Y(a2),d0
	move.l	d0,W_Y(a3)
	move.w	#45,W_T(a3)
	move.w	#-1,W_TGT(a3)
	cmp.w	#3,W_ACT(a3)
	bne.s	.m
	move.w	#80,W_T(a3)
	bsr	homing_target
.m	moveq	#S_LAUNCH,d0
	bsr	sfx
	bra.s	.used
.bomb	move.w	d3,d0			; a bomb: behind the car
	muls	#-14,d0
	add.l	C_X(a2),d0
	move.l	d0,W_X(a3)
	move.w	d4,d0
	muls	#-14,d0
	add.l	C_Y(a2),d0
	move.l	d0,W_Y(a3)
	clr.w	W_VX(a3)
	clr.w	W_VY(a3)
	move.w	#250,W_T(a3)
	move.w	#15,W_ARM(a3)
	moveq	#S_DROP,d0
	bsr	sfx
.used	subq.w	#1,C_AMMO(a2)
	bne.s	.x
	clr.w	C_WEAP(a2)
.x	movem.l	(sp)+,d0-d4/a3
	rts

; homing_target: the car just ahead of a2 (by place) -> W_TGT(a3)
homing_target:
	movem.l	d0-d1/a0,-(sp)
	move.w	C_RANK(a2),d0
	subq.w	#1,d0
	bne.s	.f
	moveq	#2,d0			; leading: go for the second
.f	lea	cars,a0
	moveq	#3,d1
.l	cmp.w	C_RANK(a0),d0
	bne.s	.n
	cmp.l	a0,a2
	beq.s	.n
	move.w	C_ID(a0),W_TGT(a3)
	bra.s	.x
.n	lea	CARSZ(a0),a0
	dbf	d1,.l
.x	movem.l	(sp)+,d0-d1/a0
	rts

weapons_update:
	movem.l	d0-d7/a2-a4,-(sp)
	lea	weaps,a3
	moveq	#3,d7
.l	move.w	W_ACT(a3),d0
	beq	.n
	cmp.w	#4,d0
	beq	.expl
	cmp.w	#2,d0
	beq	.bomb
	; missiles: steer (homing), fly, hit
	cmp.w	#3,d0
	bne.s	.fly
	move.w	W_TGT(a3),d0
	bmi.s	.fly
	mulu	#CARSZ,d0
	lea	cars,a4
	add.l	d0,a4
	move.l	C_X(a4),d0
	sub.l	W_X(a3),d0
	asr.l	#8,d0
	move.l	C_Y(a4),d1
	sub.l	W_Y(a3),d1
	asr.l	#8,d1
	bsr	atan2
	sub.w	W_ANG(a3),d0
	ext.w	d0
	moveq	#5,d1
	cmp.w	d1,d0
	ble.s	.h1
	move.w	d1,d0
.h1	neg.w	d1
	cmp.w	d1,d0
	bge.s	.h2
	move.w	d1,d0
.h2	add.w	d0,W_ANG(a3)
	and.w	#255,W_ANG(a3)
.fly	move.w	W_ANG(a3),d2
	bsr	sincos
	muls	#7,d3
	muls	#7,d4
	add.l	d3,W_X(a3)
	add.l	d4,W_Y(a3)
	move.l	W_X(a3),d0
	move.l	W_Y(a3),d1
	bsr	surf_at
	cmp.w	#SURF_WALL,d0
	beq	.boom
	bsr	weapon_hits
	tst.l	d0
	bne	.boom
	subq.w	#1,W_T(a3)
	bne	.n
	clr.w	W_ACT(a3)
	bra	.n
.bomb	tst.w	W_ARM(a3)
	beq.s	.armed
	subq.w	#1,W_ARM(a3)
	bra.s	.bt
.armed	bsr	weapon_hits
	tst.l	d0
	bne.s	.boom
.bt	subq.w	#1,W_T(a3)
	bne.s	.n
.boom	move.w	#4,W_ACT(a3)		; explosion
	clr.w	W_FR(a3)
	moveq	#S_BOOM,d0
	bsr	sfx
	bra.s	.n
.expl	addq.w	#1,W_FR(a3)
	cmp.w	#8,W_FR(a3)
	blo.s	.n
	clr.w	W_ACT(a3)
.n	lea	WSZ(a3),a3
	dbf	d7,.l
	movem.l	(sp)+,d0-d7/a2-a4
	rts

; weapon_hits: does weapon a3 hit a car? -> d0 = 1 and the car is hit
weapon_hits:
	movem.l	d1-d4/a2,-(sp)
	lea	cars,a2
	moveq	#3,d4
.l	cmp.w	#2,W_ACT(a3)		; (bombs hit their owner too)
	beq.s	.any
	move.w	C_ID(a2),d0
	cmp.w	W_OWN(a3),d0
	beq.s	.n
.any	tst.w	C_AIR(a2)
	bne.s	.n
	move.l	C_X(a2),d0
	sub.l	W_X(a3),d0
	asr.l	#8,d0
	bpl.s	.a
	neg.w	d0
.a	move.l	C_Y(a2),d1
	sub.l	W_Y(a3),d1
	asr.l	#8,d1
	bpl.s	.b
	neg.w	d1
.b	add.w	d1,d0
	cmp.w	#11,d0
	bgt.s	.n
	bsr	hit_car
	moveq	#1,d0
	bra.s	.x
.n	lea	CARSZ(a2),a2
	dbf	d4,.l
	moveq	#0,d0
.x	movem.l	(sp)+,d1-d4/a2
	rts

; hit_car: car a2 is hit by a missile or a bomb
hit_car:
	tst.w	C_SHLD(a2)
	bne.s	.x
	tst.w	C_CAGE(a2)
	beq.s	.hit
	subq.w	#1,C_CAGE(a2)
	move.w	#6,C_STUN(a2)
	rts
.hit	move.w	#36,C_STUN(a2)
	add.w	#20,C_DMG(a2)
	cmp.w	#99,C_DMG(a2)
	bls.s	.d
	move.w	#99,C_DMG(a2)
.d	clr.w	C_SPD(a2)
	tst.w	C_PERS(a2)
	bpl.s	.x
	move.l	a0,-(sp)
	lea	str_hit,a0
	move.l	d0,-(sp)
	moveq	#40,d0
	bsr	hud_msg
	move.l	(sp)+,d0
	move.l	(sp)+,a0
.x	rts

;------------------------------------------------------------------------------
; pickups: 6 spots on the track, icons drawn into the track picture
;------------------------------------------------------------------------------
spots_init:
	movem.l	d0-d7/a0-a2,-(sp)
	move.l	trk_ptr,a0
	move.l	TE_SPOTS(a0),a1		; spots: x, y, bx, by, wp, wp the other way round
	lea	spots,a2
	moveq	#NSPOTS-1,d7
.l	move.w	(a1)+,SP_X(a2)
	move.w	(a1)+,SP_Y(a2)
	move.w	(a1)+,SP_BX(a2)
	move.w	(a1)+,SP_BY(a2)
	move.w	(a1)+,SP_WP(a2)
	move.w	(a1)+,d0
	tst.b	race_reverse
	beq.s	.sw
	move.w	d0,SP_WP(a2)
.sw
	clr.w	SP_TYPE(a2)
	clr.w	SP_T(a2)
	bsr	random_item
	bsr	spot_show
	lea	SPSZ(a2),a2
	dbf	d7,.l
	; the next STRONKIE letter in one of the spots
	tst.b	practice
	bne.s	.x
	moveq	#0,d6
	move.b	r_letters,d6
	cmp.w	#8,d6
	bhs.s	.x
	moveq	#NSPOTS,d0
	bsr	rand_n
	mulu	#SPSZ,d0
	lea	spots,a2
	add.l	d0,a2
	bsr	spot_hide
	add.w	#IC_L_S+1,d6
	move.w	d6,d0
	bsr	spot_show
.x	movem.l	(sp)+,d0-d7/a0-a2
	rts

; random_item -> d0 = icon + 1 (weighted)
random_item:
	movem.l	d1/a0,-(sp)
	moveq	#90,d0
	bsr	rand_n
	lea	item_weights,a0
	moveq	#1,d1
.l	sub.b	(a0)+,d0
	bmi.s	.x
	addq.w	#1,d1
	bra.s	.l
.x	move.w	d1,d0
	movem.l	(sp)+,d1/a0
	rts

; spot_show: a2 = spot, d0 = item (icon + 1): save the picture under it, draw the icon
spot_show:
	movem.l	d0-d7/a0-a1/a3,-(sp)
	move.w	d0,SP_TYPE(a2)
	bsr	spot_addr		; a1 = the track picture there
	lea	SP_BG(a2),a3
	move.l	a1,a0
	moveq	#15,d1
.save	moveq	#4,d2
	move.l	a0,-(sp)
.sp	move.b	(a0),(a3)+
	move.b	1(a0),(a3)+
	lea	TRK_PB(a0),a0
	dbf	d2,.sp
	move.l	(sp)+,a0
	lea	TRK_RB(a0),a0
	dbf	d1,.save
	move.w	SP_TYPE(a2),d0
	subq.w	#1,d0
	move.w	d0,d1
	mulu	#160,d0
	lea	icons_gfx,a3		; 16 rows x 5 planes x 2 bytes
	add.l	d0,a3
	lsl.w	#5,d1
	lea	icons_mask,a0
	add.w	d1,a0			; 16 rows x 2 bytes
	moveq	#15,d1
.row	move.b	(a0)+,d3		; mask
	move.b	(a0)+,d4
	move.b	d3,d5
	not.b	d5
	move.b	d4,d6
	not.b	d6
	move.l	a1,-(sp)
	moveq	#4,d2
.pl	move.b	(a1),d7
	and.b	d5,d7
	move.b	(a3)+,d0
	and.b	d3,d0
	or.b	d0,d7
	move.b	d7,(a1)
	move.b	1(a1),d7
	and.b	d6,d7
	move.b	(a3)+,d0
	and.b	d4,d0
	or.b	d0,d7
	move.b	d7,1(a1)
	lea	TRK_PB(a1),a1
	dbf	d2,.pl
	move.l	(sp)+,a1
	lea	TRK_RB(a1),a1
	dbf	d1,.row
	movem.l	(sp)+,d0-d7/a0-a1/a3
	rts

; spot_hide: put the picture back
spot_hide:
	movem.l	d1-d2/a0-a1/a3,-(sp)
	tst.w	SP_TYPE(a2)
	beq.s	.x
	clr.w	SP_TYPE(a2)
	bsr	spot_addr
	lea	SP_BG(a2),a3
	moveq	#15,d1
.r	moveq	#4,d2
	move.l	a1,a0
.p	move.b	(a3)+,(a0)
	move.b	(a3)+,1(a0)
	lea	TRK_PB(a0),a0
	dbf	d2,.p
	lea	TRK_RB(a1),a1
	dbf	d1,.r
.x	movem.l	(sp)+,d1-d2/a0-a1/a3
	rts

spot_addr:
	move.l	d0,-(sp)
	move.w	SP_BY(a2),d0
	mulu	#TRK_RB,d0
	add.w	SP_BX(a2),d0
	lea	trackbm,a1
	add.l	d0,a1
	move.l	(sp)+,d0
	rts

; spots_update: pick up, and new items after a while
spots_update:
	movem.l	d0-d7/a0-a4,-(sp)
	lea	spots,a4
	moveq	#NSPOTS-1,d7
.l	tst.w	SP_TYPE(a4)
	bne.s	.full
	addq.w	#1,SP_T(a4)
	cmp.w	#250,SP_T(a4)
	blo	.n
	clr.w	SP_T(a4)
	move.l	a4,a2
	bsr	random_item
	bsr	spot_show
	bra	.n
.full	lea	cars,a3
	moveq	#3,d6
.c	tst.w	C_AIR(a3)
	bne.s	.nc
	move.l	C_X(a3),d0
	asr.l	#8,d0
	sub.w	SP_X(a4),d0
	bpl.s	.a
	neg.w	d0
.a	move.l	C_Y(a3),d1
	asr.l	#8,d1
	sub.w	SP_Y(a4),d1
	bpl.s	.b
	neg.w	d1
.b	add.w	d1,d0
	cmp.w	#13,d0
	bgt.s	.nc
	move.w	SP_TYPE(a4),d0
	tst.w	C_PERS(a3)		; you take everything
	bmi.s	.take
	bsr	ai_can_take		; the computer cars: weapons and power-ups only
	beq.s	.nc
.take	move.l	a4,a2
	bsr	spot_hide
	clr.w	SP_T(a4)
	move.l	a3,a2
	subq.w	#1,d0
	bsr	apply_item
	bra.s	.n
.nc	lea	CARSZ(a3),a3
	dbf	d6,.c
.n	lea	SPSZ(a4),a4
	dbf	d7,.l
	movem.l	(sp)+,d0-d7/a0-a4
	rts

; ai_can_take: d0 = item (icon + 1) -> ne when a computer car may take it:
; weapons, roll cage, turbo, shield, repair (not the upgrades, cash or letters)
ai_can_take:
	move.l	d0,-(sp)
	cmp.w	#IC_MISSILES+1,d0
	blo.s	.no
	cmp.w	#IC_HOMING+1,d0
	bls.s	.yes
	cmp.w	#IC_CAGE+1,d0
	blo.s	.no
	cmp.w	#IC_REPAIR+1,d0
	bhi.s	.no
.yes	moveq	#1,d0
	movem.l	(sp)+,d0
	rts
.no	moveq	#0,d0
	movem.l	(sp)+,d0
	rts

; apply_item: car a2 picked up icon d0
apply_item:
	movem.l	d0-d2/a0,-(sp)
	move.w	d0,d2
	tst.w	C_PERS(a2)
	bmi.s	.you
	; a computer car (weapons and power-ups only, see ai_can_take)
	bra	.common
.you	cmp.w	#IC_L_S,d2
	blo.s	.notl
	addq.b	#1,r_letters
	addq.w	#1,race_letter
	moveq	#S_LETTER,d0
	bsr	sfx
	lea	str_letter,a0
	moveq	#50,d0
	bsr	hud_msg
	bra	.x
.notl	moveq	#S_PICKUP,d0
	bsr	sfx
	lea	item_msgs,a0
	move.w	d2,d0
	lsl.w	#2,d0
	move.l	(a0,d0.w),a0
	moveq	#40,d0
	bsr	hud_msg
	cmp.w	#IC_MOTOR,d2
	bne.s	.y1
	cmp.b	#5,r_motor
	bhs.s	.max
	addq.b	#1,r_motor
	add.w	#44,C_TOP(a2)
	bra	.x
.y1	cmp.w	#IC_TIRES,d2
	bne.s	.y2
	cmp.b	#5,r_tires
	bhs.s	.max
	addq.b	#1,r_tires
	add.w	#14,C_GRIP(a2)
	bra	.x
.y2	cmp.w	#IC_BATTERY,d2
	bne.s	.y3
	cmp.b	#5,r_battery
	bhs.s	.max
	addq.b	#1,r_battery
	addq.w	#3,C_ACC(a2)
	bra	.x
.max	add.l	#200,r_cash		; already the best: cash instead
	bra	.x
.y3	cmp.w	#IC_CASH,d2
	bne.s	.common
	moveq	#S_CASH,d0
	bsr	sfx
	add.l	#100,r_cash
	tst.b	practice
	beq	.x
	sub.l	#100,r_cash
	bra	.x
.common	cmp.w	#IC_MISSILES,d2
	bne.s	.c1
	moveq	#1,d0
	moveq	#2,d1
	bsr	give_weapon
	bra.s	.x
.c1	cmp.w	#IC_BOMBS,d2
	bne.s	.c2
	moveq	#2,d0
	moveq	#2,d1
	bsr	give_weapon
	bra.s	.x
.c2	cmp.w	#IC_HOMING,d2
	bne.s	.c3
	moveq	#3,d0
	moveq	#1,d1
	bsr	give_weapon
	bra.s	.x
.c3	cmp.w	#IC_CAGE,d2
	bne.s	.c4
	move.w	#2,C_CAGE(a2)
	bra.s	.x
.c4	cmp.w	#IC_TURBO,d2
	bne.s	.c5
	move.w	#250,C_TURBO(a2)
	bra.s	.x
.c5	cmp.w	#IC_SHIELD,d2
	bne.s	.c6
	move.w	#125,C_SHLD(a2)
	bra.s	.x
.c6	cmp.w	#IC_REPAIR,d2
	bne.s	.x
	clr.w	C_DMG(a2)
.x	movem.l	(sp)+,d0-d2/a0
	rts

; give_weapon: d0 = type, d1 = how many
give_weapon:
	cmp.w	C_WEAP(a2),d0
	beq.s	.same
	move.w	d0,C_WEAP(a2)
	clr.w	C_AMMO(a2)
.same	add.w	d1,C_AMMO(a2)
	move.w	C_CAP(a2),d1
	cmp.w	C_AMMO(a2),d1
	bhs.s	.x
	move.w	d1,C_AMMO(a2)
.x	rts

;------------------------------------------------------------------------------
; the motor sound
;------------------------------------------------------------------------------
engine_sound:
	movem.l	d0-d1,-(sp)
	tst.b	paused
	bne.s	.off
	move.w	cars+C_SPD,d0
	bpl.s	.p
	neg.w	d0
.p	cmp.w	#2,race_phase
	bne.s	.r
	lsr.w	#1,d0
.r	moveq	#0,d1			; a stronger motor sings higher
	move.b	r_motor,d1
	mulu	#22,d1
	neg.w	d1
	add.w	#640,d1
	lsr.w	#1,d0
	sub.w	d0,d1
	cmp.w	#150,d1
	bge.s	.ok
	move.w	#150,d1
.ok	move.w	d1,eng_per
	move.w	cars+C_SPD,d0
	bpl.s	.q
	neg.w	d0
.q	lsr.w	#5,d0
	add.w	#14,d0
	cmp.w	#42,d0
	bls.s	.v
	moveq	#42,d0
.v	move.w	d0,eng_vol
	movem.l	(sp)+,d0-d1
	rts
.off	clr.w	eng_vol
	movem.l	(sp)+,d0-d1
	rts

;------------------------------------------------------------------------------
; drawing: the camera, the scroll position and the sprites
;------------------------------------------------------------------------------
fx_cycle:	dc.w	$810,$a20,$c40,$e60,$f80,$fa0,$fc2,$ff6,$fff,$ff6,$fc2,$fa0,$f80,$e60,$c40,$a20

race_draw:
	movem.l	d0-d7/a0-a3,-(sp)
	; the animated colour 25: zipper arrows, flags, electric plates, camera flashes
	move.l	framecount,d0
	lsr.w	#2,d0
	and.w	#15,d0
	add.w	d0,d0
	lea	fx_cycle,a0
	move.w	(a0,d0.w),cr_col+2+25*4
	lea	cars,a2
	; the camera: on your car, looking ahead a little
	move.w	C_VX(a2),d0
	sub.w	C_VY(a2),d0
	asr.w	#5,d0
	add.w	C_SX(a2),d0
	sub.w	#160,d0
	move.w	C_VX(a2),d1
	add.w	C_VY(a2),d1
	asr.w	#6,d1
	add.w	C_SY(a2),d1
	sub.w	#106,d1
	sub.w	cam_x,d0
	asr.w	#2,d0
	add.w	d0,cam_x
	sub.w	cam_y,d1
	asr.w	#2,d1
	add.w	d1,cam_y
	bsr	clamp_cam
	move.w	cam_x,d0
	move.w	cam_y,d1
	bsr	set_scroll
	; the cars: attached sprite pairs (0+1, 2+3, 4+5, 6+7)
	moveq	#0,d7
.car	move.w	d7,d3
	tst.w	C_SHLD(a2)		; the shield: blinking
	beq.s	.vis
	move.l	race_step,d0
	btst	#1,d0
	beq.s	.vis
	add.w	d3,d3
	bsr	hide_sprite
	addq.w	#1,d3
	bsr	hide_sprite
	bra.s	.nc
.vis	move.w	C_ANG(a2),d0
	addq.w	#8,d0
	lsr.w	#4,d0
	and.w	#15,d0
	move.w	C_DES(a2),d1
	add.w	d1,d1
	tst.w	C_CAGE(a2)
	beq.s	.ncg
	addq.w	#1,d1
.ncg	lsl.w	#4,d1
	add.w	d1,d0
	mulu	#CARSPR,d0
	lea	cars_gfx,a0
	add.l	d0,a0
	move.w	C_SX(a2),d0
	sub.w	cam_x,d0
	sub.w	#CAR_AX,d0
	move.w	C_SY(a2),d1
	sub.w	cam_y,d1
	sub.w	#CAR_AY,d1
	sub.w	C_JH(a2),d1
	move.w	d7,d4			; colour slot = car number
	bsr	put_car
.nc	lea	CARSZ(a2),a2
	addq.w	#1,d7
	cmp.w	#4,d7
	blo	.car
	bsr	bobs_draw
	bsr	ovl_draw
	movem.l	(sp)+,d0-d7/a0-a3
	rts

;------------------------------------------------------------------------------
; missiles, bombs and explosions: drawn into the track picture (all 8 sprites
; are the cars), with the picture under them saved and put back every step
;------------------------------------------------------------------------------
BB_ON		equ	0
BB_ADDR		equ	2
BB_DATA		equ	6
BBSZ		equ	6+16*5*4

bobs_restore:
	movem.l	d0-d2/a0-a2,-(sp)
	lea	bobsave+BBSZ*3,a2	; the last one drawn first
	moveq	#3,d2
.l	tst.w	BB_ON(a2)
	beq.s	.n
	clr.w	BB_ON(a2)
	move.l	BB_ADDR(a2),a0
	lea	BB_DATA(a2),a1
	moveq	#15,d0
.r	move.l	(a1)+,(a0)
	move.l	(a1)+,TRK_PB(a0)
	move.l	(a1)+,TRK_PB*2(a0)
	move.l	(a1)+,TRK_PB*3(a0)
	move.l	(a1)+,TRK_PB*4(a0)
	lea	TRK_RB(a0),a0
	dbf	d0,.r
.n	lea	-BBSZ(a2),a2
	dbf	d2,.l
	movem.l	(sp)+,d0-d2/a0-a2
	rts

bobs_draw:
	movem.l	d0-d7/a0-a4,-(sp)
	lea	weaps,a3
	lea	bobsave,a4
	moveq	#0,d7
.w	move.w	W_ACT(a3),d0
	beq	.nw
	cmp.w	#2,d0
	beq.s	.wb
	cmp.w	#4,d0
	beq.s	.we
	move.w	W_ANG(a3),d0		; a missile: 8 directions
	add.w	#16,d0
	lsr.w	#5,d0
	and.w	#7,d0
	bra.s	.wf
.wb	moveq	#8,d0			; a bomb: blinking fuse
	move.w	W_T(a3),d1
	btst	#2,d1
	beq.s	.wf
	moveq	#9,d0
	bra.s	.wf
.we	move.w	W_FR(a3),d0		; an explosion
	lsr.w	#1,d0
	add.w	#10,d0
.wf	mulu	#192,d0
	lea	wbob_gfx,a0
	add.l	d0,a0
	move.l	W_X(a3),d0		; top left in the track picture
	sub.l	W_Y(a3),d0
	asr.l	#8,d0
	add.w	#320-8,d0
	move.l	W_X(a3),d1
	add.l	W_Y(a3),d1
	asr.l	#8,d1
	asr.w	#1,d1
	sub.w	#12,d1
	tst.w	d0
	bmi	.nw
	cmp.w	#WW-32,d0
	bgt	.nw
	tst.w	d1
	bmi	.nw
	cmp.w	#WH-16,d1
	bgt	.nw
	move.w	d0,d5
	and.w	#15,d5			; shift
	lsr.w	#4,d0
	add.w	d0,d0
	mulu	#TRK_RB,d1
	add.w	d0,d1
	lea	trackbm,a1
	add.l	d1,a1
	move.l	a1,BB_ADDR(a4)
	move.w	#1,BB_ON(a4)
	lea	BB_DATA(a4),a2
	moveq	#15,d6
.row	moveq	#0,d2
	move.w	(a0)+,d2		; mask
	swap	d2
	lsr.l	d5,d2
	move.l	d2,d3
	not.l	d3
	move.l	a1,-(sp)
	moveq	#4,d4
.pl	move.l	(a1),d0
	move.l	d0,(a2)+		; save
	and.l	d3,d0
	moveq	#0,d1
	move.w	(a0)+,d1
	swap	d1
	lsr.l	d5,d1
	and.l	d2,d1
	or.l	d1,d0
	move.l	d0,(a1)
	lea	TRK_PB(a1),a1
	dbf	d4,.pl
	move.l	(sp)+,a1
	lea	TRK_RB(a1),a1
	dbf	d6,.row
.nw	lea	WSZ(a3),a3
	lea	BBSZ(a4),a4
	addq.w	#1,d7
	cmp.w	#4,d7
	blo	.w
	movem.l	(sp)+,d0-d7/a0-a4
	rts


;------------------------------------------------------------------------------
; overlays: the start lights and the big texts, a blitter bob over the track
; (one at a time, centred on the screen, put back at the start of each step)
;------------------------------------------------------------------------------
OVL_MAXW	equ	12			; words
OVL_MAXH	equ	40

; show_ovl: d0 = OVL_*, d1 = steps to show (0 = until the next one)
show_ovl:
	move.w	d0,ovl_cur
	move.w	d1,ovl_t
	rts

hide_ovl:
	move.w	#-1,ovl_cur
	rts

ovl_restore:
	tst.b	ovl_drawn
	beq.s	.x
	movem.l	a5,-(sp)
	clr.b	ovl_drawn
	bsr	wait_blit
	lea	CUSTOM,a5
	move.l	#$09f00000,$40(a5)
	move.l	#-1,$44(a5)
	move.l	#ovl_save,$50(a5)
	move.l	ovl_dst,$54(a5)
	clr.w	$64(a5)
	move.w	ovl_dmod,$66(a5)
	move.w	ovl_size,$58(a5)
	bsr	wait_blit
	movem.l	(sp)+,a5
.x	rts

ovl_draw:
	movem.l	d0-d2/a5,-(sp)
	move.w	ovl_cur,d0
	bmi	.x
	cmp.w	ovl_built,d0
	beq.s	.b
	bsr	ovl_build
.b	move.w	ovl_w,d0		; x: centred
	lsl.w	#3,d0
	neg.w	d0
	add.w	cam_x,d0
	add.w	#160,d0
	move.w	ovl_y,d1
	add.w	cam_y,d1
	mulu	#TRK_RB,d1
	move.w	d0,d2
	lsr.w	#4,d2
	add.w	d2,d2
	add.l	d2,d1
	add.l	#trackbm,d1
	move.l	d1,ovl_dst
	and.w	#15,d0
	ror.w	#4,d0			; the shift, in bits 12-15
	move.w	ovl_w,d1
	addq.w	#1,d1
	move.w	#TRK_PB,d2
	sub.w	d1,d2
	sub.w	d1,d2
	move.w	d2,ovl_dmod
	move.w	ovl_h,d2
	mulu	#5*64,d2
	or.w	d1,d2
	move.w	d2,ovl_size
	bsr	wait_blit
	lea	CUSTOM,a5
	; save what is under it
	move.l	#$09f00000,$40(a5)
	move.l	#-1,$44(a5)
	move.l	ovl_dst,$50(a5)
	move.l	#ovl_save,$54(a5)
	move.w	ovl_dmod,$64(a5)
	clr.w	$66(a5)
	move.w	ovl_size,$58(a5)
	bsr	wait_blit
	; cookie cut: D = A.B + /A.C
	move.w	d0,d1
	or.w	#$0fca,d1
	move.w	d1,$40(a5)
	move.w	d0,$42(a5)
	move.l	#$ffff0000,$44(a5)
	move.l	ovl_dst,$48(a5)
	move.l	#ovl_img,$4c(a5)
	move.l	#ovl_msk,$50(a5)
	move.l	ovl_dst,$54(a5)
	move.w	ovl_dmod,$60(a5)
	move.w	#-2,$62(a5)
	move.w	#-2,$64(a5)
	move.w	ovl_dmod,$66(a5)
	move.w	ovl_size,$58(a5)
	st	ovl_drawn
	; the time it stays
	tst.w	ovl_t
	beq.s	.x
	subq.w	#1,ovl_t
	bne.s	.x
	move.w	#-1,ovl_cur
.x	movem.l	(sp)+,d0-d2/a5
	rts

; ovl_build: d0 = OVL_* -> ovl_img / ovl_msk (interleaved rows, 5 planes)
; the image has 2 bits a pixel: a (bit 0) and b (bit 1); 1, 2, 3 = its 3 colours
ovl_build:
	movem.l	d0-d7/a0-a5,-(sp)
	bsr	wait_blit
	move.w	d0,ovl_built
	add.w	d0,d0
	add.w	d0,d0
	lea	ovl_table,a0
	move.l	(a0,d0.w),d0
	lea	ovl_buf,a0
	add.l	d0,a0
	move.w	(a0)+,d5		; width in words
	move.w	d5,ovl_w
	add.w	d5,d5			; ... in bytes
	move.w	(a0)+,d7		; height
	move.w	d7,ovl_h
	move.w	(a0)+,ovl_y
	move.w	(a0)+,d2		; the 3 colours
	move.w	(a0)+,d3
	move.w	(a0)+,d4
	lea	ovl_img,a1
	lea	ovl_msk,a2
	subq.w	#1,d7
.row	moveq	#0,d1			; plane
.pl	moveq	#0,d0			; which of the colours have this plane: 0..7
	btst	d1,d2
	beq.s	.s1
	addq.w	#1,d0
.s1	btst	d1,d3
	beq.s	.s2
	addq.w	#2,d0
.s2	btst	d1,d4
	beq.s	.s3
	addq.w	#4,d0
.s3	add.w	d0,d0
	add.w	d0,d0
	lea	.ops(pc),a5
	move.l	(a5,d0.w),a5
	move.l	a0,a3
	move.w	d5,d6
	lsr.w	#1,d6
	subq.w	#1,d6
	move.w	d7,-(sp)
	move.w	d1,-(sp)
.wd	move.w	(a3)+,d0		; a
	move.w	-2(a3,d5.w),d1		; b
	move.w	d0,d7
	or.w	d1,d7
	move.w	d7,(a2)+		; the mask
	jsr	(a5)
	move.w	d7,(a1)+
	dbf	d6,.wd
	move.w	(sp)+,d1
	move.w	(sp)+,d7
	addq.w	#1,d1
	cmp.w	#5,d1
	blo.s	.pl
	add.w	d5,a0
	add.w	d5,a0
	dbf	d7,.row
	movem.l	(sp)+,d0-d7/a0-a5
	rts
.ops	dc.l	.o0,.o1,.o2,.o3,.o4,.o5,.o6,.o7
.o0	moveq	#0,d7
	rts
.o1	move.w	d1,d7			; a and not b
	not.w	d7
	and.w	d0,d7
	rts
.o2	move.w	d0,d7			; b and not a
	not.w	d7
	and.w	d1,d7
	rts
.o3	move.w	d0,d7
	eor.w	d1,d7
	rts
.o4	move.w	d0,d7
	and.w	d1,d7
	rts
.o5	move.w	d0,d7
	rts
.o6	move.w	d1,d7
	rts
.o7	move.w	d0,d7
	or.w	d1,d7
	rts

clamp_cam:
	cmp.w	#16,cam_x
	bge.s	.x1
	move.w	#16,cam_x
.x1	cmp.w	#WW-320,cam_x
	ble.s	.x2
	move.w	#WW-320,cam_x
.x2	tst.w	cam_y
	bpl.s	.y1
	clr.w	cam_y
.y1	cmp.w	#WH-VIEW_H,cam_y
	ble.s	.y2
	move.w	#WH-VIEW_H,cam_y
.y2	rts

;------------------------------------------------------------------------------
; the HUD
;------------------------------------------------------------------------------
hud_init:
	movem.l	d0-d7/a0-a2,-(sp)
	lea	hud_lz,a0
	lea	hudbm,a1
	move.l	#HUD_SIZE,d0
	bsr	unlz
	; the minimap: the track line in colour H_MAP (11 = planes 0, 1, 3)
	move.l	trk_ptr,a0
	move.l	TE_MM(a0),a0
	lea	hudbm+MM_Y*HUD_RB+3,a1
	moveq	#35,d1
.r	moveq	#9,d2
	move.l	a1,a2
.b	move.b	(a0)+,d0
	or.b	d0,(a2)
	or.b	d0,HUD_PB(a2)
	not.b	d0
	and.b	d0,HUD_PB*2(a2)
	not.b	d0
	or.b	d0,HUD_PB*3(a2)
	not.b	d0
	and.b	d0,HUD_PB*4(a2)
	addq.l	#1,a2
	dbf	d2,.b
	lea	HUD_RB(a1),a1
	dbf	d1,.r
	clr.w	mm_saved
	; force a full redraw
	move.w	#-1,h_mph
	move.w	#-1,h_lap
	move.w	#-1,h_pos
	move.w	#-1,h_wpn
	move.l	#-1,h_cash
	move.w	#-1,h_let
	move.w	#-1,h_stat
	st	h_msgdirty
	movem.l	(sp)+,d0-d7/a0-a2
	rts

hud_update:
	movem.l	d0-d7/a0-a3,-(sp)
	bsr	tgt_hud
	lea	cars,a2
	; MPH
	move.w	C_SPD(a2),d0
	bpl.s	.m
	neg.w	d0
.m	mulu	#13,d0
	lsr.l	#8,d0
	cmp.w	h_mph,d0
	beq.s	.nm
	move.w	d0,h_mph
	bsr	str_start
	ext.l	d0
	bsr	str_dec
	lea	str_sp2,a0
	bsr	str_add
	bsr	str_end
	moveq	#16,d0
	moveq	#6,d1
	moveq	#H_WHITE,d2
	moveq	#H_PANL,d3
	bsr	draw_text
.nm	; LAP
	move.w	C_LAP(a2),d0
	addq.w	#1,d0
	cmp.w	#LAPS,d0
	bls.s	.l4
	moveq	#LAPS,d0
.l4	cmp.w	h_lap,d0
	beq.s	.nl
	move.w	d0,h_lap
	bsr	str_start
	add.b	#'0',d0
	bsr	str_char
	moveq	#'/',d0
	bsr	str_char
	moveq	#'0'+LAPS,d0
	bsr	str_char
	bsr	str_end
	moveq	#16,d0
	moveq	#17,d1
	moveq	#H_WHITE,d2
	moveq	#H_PANL,d3
	bsr	draw_text
.nl	; place
	move.w	C_RANK(a2),d0
	tst.w	C_FIN(a2)
	beq.s	.r
	move.w	C_FIN(a2),d0
.r	cmp.w	h_pos,d0
	beq.s	.np
	move.w	d0,h_pos
	subq.w	#1,d0
	lsl.w	#2,d0
	lea	str_places,a0
	add.w	d0,a0
	moveq	#16,d0
	moveq	#28,d1
	moveq	#H_ORANGE,d2
	cmp.w	#4,h_pos
	bne.s	.pc
	moveq	#H_DIM,d2
.pc	cmp.w	#1,h_pos
	bne.s	.pc2
	moveq	#H_GREEN,d2
.pc2	moveq	#H_PANL,d3
	bsr	draw_text
.np	; the letters you have
	moveq	#0,d0
	move.b	r_letters,d0
	tst.b	practice
	beq.s	.lt
	moveq	#-2,d0
.lt	cmp.w	h_let,d0
	beq.s	.nlt
	move.w	d0,h_let
	lea	str_stronkie,a3
	moveq	#0,d4
.lc	move.b	(a3,d4.w),d0
	lea	strbuf,a0
	move.b	d0,(a0)
	clr.b	1(a0)
	moveq	#H_LDIM,d2
	cmp.w	h_let,d4
	bge.s	.ld
	moveq	#28,d2			; yellow
.ld	move.w	d4,d0
	add.w	#27,d0
	moveq	#6,d1
	moveq	#H_PANL,d3
	bsr	draw_text
	addq.w	#1,d4
	cmp.w	#8,d4
	blo.s	.lc
.nlt	; the weapon
	move.w	C_WEAP(a2),d0
	lsl.w	#4,d0
	or.w	C_AMMO(a2),d0
	cmp.w	h_wpn,d0
	beq.s	.nw
	move.w	d0,h_wpn
	bsr	str_start
	move.w	C_WEAP(a2),d0
	lsl.w	#2,d0
	lea	weap_names,a0
	move.l	(a0,d0.w),a0
	bsr	str_add
	tst.w	C_WEAP(a2)
	beq.s	.wn
	moveq	#'x',d0
	bsr	str_char
	moveq	#0,d0
	move.w	C_AMMO(a2),d0
	bsr	str_dec
.wn	lea	str_sp8,a0
	bsr	str_add
	bsr	str_end
	clr.b	14(a0)
	moveq	#26,d0
	moveq	#17,d1
	moveq	#H_CYAN,d2
	tst.w	C_WEAP(a2)
	bne.s	.wc
	moveq	#H_DIM,d2
.wc	moveq	#H_PANL,d3
	bsr	draw_text
.nw	; status letters: cage, shield, turbo, damage
	moveq	#0,d0
	tst.w	C_CAGE(a2)
	beq.s	.s1
	bset	#0,d0
.s1	tst.w	C_SHLD(a2)
	beq.s	.s2
	bset	#1,d0
.s2	tst.w	C_TURBO(a2)
	beq.s	.s3
	bset	#2,d0
.s3	move.w	C_DMG(a2),d1
	lsr.w	#4,d1
	lsl.w	#4,d1
	or.w	d1,d0
	cmp.w	h_stat,d0
	beq.s	.ns
	move.w	d0,h_stat
	bsr	draw_status
.ns	; the message line, or the cash
	tst.w	msg_t
	beq.s	.cash
	tst.b	h_msgdirty
	beq.s	.mt
	clr.b	h_msgdirty
	move.l	msg_ptr,a0
	bsr	str_start
	bsr	str_add
	lea	str_sp16,a0
	bsr	str_add
	bsr	str_end
	clr.b	14(a0)
	moveq	#26,d0
	moveq	#28,d1
	moveq	#28,d2			; yellow
	moveq	#H_PANL,d3
	bsr	draw_text
.mt	cmp.w	#30000,msg_t
	beq	.mm
	subq.w	#1,msg_t
	bne	.mm
	move.l	#-1,h_cash
.cash	move.l	r_cash,d0
	tst.b	practice
	beq.s	.c0
	move.l	race_step,d0		; practice: the lap time instead
	moveq	#0,d0
	move.w	C_LAPT(a2),d0
	bsr	str_start
	bsr	str_time
	lea	str_sp8,a0
	bsr	str_add
	bsr	str_end
	clr.b	14(a0)
	bra.s	.c1
.c0	cmp.l	h_cash,d0
	beq.s	.mm
	move.l	d0,h_cash
	bsr	str_start
	moveq	#'$',d0
	bsr	str_char
	move.l	r_cash,d0
	bsr	str_dec
	lea	str_sp16,a0
	bsr	str_add
	bsr	str_end
	clr.b	14(a0)
.c1	moveq	#26,d0
	moveq	#28,d1
	moveq	#H_WHITE,d2
	moveq	#H_PANL,d3
	bsr	draw_text
.mm	; car dots on the minimap
	bsr	minimap_dots
	movem.l	(sp)+,d0-d7/a0-a3
	rts

; draw_status: C S T and a damage bar (d0 = flags) in the middle panel
draw_status:
	movem.l	d0-d4/a0,-(sp)
	move.w	d0,d4
	lea	strbuf,a0
	move.b	#'C',(a0)
	clr.b	1(a0)
	moveq	#21,d0
	moveq	#6,d1
	moveq	#H_LDIM,d2
	btst	#0,d4
	beq.s	.a
	moveq	#H_GREEN,d2
.a	moveq	#H_PANL,d3
	bsr	draw_text
	move.b	#'S',(a0)
	moveq	#22,d0
	moveq	#H_LDIM,d2
	btst	#1,d4
	beq.s	.b
	moveq	#H_CYAN,d2
.b	bsr	draw_text
	move.b	#'T',(a0)
	moveq	#23,d0
	moveq	#H_LDIM,d2
	btst	#2,d4
	beq.s	.c
	moveq	#H_ORANGE,d2
.c	bsr	draw_text
	; damage: 0..6 blocks
	lsr.w	#4,d4
	lsr.w	#1,d4
	move.l	a0,a1
	moveq	#0,d0
.d	moveq	#'[',d1
	cmp.w	d4,d0
	blt.s	.e
	moveq	#'@',d1
.e	move.b	d1,(a1)+
	addq.w	#1,d0
	cmp.w	#3,d0
	blo.s	.d
	clr.b	(a1)
	moveq	#21,d0
	moveq	#17,d1
	moveq	#H_DGREEN,d2
	cmp.w	#1,d4
	blo.s	.f
	moveq	#H_ORANGE,d2
	cmp.w	#2,d4
	blo.s	.f
	moveq	#H_DRED,d2
.f	moveq	#H_PANL,d3
	bsr	draw_text
	lea	str_dmg,a0
	moveq	#21,d0
	moveq	#28,d1
	moveq	#H_DIM,d2
	bsr	draw_text
	movem.l	(sp)+,d0-d4/a0
	rts

; minimap_dots: put back what was under the old dots, draw the new ones
minimap_dots:
	movem.l	d0-d7/a0-a3,-(sp)
	lea	mm_save,a3
	move.w	mm_saved,d7
	beq.s	.draw
	subq.w	#1,d7
	move.w	d7,d0			; the last one first
	mulu	#14,d0
	add.w	d0,a3
.rest	move.l	(a3),a1			; address, then 2 rows x 5 planes
	lea	4(a3),a0
	moveq	#1,d1
.rr	move.l	a1,a2
	moveq	#4,d2
.rp	move.b	(a0)+,(a2)
	lea	HUD_PB(a2),a2
	dbf	d2,.rp
	lea	HUD_RB(a1),a1
	dbf	d1,.rr
	lea	-14(a3),a3
	dbf	d7,.rest
.draw	clr.w	mm_saved
	lea	mm_save,a3
	move.l	trk_ptr,a0
	move.w	TE_MMK(a0),d5		; scale (8.8)
	move.w	TE_MMX(a0),d6		; x offset
	move.w	TE_MMY(a0),d4		; y offset
	lea	cars+CARSZ*3,a2
	moveq	#3,d7			; you last (on top)
.car	move.w	C_SX(a2),d0
	mulu	d5,d0
	lsr.l	#8,d0
	add.w	d6,d0
	add.w	#24,d0			; HUD buffer x
	and.w	#$fffe,d0
	move.w	C_SY(a2),d1
	mulu	d5,d1
	lsr.l	#8,d1
	add.w	d4,d1
	cmp.w	#34,d1
	bls.s	.yy
	moveq	#34,d1
.yy	add.w	#MM_Y,d1
	mulu	#HUD_RB,d1
	move.w	d0,d2
	lsr.w	#3,d2
	add.w	d2,d1
	lea	hudbm,a1
	add.l	d1,a1
	move.l	a1,(a3)+
	moveq	#1,d1
.sr	move.l	a1,a0
	moveq	#4,d2
.sp	move.b	(a0),(a3)+
	lea	HUD_PB(a0),a0
	dbf	d2,.sp
	lea	HUD_RB(a1),a1
	dbf	d1,.sr
	addq.w	#1,mm_saved
	; draw: colour 18 + 4 * car (the car's body colour)
	lea	-HUD_RB*2(a1),a1
	and.w	#7,d0
	moveq	#-64,d3			; %11000000
	lsr.b	d0,d3
	move.w	d7,d2
	lsl.w	#2,d2
	add.w	#19,d2
	moveq	#1,d1
.dr	move.l	a1,a0
	moveq	#0,d0
.dp	or.b	d3,(a0)
	btst	d0,d2
	bne.s	.nx
	eor.b	d3,(a0)
.nx
	lea	HUD_PB(a0),a0
	addq.w	#1,d0
	cmp.w	#5,d0
	blo.s	.dp
	lea	HUD_RB(a1),a1
	dbf	d1,.dr
	lea	-CARSZ(a2),a2
	dbf	d7,.car
	movem.l	(sp)+,d0-d7/a0-a3
	rts

; hud_msg: a0 = text, d0 = steps (30000 = until cleared)
hud_msg:
	move.l	a0,msg_ptr
	move.w	d0,msg_t
	st	h_msgdirty
	rts

hud_msg_clear:
	move.w	#1,msg_t
	rts

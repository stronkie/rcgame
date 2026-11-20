;------------------------------------------------------------------------------
;  strings.s - texts and small tables
;------------------------------------------------------------------------------
str_paused	dc.b	'PAUSED  ESC=QUIT',0
str_3		dc.b	'   - 3 -',0
str_2		dc.b	'   - 2 -',0
str_1		dc.b	'   - 1 -',0
str_go		dc.b	'    GO!',0
str_finish	dc.b	'  FINISH!',0
str_lap		dc.b	'NEXT LAP!',0
str_lastlap	dc.b	'FINAL LAP!',0
str_hit		dc.b	'OUCH! HIT!',0
str_letter	dc.b	'LETTER FOUND!',0
str_sp2		dc.b	'  ',0
str_sp8		dc.b	'        ',0
str_sp16	dc.b	'                ',0
str_places	dc.b	'1ST',0,'2ND',0,'3RD',0,'4TH',0
str_stronkie	dc.b	'STRONKIE',0
str_dmg		dc.b	'DMG',0
w_none		dc.b	'NO WEAPON',0
w_mis		dc.b	'MISSILE ',0
w_bomb		dc.b	'BOMB ',0
w_hom		dc.b	'HOMING ',0
im_motor	dc.b	'MOTOR UP!',0
im_tires	dc.b	'TIRES UP!',0
im_batt		dc.b	'BATTERY UP!',0
im_mis		dc.b	'MISSILES!',0
im_bomb		dc.b	'BOMBS!',0
im_hom		dc.b	'HOMING!',0
im_cash		dc.b	'$100 CASH!',0
im_cage		dc.b	'ROLL CAGE!',0
im_turbo	dc.b	'TURBO!',0
im_shield	dc.b	'SHIELD!',0
im_repair	dc.b	'REPAIRED!',0
	even
weap_names	dc.l	w_none,w_mis,w_bomb,w_hom
item_msgs	dc.l	im_motor,im_tires,im_batt,im_mis,im_bomb,im_hom,im_cash,im_cage,im_turbo,im_shield,im_repair
; how often each pickup turns up (sum 90): motor, tires, battery, missiles, bombs, homing,
; cash, cage, turbo, shield, repair
item_weights	dc.b	8,8,8,14,10,3,14,6,8,5,6,127
	even
; the computer drivers per cup: top speed, acceleration, grip, turning, car design
ai_top		dc.w	700,800,890
ai_acc		dc.w	13,16,20
ai_grip		dc.w	70,90,110
ai_turn		dc.w	7,8,9
ai_des		dc.w	0,2,3
; per driver (Sam, Carla, Max, Erik): top speed * x / 256, caution in bends
pers_top	dc.w	276,251,261,246
pers_caution	dc.w	2,4,3,3

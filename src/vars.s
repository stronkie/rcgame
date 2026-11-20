;------------------------------------------------------------------------------
;  vars.s - variables (bss)
;------------------------------------------------------------------------------
; the career, saved to disk as RCTurbo.dat (REC_SIZE bytes)
records
r_magic		ds.l	1
r_cash		ds.l	1
r_active	ds.b	1	; a career is going on
r_cup		ds.b	1	; 0 amateur, 1 national, 2 world
r_race		ds.b	1	; 0..7
r_spares	ds.b	1	; spare cars
r_motor		ds.b	1
r_tires		ds.b	1
r_battery	ds.b	1
r_armor		ds.b	1
r_cap		ds.b	1	; weapon rack: 2 + this
r_class		ds.b	1	; 0..4: the car
r_paint		ds.b	1
r_letters	ds.b	1	; STRONKIE letters collected
r_weap		ds.b	1	; the weapon you carry
r_ammo		ds.b	1
r_erik		ds.b	1	; Engineer Erik's upgrades
r_ctrl		ds.b	1	; 0: up = gas, 1: fire = gas
r_points	ds.w	5	; you, Sam, Carla, Max, Erik
r_best		ds.w	8	; best laps per track (steps)
r_races		ds.w	1
r_wins		ds.w	1
r_titles	ds.w	1
r_trophy	ds.b	3	; per cup: 0 none, 1 gold, 2 silver, 3 bronze
		ds.b	REC_SIZE-59
rec_load	ds.b	REC_SIZE

; the race
cars		ds.b	CARSZ*4
weaps		ds.b	WSZ*4
spots		ds.b	SPSZ*NSPOTS
trk_ptr		ds.l	1
wp_ptr		ds.l	1
race_step	ds.l	1
msg_ptr		ds.l	1
h_cash		ds.l	1
nwp		ds.w	1
race_phase	ds.w	1
fin_count	ds.w	1
ending_t	ds.w	1
msg_t		ds.w	1
cam_x		ds.w	1
cam_y		ds.w	1
sub_frame	ds.w	1
step_act	ds.w	1
wind_x		ds.w	1
wind_y		ds.w	1
cur_track	ds.w	1
loaded_track	ds.w	1
cur_race_song	ds.w	1
race_pers	ds.w	3
race_letter	ds.w	1
h_mph		ds.w	1
h_lap		ds.w	1
h_pos		ds.w	1
h_wpn		ds.w	1
h_let		ds.w	1
h_stat		ds.w	1
mm_saved	ds.w	1
menu_sel	ds.w	1
menu_n		ds.w	1
res_place	ds.w	1
res_prize	ds.w	1
blink		ds.w	1
race_cols	ds.w	16
race_shared	ds.w	16
race_weather	ds.b	1	; 0 dry, 1 rain, 2 wind
practice	ds.b	1
paused		ds.b	1
race_quit	ds.b	1
h_msgdirty	ds.b	1
letters_done	ds.b	1
	even
mm_save		ds.b	4*14
bobsave		ds.b	(6+16*5*4)*4
surfmap		ds.b	SURF_SIZE
trkfile		ds.b	MAXTRK+16

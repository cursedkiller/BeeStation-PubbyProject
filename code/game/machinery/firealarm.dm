#define FIREALARM_COOLDOWN 67 // Chosen fairly arbitrarily, it is the length of the audio in FireAlarm.ogg. The actual track length is 7 seconds 8ms but but the audio stops at 6s 700ms

/obj/item/electronics/firealarm
	name = "fire alarm electronics"
	custom_price = 5
	desc = "A fire alarm circuit. Can handle heat levels up to 40 degrees celsius."

/obj/item/wallframe/firealarm
	name = "fire alarm frame"
	desc = "Used for building fire alarms."
	icon = 'icons/obj/monitors.dmi'
	icon_state = "fire_bitem"
	result_path = /obj/machinery/firealarm
	pixel_shift = 26

/obj/machinery/firealarm
	name = "fire alarm"
	desc = "<i>\"Pull this in case of emergency\"</i>. Thus, keep pulling it forever."
	icon = 'icons/obj/monitors.dmi'
	icon_state = "fire0"
	max_integrity = 250
	integrity_failure = 0.4
	armor_type = /datum/armor/machinery_firealarm
	use_power = IDLE_POWER_USE
	idle_power_usage = 2
	active_power_usage = 6
	power_channel = AREA_USAGE_ENVIRON
	resistance_flags = FIRE_PROOF
	layer = ABOVE_WINDOW_LAYER
	zmm_flags = ZMM_MANGLE_PLANES
	req_access = null

	light_power = 0
	light_range = 7
	light_color = "#ff3232"

	var/detecting = 1
	var/buildstage = 2 // 2 = complete, 1 = no wires, 0 = circuit gone
	var/last_alarm = 0
	var/area/myarea = null
	var/locked = FALSE //Are we locked?

CREATION_TEST_IGNORE_SUBTYPES(/obj/machinery/firealarm)


/datum/armor/machinery_firealarm
	rad = 100
	fire = 90
	acid = 30

/obj/machinery/firealarm/Initialize(mapload, dir, building)
	. = ..()
	if (!req_access)
		req_access = list(ACCESS_ATMOSPHERICS)
	if(building)
		buildstage = 0
		panel_open = TRUE
	update_appearance()
	myarea = get_area(src)
	LAZYADD(myarea.firealarms, src)
	RegisterSignal(SSsecurity_level, COMSIG_SECURITY_LEVEL_CHANGED, PROC_REF(check_security_level))

/obj/machinery/firealarm/Destroy()
	myarea.firereset(src)
	LAZYREMOVE(myarea.firealarms, src)
	return ..()

/obj/machinery/firealarm/update_overlays()
	. = ..()
	var/area/A = src.loc
	A = A.loc
	if(machine_stat & NOPOWER)
		return

	. += "fire_overlay"
	if(is_station_level(z))
		. += "fire_[SSsecurity_level.get_current_level_as_number()]"
		. += mutable_appearance(icon, "fire_[SSsecurity_level.get_current_level_as_number()]")
		. += emissive_appearance(icon, "fire_[SSsecurity_level.get_current_level_as_number()]", layer, alpha = 255)
		ADD_LUM_SOURCE(src, LUM_SOURCE_MANAGED_OVERLAY)
	else
		. += "fire_[SEC_LEVEL_GREEN]"
		. += mutable_appearance(icon, "fire_[SEC_LEVEL_GREEN]")
		. += emissive_appearance(icon, "fire_[SEC_LEVEL_GREEN]", layer, alpha = 255)
		ADD_LUM_SOURCE(src, LUM_SOURCE_MANAGED_OVERLAY)

	if(obj_flags & EMAGGED)
		. += "fire_emagged"
		. += mutable_appearance(icon, "fire_emagged")
		. += emissive_appearance(icon, "fire_emagged", layer, alpha = 255)
		ADD_LUM_SOURCE(src, LUM_SOURCE_MANAGED_OVERLAY)
		return //If it's emagged, don't do anything else for overlays.
	if(locked)
		. += "fire_locked"
		. += mutable_appearance(icon, "fire_locked", layer + 1) //If we are locked, overlay that over the fire_off
		. += emissive_appearance(icon, "fire_locked", layer, alpha = 255)
		ADD_LUM_SOURCE(src, LUM_SOURCE_MANAGED_OVERLAY)
	if(detecting && A.fire)
		. += "fire_on"
		. += mutable_appearance(icon, "fire_on", layer + 2) //If we are locked and there is a fire, overlay the fire detection overlay ontop of the locked one.
		. += emissive_appearance(icon, "fire_on", layer, alpha = 255)
		ADD_LUM_SOURCE(src, LUM_SOURCE_MANAGED_OVERLAY)
	else
		. += "fire_off"
		. += mutable_appearance(icon, "fire_off")
		. += emissive_appearance(icon, "fire_off", layer, alpha = 255)
		ADD_LUM_SOURCE(src, LUM_SOURCE_MANAGED_OVERLAY)

/obj/machinery/firealarm/emp_act(severity)
	. = ..()

	if (. & EMP_PROTECT_SELF)
		return

	if(prob(50 / severity))
		alarm()

/obj/machinery/firealarm/on_emag(mob/user)
	..()
	update_appearance()
	user?.visible_message(span_warning("Sparks fly out of [src]!"),
							span_notice("You emag [src], disabling its thermal sensors."))
	playsound(src, "sparks", 50, 1)

/obj/machinery/firealarm/eminence_act(mob/living/simple_animal/eminence/eminence)
	. = ..()
	to_chat(usr, span_brass("You begin manipulating [src]!"))
	if(do_after(eminence, 20, target=get_turf(eminence)))
		attack_hand(eminence)

/obj/machinery/firealarm/temperature_expose(datum/gas_mixture/air, temperature, volume)
	if((temperature > T0C + 200 || temperature < BODYTEMP_COLD_DAMAGE_LIMIT) && (last_alarm+FIREALARM_COOLDOWN < world.time) && !(obj_flags & EMAGGED) && detecting && !machine_stat)
		alarm()
		try_lock(null, TRUE)
	..()

/**
 * Signal handler for checking if we should update fire alarm appearance accordingly to a newly set security level
 *
 * Arguments:
 * * source The datum source of the signal
 * * new_level The new security level that is in effect
 */
/obj/machinery/firealarm/proc/check_security_level(datum/source, new_level)
	SIGNAL_HANDLER

	if(is_station_level(z))
		update_appearance()

/obj/machinery/firealarm/proc/alarm(mob/user)
	if(!is_operational || (last_alarm+FIREALARM_COOLDOWN > world.time))
		return
	last_alarm = world.time
	var/area/A = get_area(src)
	A.firealert(src)
	playsound(loc, 'goon/sound/machinery/FireAlarm.ogg', 75)
	update_appearance()
	if(user)
		log_game("[user] triggered a fire alarm at [COORD(src)]")

/obj/machinery/firealarm/proc/reset(mob/user)
	if(!is_operational)
		return
	var/area/A = get_area(src)
	A.firereset(src)
	update_appearance()
	if(user)
		log_game("[user] reset a fire alarm at [COORD(src)]")

/obj/machinery/firealarm/proc/try_lock(mob/user, force_lock = FALSE)
	if(allowed(user) || !user || force_lock)
		if(!locked || force_lock)
			locked = TRUE
			balloon_alert(user, "Locked")
		else
			locked = FALSE
			balloon_alert(user, "Unlocked")
		playsound(src, 'sound/machines/beep.ogg', 50, 1)
	else
		balloon_alert(user, "Access Denied!")
		playsound(src, 'sound/machines/terminal_error.ogg', 50, 1)
	update_appearance()

/obj/machinery/firealarm/AltClick(mob/user)
	try_lock(user)

/obj/machinery/firealarm/attack_hand(mob/user)
	if(buildstage != 2)
		return ..()
	add_fingerprint(user)
	play_click_sound("button")
	var/area/A = get_area(src)
	if(A.fire)
		if(locked)
			balloon_alert(user, "Cover is locked!")
			playsound(loc, 'sound/effects/glassknock.ogg', 10, FALSE, frequency = 32000)
			return
		reset(user)
	else
		alarm(user)

/obj/machinery/firealarm/attack_silicon(mob/user)
	return attack_hand(user)

/obj/machinery/firealarm/attackby(obj/item/W, mob/user, params)
	add_fingerprint(user)

	if(istype(W, /obj/item/card/id)||istype(W, /obj/item/modular_computer/tablet/pda)) // trying to unlock the cover with an ID card
		try_lock(user)
	if(W.tool_behaviour == TOOL_SCREWDRIVER && buildstage == 2)
		W.play_tool_sound(src)
		panel_open = !panel_open
		to_chat(user, span_notice("The wires have been [panel_open ? "exposed" : "unexposed"]."))
		update_appearance()
		return

	if(panel_open)

		if(W.tool_behaviour == TOOL_WELDER && user.a_intent == INTENT_HELP)
			if(atom_integrity < max_integrity)
				if(!W.tool_start_check(user, amount=0))
					return

				to_chat(user, span_notice("You begin repairing [src]..."))
				if(W.use_tool(src, user, 40, volume=50))
					atom_integrity = max_integrity
					to_chat(user, span_notice("You repair [src]."))
			else
				to_chat(user, span_warning("[src] is already in good condition!"))
			return

		switch(buildstage)
			if(2)
				if(W.tool_behaviour == TOOL_MULTITOOL)
					detecting = !detecting
					if (src.detecting)
						user.visible_message("[user] has reconnected [src]'s detecting unit!", span_notice("You reconnect [src]'s detecting unit."))
					else
						user.visible_message("[user] has disconnected [src]'s detecting unit!", span_notice("You disconnect [src]'s detecting unit."))
					return

				else if(W.tool_behaviour == TOOL_WIRECUTTER)
					buildstage = 1
					W.play_tool_sound(src)
					new /obj/item/stack/cable_coil(user.loc, 5)
					to_chat(user, span_notice("You cut the wires from \the [src]."))
					update_appearance()
					return

				else if(W.force) //hit and turn it on
					..()
					var/area/A = get_area(src)
					if(!A.fire)
						alarm()
					return

			if(1)
				if(istype(W, /obj/item/stack/cable_coil))
					var/obj/item/stack/cable_coil/coil = W
					if(coil.get_amount() < 5)
						to_chat(user, span_warning("You need more cable for this!"))
					else
						coil.use(5)
						buildstage = 2
						to_chat(user, span_notice("You wire \the [src]."))
						update_appearance()
					return

				else if(W.tool_behaviour == TOOL_CROWBAR)
					user.visible_message("[user.name] removes the electronics from [src.name].", \
										span_notice("You start prying out the circuit..."))
					if(W.use_tool(src, user, 20, volume=50))
						if(buildstage == 1)
							if(machine_stat & BROKEN)
								to_chat(user, span_notice("You remove the destroyed circuit."))
								set_machine_stat(machine_stat & ~BROKEN)
							else
								to_chat(user, span_notice("You pry out the circuit."))
								new /obj/item/electronics/firealarm(user.loc)
							buildstage = 0
							update_appearance()
					return
			if(0)
				if(istype(W, /obj/item/electronics/firealarm))
					to_chat(user, span_notice("You insert the circuit."))
					qdel(W)
					buildstage = 1
					update_appearance()
					return

				else if(istype(W, /obj/item/electroadaptive_pseudocircuit))
					var/obj/item/electroadaptive_pseudocircuit/P = W
					if(!P.adapt_circuit(user, 15))
						return
					user.visible_message(span_notice("[user] fabricates a circuit and places it into [src]."), \
					span_notice("You adapt a fire alarm circuit and slot it into the assembly."))
					buildstage = 1
					update_appearance()
					return

				else if(W.tool_behaviour == TOOL_WRENCH)
					user.visible_message("[user] removes the fire alarm assembly from the wall.", \
										span_notice("You remove the fire alarm assembly from the wall."))
					var/obj/item/wallframe/firealarm/frame = new /obj/item/wallframe/firealarm()
					frame.forceMove(user.drop_location())
					W.play_tool_sound(src)
					qdel(src)
					return

	return ..()

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/firealarm, 26)

/obj/machinery/firealarm/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if((buildstage == 0) && (the_rcd.upgrade & RCD_UPGRADE_SIMPLE_CIRCUITS))
		return list("mode" = RCD_UPGRADE_SIMPLE_CIRCUITS, "delay" = 20, "cost" = 1)
	return FALSE

/obj/machinery/firealarm/rcd_act(mob/user, obj/item/construction/rcd/the_rcd, passed_mode)
	switch(passed_mode)
		if(RCD_UPGRADE_SIMPLE_CIRCUITS)
			user.visible_message(span_notice("[user] fabricates a circuit and places it into [src]."), \
			span_notice("You adapt a fire alarm circuit and slot it into the assembly."))
			buildstage = 1
			update_appearance()
			return TRUE
	return FALSE

/obj/machinery/firealarm/take_damage(damage_amount, damage_type = BRUTE, damage_flag = 0, sound_effect = 1, attack_dir, armour_penetration = 0)
	. = ..()
	if(.) //damage received
		if(atom_integrity > 0 && !(machine_stat & BROKEN) && buildstage != 0)
			if(prob(33))
				alarm()

/obj/machinery/firealarm/singularity_pull(S, current_size)
	if (current_size >= STAGE_FIVE) // If the singulo is strong enough to pull anchored objects, the fire alarm experiences integrity failure
		deconstruct()
	..()

/obj/machinery/firealarm/atom_break(damage_flag)
	if(buildstage == 0) //can't break the electronics if there isn't any inside.
		return
	. = ..()
	if(.)
		LAZYREMOVE(myarea.firealarms, src)

/obj/machinery/firealarm/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/iron(loc, 1)
		if(!(machine_stat & BROKEN))
			var/obj/item/I = new /obj/item/electronics/firealarm(loc)
			if(!disassembled)
				I.update_integrity(I.max_integrity * 0.5)
		new /obj/item/stack/cable_coil(loc, 3)
	qdel(src)

/obj/machinery/firealarm/proc/update_fire_light(fire)
	if(fire == !!light_power)
		return  // do nothing if we're already active
	if(fire)
		set_light(l_power = 0.8)
	else
		set_light(l_power = 0)

/*
 * Return of Party button
 */

/area
	var/party = FALSE

/obj/machinery/firealarm/partyalarm
	name = "\improper PARTY BUTTON"
	desc = "Cuban Pete is in the house!"
	var/static/party_overlay

/obj/machinery/firealarm/partyalarm/reset()
	if (machine_stat & (NOPOWER|BROKEN))
		return
	var/area/A = get_area(src)
	if (!A || !A.party)
		return
	A.party = FALSE
	A.cut_overlay(party_overlay)

/obj/machinery/firealarm/partyalarm/alarm()
	if (machine_stat & (NOPOWER|BROKEN))
		return
	var/area/A = get_area(src)
	if (!A || A.party || A.name == "Space")
		return
	A.party = TRUE
	if (!party_overlay)
		party_overlay = iconstate2appearance('icons/turf/areas.dmi', "party")
	A.add_overlay(party_overlay)

#undef FIREALARM_COOLDOWN

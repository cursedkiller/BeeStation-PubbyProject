/obj/effect/proc_holder/spell/targeted/touch
	var/hand_path = /obj/item/melee/touch_attack
	var/obj/item/melee/touch_attack/attached_hand = null
	var/drawmessage = "You channel the power of the spell to your hand."
	var/dropmessage = "You draw the power out of your hand."
	invocation_type = INVOCATION_NONE //you scream on connecting, not summoning
	include_user = TRUE
	range = -1
	//Checks
	var/spell_used = FALSE

/obj/effect/proc_holder/spell/targeted/touch/Destroy()
	remove_hand()
	to_chat(usr, span_notice("The power of the spell dissipates from your hand."))
	..()

/obj/effect/proc_holder/spell/targeted/touch/proc/remove_hand()
	QDEL_NULL(attached_hand)
	if(!spell_used)
		charge_counter = charge_max

/obj/effect/proc_holder/spell/targeted/touch/proc/on_hand_destroy(obj/item/melee/touch_attack/hand)
	if(hand != attached_hand)
		CRASH("Incorrect touch spell hand.")
	//Start recharging.
	attached_hand = null
	recharging = TRUE
	action.UpdateButtonIcon()

/obj/effect/proc_holder/spell/targeted/touch/cast(list/targets,mob/user = usr)
	if(!QDELETED(attached_hand))
		remove_hand()
		to_chat(user, span_notice("[dropmessage]"))
		return

	for(var/mob/living/carbon/target in targets)
		if(!attached_hand && charge_hand(target))
			recharging = FALSE
			return

/obj/effect/proc_holder/spell/targeted/touch/charge_check(mob/user,silent = FALSE)
	if(!QDELETED(attached_hand)) //Charge doesn't matter when putting the hand away.
		return TRUE
	return ..()

/obj/effect/proc_holder/spell/targeted/touch/proc/create_hand()
	return new hand_path(null, src)

/obj/effect/proc_holder/spell/targeted/touch/proc/charge_hand(mob/living/carbon/user)
	attached_hand = create_hand()
	if(!user.put_in_hands(attached_hand))
		remove_hand()
		if (user.usable_hands == 0)
			to_chat(user, span_warning("You dont have any usable hands!"))
		else
			to_chat(user, span_warning("Your hands are full!"))
		return FALSE
	spell_used = FALSE
	to_chat(user, span_notice("[drawmessage]"))
	return TRUE


/obj/effect/proc_holder/spell/targeted/touch/disintegrate
	name = "Disintegrate"
	desc = "This spell charges your hand with vile energy that can be used to violently explode victims."
	hand_path = /obj/item/melee/touch_attack/disintegrate

	school = "evocation"
	charge_max = 600
	clothes_req = TRUE
	cooldown_min = 200 //100 deciseconds reduction per rank

	action_icon_state = "gib"

/obj/effect/proc_holder/spell/targeted/touch/flesh_to_stone
	name = "Flesh to Stone"
	desc = "This spell charges your hand with the power to turn victims into inert statues for a long period of time."
	hand_path = /obj/item/melee/touch_attack/fleshtostone

	school = "transmutation"
	charge_max = 600
	clothes_req = TRUE
	cooldown_min = 200 //100 deciseconds reduction per rank

	action_icon_state = "statue"
	sound = 'sound/magic/fleshtostone.ogg'

/obj/effect/proc_holder/spell/targeted/touch/mutation
	clothes_req = FALSE
	var/datum/mutation/parent_mutation

CREATION_TEST_IGNORE_SUBTYPES(/obj/effect/proc_holder/spell/targeted/touch/mutation)

/obj/effect/proc_holder/spell/targeted/touch/mutation/Initialize(mapload, datum/mutation/_parent)
	. = ..()
	if(!istype(_parent))
		return INITIALIZE_HINT_QDEL
	parent_mutation = _parent

/obj/effect/proc_holder/spell/targeted/touch/mutation/create_hand()
	return new hand_path(null, src, parent_mutation)

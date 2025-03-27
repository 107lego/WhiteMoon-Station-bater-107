/obj/item/armorkit
	name = "rampart armor kit"
	desc = "A standard Nanotrasen security nanite armoring kit, for reinforcing outerwear."
	icon = 'modular_zzplurt/icons/obj/reinforcekits.dmi'
	icon_state = "sec_armor_kit"
	w_class = WEIGHT_CLASS_SMALL

	var/datum/armor/target_armor = /datum/armor/suit_armor
	var/target_slot = ITEM_SLOT_OCLOTHING
	var/change_allowed = TRUE
	var/list/target_allowed // = GLOB.security_vest_allowed

	var/armor_text = "standard Nanotrasen security armored vest"
	var/target_prefix = "rampart"

/obj/item/armorkit/Initialize(mapload) // You're killing me here.
	. = ..()
	target_allowed = GLOB.security_vest_allowed

/obj/item/armorkit/afterattack(obj/item/target, mob/user, click_parameters)
	var/used = FALSE

	stack_trace("[src] started afterattack.")

	if(!(isobj(target) && target.slot_flags & target_slot))
		to_chat(user, "<span class = 'notice'>You can't reinforce [target] with [src].</span>")
		stack_trace("[src] aborted afterattack.")
		return

	stack_trace("[src] check passed.")

	var/obj/item/clothing/C = target
	var/datum/armor/curr_armor = C.get_armor()

	for(var/curr_stat in ARMOR_LIST_ALL())
		if(curr_armor.get_rating(curr_stat) < target_armor.get_rating(curr_stat))
			C.set_armor(curr_armor.generate_new_with_specific(list(curr_stat = target_armor.get_rating(curr_stat))))
			used = TRUE

	if(used)
		if(change_allowed)
			C.allowed = target_allowed
		user.visible_message("<span class = 'notice'>[user] reinforces [C] with [src].</span>", \
		"<span class = 'notice'>You reinforce [C] with [src], making it as protective as \a [armor_text].</span>")
		C.name = "[target_prefix] [C.name]"
		qdel(src)
		return

	to_chat(user, "<span class = 'notice'>You don't need to reinforce [C] any further.")
	return

/obj/item/armorkit/helmet
	name = "rampart headgear kit"
	desc = "A standard Nanotrasen security nanite armoring kit, for reinforcing hats or other headgear."
	icon_state = "sec_helmet_kit"

	target_armor = /datum/armor/head_helmet
	target_slot = ITEM_SLOT_HEAD
	change_allowed = FALSE
	// target_allowed = GLOB.security_vest_allowed

	armor_text = "standard Nanotrasen security helmet"
	// target_prefix = "rampart"

/obj/item/armorkit/blueshield
	name = "aegis armor kit"
	desc = "An elite Nanotrasen nanite armoring kit, for reinforcing outerwear."
	icon_state = "blueshield_armor_kit"

	target_armor = /datum/armor/suit_armor/blueshield
	// target_slot = ITEM_SLOT_OCLOTHING
	// change_allowed = TRUE
	// target_allowed = GLOB.security_vest_allowed

	armor_text = "elite Nanotrasen blueshield armored vest"
	target_prefix = "aegis"

/obj/item/armorkit/helmet/blueshield
	name = "aegis headgear kit"
	desc = "An elite Nanotrasen security nanite armoring kit, for reinforcing hats or other headgear."
	icon_state = "blueshield_helmet_kit"

	target_armor = /datum/armor/head_helmet/blueshield
	// target_slot = ITEM_SLOT_HEAD
	// change_allowed = FALSE
	// target_allowed = GLOB.security_vest_allowed

	armor_text = "elite Nanotrasen blueshield helmet"
	target_prefix = "aegis"

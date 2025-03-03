GLOBAL_VAR_INIT(hhStorageTurf, null)
GLOBAL_VAR_INIT(hhMysteryroom_number, rand(1, 999999))

#define ROOM_OPEN TRUE
#define ROOM_CLOSED FALSE

#define ROOM_VISIBLE TRUE
#define ROOM_INVISIBLE FALSE

#define ROOM_GUESTS_VISIBLE TRUE
#define ROOM_GUESTS_HIDDEN FALSE

/obj/item/hilbertshotel
	name = "Hilbert's Hotel"
	desc = "A sphere of what appears to be an intricate network of bluespace. Observing it in detail seems to give you a headache as you try to comprehend the infinite amount of infinitesimally distinct points on its surface."
	icon = 'icons/obj/structures.dmi'
	icon_state = "hilbertshotel"
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	// Some placeholder templates
	var/datum/map_template/hilbertshotel/hotel_room_template
	var/datum/map_template/hilbertshotel/empty/hotel_room_template_empty
	var/datum/map_template/hilbertshotel/lore/hotel_room_template_lore
	/**
	 * List of active rooms with their data.\
	 * Format:\
	 * `list("room_number" = list(
	 *   "reservation" = datum/turf_reservation,
	 *   "status" = ROOM_CLOSED/OPEN,
	 *   "visibility" = ROOM_VISIBLE/INVISIBLE,
	 *   "privacy" = ROOM_GUESTS_VISIBLE/HIDDEN
	 * ))
	 * `
	*/
	var/list/room_data = list()
	/// List of stored rooms.
	var/list/conservated_rooms = list()
	var/storageTurf
	// Lore stuff
	var/lore_room_spawned = FALSE

	var/list/hotel_map_list = list()
	/// Name of the first template in the list - used as default
	var/default_template
	/// Current room number being viewed
	var/current_room_number = 1

	// List of strings used for the prompt check-in message
	var/static/list/vanity_strings = list(
		"You feel a strange sense of déjà vu.",
		"You feel chills rolling down your spine.",
		"You suddenly feel like you're being watched from behind.",
		"You feel like a gust of bone-chilling cold is passing through you.",
		"Your vision gets a little blurry for a moment.",
		"Your heart sinks as you feel a strange sense of dread.",
		"Your mouth goes dry.",
		"You feel uneasy.",
	)

	/// List of user preferences. Format: list(ckey = list("room_number" = number, "template" = template_name))
	var/list/user_data = list()

// Links to the main sphere to have a common room dataset
GLOBAL_VAR(main_hilbert_sphere)

/obj/item/hilbertshotel/New()
	. = ..()
	if(!GLOB.main_hilbert_sphere)
		GLOB.main_hilbert_sphere = src

/obj/item/hilbertshotel/Initialize(mapload)
	. = ..()
	INVOKE_ASYNC(src, PROC_REF(prepare_rooms))

/obj/item/hilbertshotel/ghostdojo/examine(mob/user)
	. = ..()
	if(!(src == GLOB.main_hilbert_sphere))
		. += span_notice("It's slightly trembling.")

/// Creates a static hotel room template list iterating over the templates typecache. Initializes the templates.
/obj/item/hilbertshotel/proc/prepare_rooms()
	var/list/hotel_map_templates = typecacheof(list(
		/datum/map_template/ghost_cafe_rooms,
	))

	hotel_room_template = new()
	hotel_room_template_empty = new()
	hotel_room_template_lore = new()

	for(var/template_type in hotel_map_templates)
		var/datum/map_template/this_template = new template_type()
		hotel_map_list[this_template.name] = this_template

	default_template = hotel_map_list[hotel_map_list[1]]
	var/area/currentArea = get_area(src)
	if(currentArea.type == /area/ruin/space/has_grav/powered/hilbertresearchfacility/secretroom)
		lore_room_spawned = TRUE

/obj/item/hilbertshotel/Destroy()
	eject_all_rooms()
	return ..()

/obj/item/hilbertshotel/attack_tk(mob/user)
	to_chat(user, span_notice("\The [src] actively rejects your mind as the bluespace energies surrounding it disrupt your telekinesis."))
	return COMPONENT_CANCEL_ATTACK_CHAIN

/// Runs all necessary checks before allowing a user to be moved to a room (or not). Requires `room_number` and `template` to be set.
/obj/item/hilbertshotel/proc/prompt_check_in(mob/user, mob/target, room_number, template)
	if(room_number > SHORT_REAL_LIMIT)
		to_chat(target, span_warning("You have to check out the first [SHORT_REAL_LIMIT] rooms before you can go to a higher numbered one!"))
		return

	var/obj/item/hilbertshotel/main_sphere = GLOB.main_hilbert_sphere
	// Checking for conservated rooms
	if(main_sphere?.conservated_rooms["[room_number]"])
		to_chat(target, span_notice(pick(vanity_strings))) // We're lucky - a conservated room exists which means we don't have to check for other stuff here
		if(try_join_conservated_room(room_number, target))
			return
	// Checking for active rooms
	else if(main_sphere?.room_data["[room_number]"])
		var/list/room = main_sphere.room_data["[room_number]"]
		if(room["status"] == ROOM_CLOSED)
			to_chat(target, span_warning("This room is currently closed and cannot be entered!"))
			return
		// Try to enter if room is open
		if(try_join_active_room(room_number, target))
			return
	// Don't allow creating new room if it exists in any form. If we're here, that means that either the room with the same number is closed or somehow the conservated room with the same number is closed... yikes.
	else if(main_sphere?.room_data["[room_number]"] || main_sphere?.conservated_rooms["[room_number]"])
		to_chat(target, span_warning("This room number is already taken!"))
		return
	// Orb is not adjacent to the target. No teleporties.
	if(!src.Adjacent(target))
		to_chat(target, span_warning("You too far away from \the [src] to enter it!"))
		return
	// If the target is incapacitated after selecting a room, they're not allowed to teleport.
	if(target.incapacitated)
		to_chat(target, span_warning("You aren't able to activate \the [src] anymore!"))
		return

	// Some vanity stuff I guess? Also kudos to the dev for HL reference lol
	if(src.type == /obj/item/hilbertshotel)
		if(!(get_atom_on_turf(src, /mob) == user))
			to_chat(user, span_warning("\The [src] is no longer in your possession!"))
			return
		if(user == target)
			if(!user.get_held_index_of_item(src))
				to_chat(user, span_warning("You try to drop \the [src], but it's too late! It's no longer in your hands! Prepare for unforeseen consequences..."))
			else if(!user.dropItemToGround(src))
				to_chat(user, span_warning("You can't seem to drop \the [src]! It must be stuck to your hand somehow! Prepare for unforeseen consequences..."))
	else
		to_chat(target, span_notice(pick(vanity_strings)))
	send_to_new_room(room_number, target, template)

/// Attempts to join an existing active room. Returns TRUE if successful, FALSE otherwise. Requires `room_number` to be set.
/obj/item/hilbertshotel/proc/try_join_active_room(room_number, mob/user)
	var/obj/item/hilbertshotel/main_sphere = GLOB.main_hilbert_sphere
	if(main_sphere?.room_data["[room_number]"])
		var/datum/turf_reservation/roomReservation = main_sphere.room_data["[room_number]"]["reservation"]
		do_sparks(3, FALSE, get_turf(user))
		var/turf/room_bottom_left = roomReservation.bottom_left_turfs[1]
		user.forceMove(locate(
			room_bottom_left.x + hotel_room_template.landingZoneRelativeX,
			room_bottom_left.y + hotel_room_template.landingZoneRelativeY,
			room_bottom_left.z,
		))
		return TRUE
	return FALSE

/// Attempts to recreate and join an existing stored room. Returns TRUE if successful, FALSE otherwise. Requires `room_number` to be set.
/obj/item/hilbertshotel/proc/try_join_conservated_room(room_number, mob/user)
	var/obj/item/hilbertshotel/main_sphere = GLOB.main_hilbert_sphere
	if(!main_sphere?.conservated_rooms["[room_number]"])
		return FALSE

	var/datum/turf_reservation/roomReservation = SSmapping.request_turf_block_reservation(hotel_room_template.width, hotel_room_template.height, 1)
	var/turf/room_turf = roomReservation.bottom_left_turfs[1]

	// Получаем имя шаблона из сохраненных данных
	var/template_name = main_sphere.conservated_rooms["[room_number]"]["template_name"]
	var/datum/map_template/load_template

	// Выбираем правильный шаблон на основе сохраненного имени
	if(template_name in hotel_map_list)
		load_template = hotel_map_list[template_name]
	else
		load_template = hotel_room_template_empty

	// Загружаем правильный базовый шаблон
	load_template.load(room_turf)

	// Восстанавливаем содержимое комнаты
	var/turfNumber = 1
	for(var/x in 0 to hotel_room_template.width-1)
		for(var/y in 0 to hotel_room_template.height-1)
			for(var/atom/movable/A in main_sphere.conservated_rooms["[room_number]"][turfNumber])
				if(istype(A.loc, /obj/item/abstracthotelstorage))
					A.forceMove(locate(
						room_turf.x + x,
						room_turf.y + y,
						room_turf.z,
					))
			turfNumber++

	// Очищаем хранилище
	for(var/obj/item/abstracthotelstorage/this_item in storageTurf)
		if((this_item.room_number == room_number) && (this_item.parentSphere == src))
			qdel(this_item)

	// Обновляем данные комнаты
	main_sphere.conservated_rooms -= "[room_number]"
	main_sphere.room_data["[room_number]"] = list(
		"reservation" = roomReservation,
		"status" = ROOM_CLOSED,
		"visibility" = ROOM_VISIBLE,
		"privacy" = ROOM_GUESTS_HIDDEN,
		"description" = null,
		"template_name" = template_name
	)

	link_turfs(roomReservation, room_number)
	do_sparks(3, FALSE, get_turf(user))
	user.forceMove(locate(
		room_turf.x + hotel_room_template.landingZoneRelativeX,
		room_turf.y + hotel_room_template.landingZoneRelativeY,
		room_turf.z,
	))
	return TRUE

/// Creates a new room. Loads the room template and sends the user there. Requires `room_number` and `chosen_room` to be set.
/obj/item/hilbertshotel/proc/send_to_new_room(room_number, mob/user, chosen_room)
	var/obj/item/hilbertshotel/main_sphere = GLOB.main_hilbert_sphere
	if(!main_sphere)
		return

	var/datum/turf_reservation/roomReservation = SSmapping.request_turf_block_reservation(hotel_room_template.width, hotel_room_template.height, 1)
	var/turf/bottom_left = roomReservation.bottom_left_turfs[1]
	var/datum/map_template/load_from = hotel_room_template

	if(lore_room_spawned && room_number == GLOB.hhMysteryroom_number)
		load_from = hotel_room_template_lore

	if(chosen_room in hotel_map_list)
		load_from = hotel_map_list[chosen_room]
	else
		to_chat(user, span_warning("You are washed over by a wave of heat as the sphere violently wiggles. You wonder if you did something wrong..."))
		return

	load_from.load(bottom_left)
	main_sphere.room_data["[room_number]"] = list(
		"reservation" = roomReservation,
		"status" = ROOM_CLOSED,
		"visibility" = ROOM_VISIBLE,
		"privacy" = ROOM_GUESTS_HIDDEN,
		"description" = null,
		"template_name" = chosen_room,
		"name" = chosen_room
	)
	link_turfs(roomReservation, room_number)
	do_sparks(3, FALSE, get_turf(user))
	user.forceMove(locate(
		bottom_left.x + hotel_room_template.landingZoneRelativeX,
		bottom_left.y + hotel_room_template.landingZoneRelativeY,
		bottom_left.z,
	))

/obj/item/hilbertshotel/proc/link_turfs(datum/turf_reservation/currentReservation, currentroom_number)
	var/turf/room_bottom_left = currentReservation.bottom_left_turfs[1]
	var/area/misc/hilbertshotel/currentArea = get_area(room_bottom_left)

	currentArea.name = "Hilbert's Hotel Room [currentroom_number]"
	currentArea.parentSphere = src
	currentArea.storageTurf = storageTurf
	currentArea.room_number = currentroom_number
	currentArea.reservation = currentReservation

	for(var/turf/closed/indestructible/hoteldoor/door in currentReservation.reserved_turfs)
		door.parentSphere = src
		door.desc = "The door to this hotel room. \
			The placard reads 'Room [currentroom_number]'. \
			Strangely, this door doesn't even seem openable. \
			The doorknob, however, seems to buzz with unusual energy...<br/>\
			[span_info("Alt-Click to look through the peephole.")]"
	for(var/turf/T in currentReservation.reserved_turfs)
		for(var/obj/machinery/room_controller/controller in T.contents)
			controller.room_number = currentroom_number
			controller.update_appearance()
	for(var/turf/open/space/bluespace/BSturf in currentReservation.reserved_turfs)
		BSturf.parentSphere = src

/obj/item/hilbertshotel/proc/generate_occupant_list(room_number)
	var/list/occupants = list()
	if(room_data["[room_number]"])
		var/datum/turf_reservation/room = room_data[room_number]["reservation"]
		var/turf/room_bottom_left = room.bottom_left_turfs[1]
		for(var/i in 0 to hotel_room_template.width-1)
			for(var/j in 0 to hotel_room_template.height-1)
				for(var/atom/movable/movable_atom in locate(room_bottom_left.x + i, room_bottom_left.y + j, room_bottom_left.z))
					if(ismob(movable_atom))
						var/mob/this_mob = movable_atom
						if(isliving(this_mob))
							if(this_mob.mind)
								occupants += this_mob.mind.name
	return occupants

/obj/item/hilbertshotel/proc/eject_all_rooms()
	if(room_data.len)
		for(var/number in room_data)
			var/datum/turf_reservation/room = room_data[number]["reservation"]
			var/turf/room_bottom_left = room.bottom_left_turfs[1]
			for(var/i in 0 to hotel_room_template.width-1)
				for(var/j in 0 to hotel_room_template.height-1)
					for(var/atom/movable/A in locate(room_bottom_left.x + i, room_bottom_left.y + j, room_bottom_left.z))
						if(ismob(A))
							var/mob/M = A
							if(M.mind)
								to_chat(M, span_warning("As the sphere breaks apart, you're suddenly ejected into the depths of space!"))
						var/max = world.maxx-TRANSITIONEDGE
						var/min = 1+TRANSITIONEDGE
						var/list/possible_transtitons = list()
						for(var/AZ in SSmapping.z_list)
							var/datum/space_level/D = AZ
							if (D.linkage == CROSSLINKED)
								possible_transtitons += D.z_value
						var/_z = pick(possible_transtitons)
						var/_x = rand(min,max)
						var/_y = rand(min,max)
						var/turf/T = locate(_x, _y, _z)
						A.forceMove(T)
			qdel(room)

	if(conservated_rooms.len)
		for(var/x in conservated_rooms)
			var/list/atomList = conservated_rooms[x]
			for(var/atom/movable/A in atomList)
				var/max = world.maxx-TRANSITIONEDGE
				var/min = 1+TRANSITIONEDGE
				var/list/possible_transtitons = list()
				for(var/AZ in SSmapping.z_list)
					var/datum/space_level/D = AZ
					if (D.linkage == CROSSLINKED)
						possible_transtitons += D.z_value
				var/_z = pick(possible_transtitons)
				var/_x = rand(min,max)
				var/_y = rand(min,max)
				var/turf/T = locate(_x, _y, _z)
				A.forceMove(T)

// Template Stuff
/datum/map_template/hilbertshotel
	name = "Hilbert's Hotel Room"
	mappath = "_maps/templates/hilbertshotel.dmm"
	var/landingZoneRelativeX = 2
	var/landingZoneRelativeY = 8
	var/category = "Misc"

/datum/map_template/hilbertshotel/empty
	name = "Empty Hilbert's Hotel Room"
	mappath = "_maps/templates/hilbertshotelempty.dmm"

/datum/map_template/hilbertshotel/lore
	name = "Doctor Hilbert's Deathbed"
	mappath = "_maps/templates/hilbertshotellore.dmm"

/datum/map_template/hilbertshotelstorage
	name = "Hilbert's Hotel Storage"
	mappath = "_maps/templates/hilbertshotelstorage.dmm"


//Turfs and Areas
/turf/closed/indestructible/hotelwall
	name = "hotel wall"
	desc = "A wall designed to protect the security of the hotel's guests."
	icon_state = "hotelwall"
	smoothing_groups = SMOOTH_GROUP_CLOSED_TURFS + SMOOTH_GROUP_HOTEL_WALLS
	canSmoothWith = SMOOTH_GROUP_HOTEL_WALLS
	explosive_resistance = INFINITY

/turf/open/indestructible/hotelwood
	desc = "Stylish dark wood with extra reinforcement. Secured firmly to the floor to prevent tampering."
	icon_state = "wood"
	footstep = FOOTSTEP_WOOD
	tiled_dirt = FALSE

/turf/open/indestructible/hoteltile
	desc = "Smooth tile with extra reinforcement. Secured firmly to the floor to prevent tampering."
	icon_state = "showroomfloor"
	footstep = FOOTSTEP_FLOOR
	tiled_dirt = FALSE

/turf/open/space/bluespace
	name = "\proper bluespace hyperzone"
	icon_state = "bluespace"
	base_icon_state = "bluespace"
	baseturfs = /turf/open/space/bluespace
	turf_flags = NOJAUNT
	explosive_resistance = INFINITY
	var/obj/item/hilbertshotel/parentSphere

/turf/open/space/bluespace/Initialize(mapload)
	. = ..()
	update_icon_state()

/turf/open/space/bluespace/update_icon_state()
	icon_state = base_icon_state
	return ..()

/turf/open/space/bluespace/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(parentSphere && arrived.forceMove(get_turf(parentSphere)))
		do_sparks(3, FALSE, get_turf(arrived))

/turf/closed/indestructible/hoteldoor
	name = "Hotel Door"
	icon_state = "hoteldoor"
	explosive_resistance = INFINITY
	var/obj/item/hilbertshotel/parentSphere

/turf/closed/indestructible/hoteldoor/Initialize(mapload)
	. = ..()
	register_context()

/turf/closed/indestructible/hoteldoor/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	context[SCREENTIP_CONTEXT_ALT_LMB] = "Peek through"
	return CONTEXTUAL_SCREENTIP_SET

/turf/closed/indestructible/hoteldoor/proc/promptExit(mob/living/user)
	if(!isliving(user))
		return
	if(!user.mind)
		return
	if(!parentSphere)
		to_chat(user, span_warning("The door seems to be malfunctioning and refuses to operate!"))
		return
	if(tgui_alert(user, "Hilbert's Hotel would like to remind you that while we will do everything we can to protect the belongings you leave behind, we make no guarantees of their safety while you're gone, especially that of the health of any living creatures. With that in mind, are you ready to leave?", "Exit", list("Leave", "Stay")) == "Leave")
		if(HAS_TRAIT(user, TRAIT_IMMOBILIZED) || (get_dist(get_turf(src), get_turf(user)) > 1)) //no teleporting around if they're dead or moved away during the prompt.
			return
		user.forceMove(get_turf(parentSphere))
		do_sparks(3, FALSE, get_turf(user))

/turf/closed/indestructible/hoteldoor/attack_ghost(mob/dead/observer/user)
	if(!isobserver(user) || !parentSphere)
		return ..()
	user.forceMove(get_turf(parentSphere))

//If only this could be simplified...
/turf/closed/indestructible/hoteldoor/attack_tk(mob/user)
	return //need to be close.

/turf/closed/indestructible/hoteldoor/attack_hand(mob/user, list/modifiers)
	promptExit(user)

/turf/closed/indestructible/hoteldoor/attack_animal(mob/user, list/modifiers)
	promptExit(user)

/turf/closed/indestructible/hoteldoor/attack_paw(mob/user, list/modifiers)
	promptExit(user)

/turf/closed/indestructible/hoteldoor/attack_hulk(mob/living/carbon/human/user)
	promptExit(user)

/turf/closed/indestructible/hoteldoor/attack_larva(mob/user, list/modifiers)
	promptExit(user)

/turf/closed/indestructible/hoteldoor/attack_robot(mob/user)
	if(get_dist(get_turf(src), get_turf(user)) <= 1)
		promptExit(user)

/turf/closed/indestructible/hoteldoor/click_alt(mob/user)
	if(user.is_blind())
		to_chat(user, span_warning("Drats! Your vision is too poor to use this!"))
		return CLICK_ACTION_BLOCKING

	to_chat(user, span_notice("You peek through the door's bluespace peephole..."))
	user.reset_perspective(parentSphere)
	var/datum/action/peephole_cancel/PHC = new
	user.overlay_fullscreen("remote_view", /atom/movable/screen/fullscreen/impaired, 1)
	PHC.Grant(user)
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(check_eye))
	return CLICK_ACTION_SUCCESS

/turf/closed/indestructible/hoteldoor/proc/check_eye(mob/user, atom/oldloc, direction)
	SIGNAL_HANDLER
	if(get_dist(get_turf(src), get_turf(user)) < 2)
		return
	for(var/datum/action/peephole_cancel/PHC in user.actions)
		INVOKE_ASYNC(PHC, TYPE_PROC_REF(/datum/action/peephole_cancel, Trigger))

/datum/action/peephole_cancel
	name = "Cancel View"
	desc = "Stop looking through the bluespace peephole."
	button_icon_state = "cancel_peephole"

/datum/action/peephole_cancel/Trigger(trigger_flags)
	. = ..()
	to_chat(owner, span_warning("You move away from the peephole."))
	owner.reset_perspective()
	owner.clear_fullscreen("remote_view", 0)
	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)
	qdel(src)

// Despite using the ruins.dmi, hilbertshotel is not a ruin
/area/misc/hilbertshotel
	name = "Hilbert's Hotel Room"
	icon = 'icons/area/areas_ruins.dmi'
	icon_state = "hilbertshotel"
	requires_power = FALSE
	has_gravity = TRUE
	area_flags = NOTELEPORT | HIDDEN_AREA
	static_lighting = TRUE
	/* 	SKYRAT EDIT REMOVAL - GHOST HOTEL UPDATE
	ambientsounds = list('sound/ambience/servicebell.ogg')
	SKYRAT EDIT END */
	var/room_number = 0
	var/obj/item/hilbertshotel/parentSphere
	var/datum/turf_reservation/reservation
	var/turf/storageTurf

/area/misc/hilbertshotel/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(istype(arrived, /obj/item/hilbertshotel))
		relocate(arrived)
	var/list/obj/item/hilbertshotel/hotels = arrived.get_all_contents_type(/obj/item/hilbertshotel)
	for(var/obj/item/hilbertshotel/H in hotels)
		if(parentSphere == H)
			relocate(H)

/area/misc/hilbertshotel/proc/relocate(obj/item/hilbertshotel/H)
	if(prob(0.135685)) //Because screw you
		qdel(H)
		return

	// Prepare for...
	var/mob/living/unforeseen_consequences = get_atom_on_turf(H, /mob/living)

	// Turns out giving anyone who grabs a Hilbert's Hotel a free, complementary warp whistle is probably bad.
	// Let's gib the last person to have selected a room number in it.
	if(unforeseen_consequences)
		to_chat(unforeseen_consequences, span_warning("\The [H] starts to resonate. Forcing it to enter itself induces a bluespace paradox, violently tearing your body apart."))
		unforeseen_consequences.investigate_log("has been gibbed by using [H] while inside of it.", INVESTIGATE_DEATHS)
		unforeseen_consequences.gib(DROP_ALL_REMAINS)

	var/turf/targetturf = find_safe_turf()
	if(!targetturf)
		if(GLOB.blobstart.len > 0)
			targetturf = get_turf(pick(GLOB.blobstart))
		else
			CRASH("Unable to find a blobstart landmark")

	log_game("[H] entered itself. Moving it to [loc_name(targetturf)].")
	message_admins("[H] entered itself. Moving it to [ADMIN_VERBOSEJMP(targetturf)].")
	H.visible_message(span_danger("[H] almost implodes in upon itself, but quickly rebounds, shooting off into a random point in space!"))
	H.forceMove(targetturf)

/area/misc/hilbertshotel/Exited(atom/movable/gone, direction)
	. = ..()
	if(ismob(gone))
		var/mob/M = gone
		if(M.mind)
			var/stillPopulated = FALSE
			var/list/currentLivingMobs = get_all_contents_type(/mob/living) //Got to catch anyone hiding in anything
			for(var/mob/living/L in currentLivingMobs) //Check to see if theres any sentient mobs left.
				if(L.mind)
					stillPopulated = TRUE
					break
			if(!stillPopulated)
				conservate_room()

/area/misc/hilbertshotel/proc/conservate_room()
	var/turf/room_bottom_left = reservation.bottom_left_turfs[1]
	var/turf/room_top_right = reservation.top_right_turfs[1]
	var/roomSize = \
		((room_top_right.x - room_bottom_left.x) + 1) * \
		((room_top_right.y - room_bottom_left.y) + 1)
	var/storage[roomSize]
	var/turfNumber = 1
	var/obj/item/abstracthotelstorage/storageObj = new(storageTurf)
	storageObj.room_number = room_number
	storageObj.parentSphere = parentSphere
	storageObj.name = "Room [room_number] Storage"

	for(var/x in 0 to parentSphere.hotel_room_template.width-1)
		for(var/y in 0 to parentSphere.hotel_room_template.height-1)
			var/list/turfContents = list()
			for(var/atom/movable/A in locate(room_bottom_left.x + x, room_bottom_left.y + y, room_bottom_left.z))
				if(ismob(A) && !isliving(A))
					continue
				turfContents += A
				A.forceMove(storageObj)
			storage[turfNumber] = turfContents
			turfNumber++

	var/obj/item/hilbertshotel/main_sphere = GLOB.main_hilbert_sphere
	var/template_name = main_sphere.room_data["[room_number]"]["template_name"]

	if(main_sphere)
		main_sphere.conservated_rooms["[room_number]"] = storage
		main_sphere.conservated_rooms["[room_number]"]["template_name"] = template_name
		main_sphere.room_data -= "[room_number]"
	qdel(reservation)

/area/misc/hilbertshotelstorage
	name = "Hilbert's Hotel Storage Room"
	icon = 'icons/area/areas_ruins.dmi'
	icon_state = "hilbertshotel"
	requires_power = FALSE
	area_flags = HIDDEN_AREA | NOTELEPORT | UNIQUE_AREA
	has_gravity = TRUE

/obj/item/abstracthotelstorage
	anchored = TRUE
	invisibility = INVISIBILITY_ABSTRACT
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	item_flags = ABSTRACT
	var/room_number
	var/obj/item/hilbertshotel/parentSphere

/obj/item/abstracthotelstorage/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	if(istype(arrived, /obj/machinery/light))
		var/obj/machinery/light/entered_light = arrived
		entered_light.end_processing()
	. = ..()
	if(ismob(arrived))
		var/mob/target = arrived
		ADD_TRAIT(target, TRAIT_NO_TRANSFORM, REF(src))

/obj/item/abstracthotelstorage/Exited(atom/movable/gone, direction)
	. = ..()
	if(ismob(gone))
		var/mob/target = gone
		REMOVE_TRAIT(target, TRAIT_NO_TRANSFORM, REF(src))
	if(istype(gone, /obj/machinery/light))
		var/obj/machinery/light/exited_light = gone
		exited_light.begin_processing()

/obj/item/hilbertshotel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "HilbertsHotelCheckout")
		ui.set_autoupdate(TRUE)
		ui.open()

/obj/item/hilbertshotel/ui_data(mob/user)
	var/list/data = list()
	data["hotel_map_list"] = list()
	for(var/template in hotel_map_list)
		var/datum/map_template/ghost_cafe_rooms/room_template = hotel_map_list[template]
		data["hotel_map_list"] += list(list(
			"name" = room_template.name,
			"category" = room_template.category || "Misc"
		))

	if(!user_data[user.ckey])
		user_data[user.ckey] = list(
			"room_number" = 1,
			"template" = default_template
		)

	data["current_room"] = user_data[user.ckey]["room_number"]
	data["selected_template"] = user_data[user.ckey]["template"]

	var/obj/item/hilbertshotel/main_sphere = GLOB.main_hilbert_sphere
	if(main_sphere)
		data["active_rooms"] = list()
		for(var/room_number in main_sphere.room_data)
			var/list/room = main_sphere.room_data[room_number]
			if(room["visibility"] == ROOM_VISIBLE)
				data["active_rooms"] += list(list(
					"number" = room_number,
					"name" = room["template_name"] || "Unknown Room",
					"occupants" = main_sphere.generate_occupant_list(room_number),
					"description" = room["description"],
					"icon" = room["icon"] || "door-open"
				))
		data["conservated_rooms"] = list()
		for(var/room_number in main_sphere.conservated_rooms)
			var/list/room = main_sphere.conservated_rooms[room_number]
			data["conservated_rooms"] += list(list(
				"number" = room_number,
				"description" = room["description"]
			))
	return data

/obj/item/hilbertshotel/ui_act(action, params)
	. = ..()
	if(!usr.ckey)
		return

	if(!user_data[usr.ckey])
		user_data[usr.ckey] = list(
			"room_number" = 1,
			"template" = default_template
		)

	switch(action)
		if("update_room")
			var/new_room = params["room"]
			if(!new_room)
				return FALSE
			if(new_room < 1)
				return FALSE
			user_data[usr.ckey]["room_number"] = new_room
			return TRUE

		if("select_room")
			var/template_name = params["room"]
			if(!(template_name in hotel_map_list))
				return FALSE
			user_data[usr.ckey]["template"] = template_name
			return TRUE

		if("checkin")
			var/template = user_data[usr.ckey]["template"]
			var/room_number = user_data[usr.ckey]["room_number"]
			if(!room_number || !(template in hotel_map_list))
				return FALSE
			var/obj/item/hilbertshotel/main_sphere = GLOB.main_hilbert_sphere
			if(main_sphere?.room_data["[room_number]"])
				to_chat(usr, span_warning("This room is already occupied!"))
				return FALSE
			prompt_check_in(usr, usr, room_number, template)
			return TRUE

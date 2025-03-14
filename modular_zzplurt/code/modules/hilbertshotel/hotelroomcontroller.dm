/obj/item/storage/box/bluespace
	name = "bluespace box"
	desc = "A box that stores items in a bluespace pocket dimension."
	icon = 'modular_zzplurt/icons/obj/machines/room_controller.dmi'
	icon_state = "box"
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	foldable_result = null
	w_class = WEIGHT_CLASS_BULKY
	/// The controller this box was initialized at
	var/datum/weakref/origin_controller
	/// If the controller is currently in a hotel room
	var/in_hotel_room = FALSE
	/// The hotel room area
	var/area/creation_area
	/// If the box was sent to the station (required to ignore area checks)
	var/successfully_sent = FALSE
	/// The name of the person who sent the package to the station
	var/assigned_name = "Unknown"

/obj/item/storage/box/bluespace/proc/return_to_station(name)
	assigned_name = name
	atom_storage.max_slots = 7 // shrinking the box back so it wouldn't get abused
	atom_storage.max_specific_storage = WEIGHT_CLASS_NORMAL
	atom_storage.max_total_storage = WEIGHT_CLASS_SMALL * 7

	name = "bluespace box ([assigned_name])"
	desc += span_info("\nThere's a red \"BLUESPACE-REACTIVE. HANDLE WITH CARE.\" sticker on it.")

	resistance_flags = FLAMMABLE // no more plot armour
	successfully_sent = TRUE
	in_hotel_room = FALSE
	update_appearance()

/obj/item/storage/box/bluespace/update_overlays()
	. = ..()
	if(successfully_sent)
		. += mutable_appearance(icon, "sticker")

/obj/item/storage/box/bluespace/attack_self(mob/user)
	if(!successfully_sent)
		return ..()
	else if(length(contents))
		return ..()
	else
		visible_message(span_danger("[src] begins rapidly shrinking!"))
		var/matrix/shrink_back = matrix()
		shrink_back.Scale(0.1,0.1)
		animate(src, 3 SECONDS, transform = shrink_back)
		addtimer(CALLBACK(src, PROC_REF(fancydelete)), 3 SECONDS)

/obj/item/storage/box/bluespace/proc/fancydelete()
	do_harmless_sparks(3, FALSE, src)
	qdel(src)

/obj/item/storage/box/bluespace/Initialize(mapload)
	. = ..()
	atom_storage.max_specific_storage = WEIGHT_CLASS_GIGANTIC
	atom_storage.max_total_storage = WEIGHT_CLASS_GIGANTIC * INFINITY
	atom_storage.max_slots = INFINITY
	creation_area = get_area(src)
	update_appearance()
	START_PROCESSING(SSobj, src)

/obj/item/storage/box/bluespace/process()
	if(!creation_area)
		return
	if(!in_hotel_room)
		return

	// The INPUT box should NOT exist outside of the hotel room or the storage object
	var/area/current_area = get_area(src)
	if(current_area != creation_area)
		var/obj/machinery/room_controller/controller = origin_controller?.resolve()
		do_harmless_sparks(3, FALSE, src)
		visible_message(span_danger("[src] vanishes in a flash of light!"))
		if(controller)
			forceMove(controller)
			controller.bluespace_box = src
			controller.update_appearance()
		else
			qdel(src)

/*
  ___  ___   ___  __  __    ___ ___  _  _ _____ ___  ___  _    _    ___ ___
 | _ \/ _ \ / _ \|  \/  |  / __/ _ \| \| |_   _| _ \/ _ \| |  | |  | __| _ \
 |   / (_) | (_) | |\/| | | (_| (_) | .` | | | |   / (_) | |__| |__| _||   /
 |_|_\\___/ \___/|_|  |_|  \___\___/|_|\_| |_| |_|_\\___/|____|____|___|_|_\

*/

/obj/machinery/room_controller
	name = "Hilbert's Hotel Room Controller"
	desc = "A mysterious device."
	icon = 'modular_zzplurt/icons/obj/machines/room_controller.dmi'
	icon_state = "room_controller"
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	use_power = NO_POWER_USE
	rad_insulation = RAD_FULL_INSULATION
	integrity_failure = 0
	max_integrity = INFINITY

	/// The main sphere of the hotel, the global room network handler
	var/obj/item/hilbertshotel/main_sphere
	/// The number of the hotel room
	var/room_number
	/// Data of the current room as an associative list
	var/list/current_room_data
	/// The ID card inserted into the controller
	var/inserted_id
	/// The bluespace box inside the controller
	var/obj/item/storage/box/bluespace/bluespace_box
	/// List of roles that are disallowed to use the "Depart" feature
	var/list/disallowed_roles = list(
		/datum/job/ghostcafe,
		/datum/job/hotel_staff,
	)
	/// Vanity desctiption tags
	var/static/list/vanity_tags = list(
		", scribbled all around it",
		". There's a small bloody fingerprint on it",
		". The corner is torn off",
		". It's covered in a thick layer of dust",
		". The writing is smudged, as if someone was in a hurry. You squint your eyes..",
		". The writing is faded",
		". The writing is barely visible",
		". The corner is burnt",
	)


/obj/machinery/room_controller/examine(mob/user)
	. = ..()
	. += span_info("The screen displays [!room_number ? "the word \"Error\". Nothing else." : "some small text and a large number [room_number]."]")

/obj/machinery/room_controller/Initialize()
	. = ..()
	main_sphere = GLOB.main_hilbert_sphere
	if(!main_sphere)
		message_admins("Attention: [ADMIN_VERBOSEJMP(src)] at room [room_number] failed to locate the main hotel sphere!")
		return INITIALIZE_HINT_QDEL
	to_chat(world, "DEBUG: Hilbert's Hotel Room Controller initialized. Main sphere located.")
	bluespace_box = new /obj/item/storage/box/bluespace(src)
	bluespace_box.origin_controller = WEAKREF(src)
	inserted_id = null
	desc += span_info("There is an old tag on the back of the device[pick(vanity_tags)]. 'Last Serviced: 1025-[pick("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")]-[pick("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "10", "31")]'.")

	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom/movable, say), "Welcome to Hilbert's Hotel."), 3 SECONDS)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom/movable, say), "Enjoy your stay!"), 5 SECONDS)
	update_appearance()

/obj/machinery/room_controller/update_overlays()
	. = ..()
	var/list/to_display = list()

	if(!room_number)
		var/mutable_appearance/error = mutable_appearance(icon, "n_err")
		error.pixel_x = 9
		error.pixel_y = -11
		. += error
	else
		var/room_text = "[room_number]"
		to_display = list()

		if(length(room_text) > 3)
			to_display = list(room_text[1], room_text[2], "dot")
		else
			for(var/i in 1 to min(length(room_text), 3))
				to_display += room_text[i]

		var/x_offset = 9
		for(var/digit in to_display)
			var/mutable_appearance/digit_overlay = mutable_appearance(icon, "n_[digit]")
			digit_overlay.pixel_x = x_offset
			digit_overlay.pixel_y = -11
			. += digit_overlay
			x_offset += 4

	. += emissive_appearance(icon, "screen_dim", src)
	if(bluespace_box)
		. += mutable_appearance(icon, "box_inserted")

/obj/machinery/room_controller/proc/can_depart(id)
	var/obj/item/card/id/this_id = id
	if(!this_id)
		return FALSE
	var/datum/job/job = this_id.assignment
	return !(job in disallowed_roles)


/obj/machinery/room_controller/interact(mob/user)
	. = ..()
	ui_interact(user)

/obj/machinery/room_controller/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "HilbertsHotelRoomControl")
		ui.open()

/obj/machinery/room_controller/ui_data(mob/user)
	var/list/data = list()

	var/obj/item/card/id/this_id = inserted_id
	data["id_card"] = this_id?.registered_name
	data["bluespace_box"] = !isnull(bluespace_box)

	if(!room_number || !main_sphere?.room_data["[room_number]"])
		return data

	current_room_data = main_sphere.room_data["[room_number]"]
	data["room_number"] = room_number
	data["room_status"] = current_room_data["status"]
	data["room_visibility"] = current_room_data["visibility"]
	data["room_privacy"] = current_room_data["privacy"]
	data["room_description"] = current_room_data["description"]
	data["name"] = current_room_data["name"]
	data["icon"] = current_room_data["icon"]
	data["can_depart"] = inserted_id ? can_depart(inserted_id) : FALSE
	return data

/obj/machinery/room_controller/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("eject_id")
			if(inserted_id)
				eject_id(inserted_id, usr)
				return TRUE
		if("eject_box")
			if(bluespace_box)
				bluespace_box.forceMove(drop_location())
				bluespace_box = null
				update_appearance()
				return TRUE
		if("depart")
			if(!inserted_id || !can_depart(inserted_id))
				return FALSE
			depart_user(usr)
			return TRUE

	if(!room_number || !main_sphere?.room_data["[room_number]"])
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 10, TRUE)
		say("Room number out of array range.")
		addtimer(CALLBACK(src, TYPE_PROC_REF(/atom/movable, say), "Please contact the hotel staff for further assistance."), 3 SECONDS)
		return

	var/list/room_data = main_sphere.room_data["[room_number]"]
	switch(action)
		if("toggle_visibility")
			room_data["visibility"] = !room_data["visibility"]
			SStgui.update_uis(src)
			SEND_GLOBAL_SIGNAL(COMSIG_HILBERT_ROOM_UPDATED, list("action" = "toggle_visibility", "room" = room_number))
			return TRUE
		if("toggle_status")
			room_data["status"] = !room_data["status"]
			SStgui.update_uis(src)
			SEND_GLOBAL_SIGNAL(COMSIG_HILBERT_ROOM_UPDATED, list("action" = "toggle_status", "room" = room_number))
			return TRUE
		if("toggle_privacy")
			room_data["privacy"] = !room_data["privacy"]
			SStgui.update_uis(src)
			SEND_GLOBAL_SIGNAL(COMSIG_HILBERT_ROOM_UPDATED, list("action" = "toggle_privacy", "room" = room_number))
			return TRUE
		if("confirm_description")
			room_data["description"] = params["description"]
			SStgui.update_uis(src)
			SEND_GLOBAL_SIGNAL(COMSIG_HILBERT_ROOM_UPDATED, list("action" = "update_description", "room" = room_number))
			return TRUE
		if("confirm_name")
			room_data["name"] = params["name"]
			SStgui.update_uis(src)
			SEND_GLOBAL_SIGNAL(COMSIG_HILBERT_ROOM_UPDATED, list("action" = "update_name", "room" = room_number))
			return TRUE
		if("set_icon")
			room_data["icon"] = params["icon"]
			SStgui.update_uis(src)
			SEND_GLOBAL_SIGNAL(COMSIG_HILBERT_ROOM_UPDATED, list("action" = "update_icon", "room" = room_number))
			return TRUE

/obj/machinery/room_controller/emp_act(severity)
	return

/obj/machinery/room_controller/proc/eject_id(id, user)
	var/obj/item/card/id/this_id = id
	var/mob/living/carbon/human/this_humanoid = user
	this_id.forceMove(drop_location())
	if(this_humanoid.CanReach(this_id))
		this_humanoid.put_in_hands(this_id)
	inserted_id = null
	update_appearance()
	SStgui.update_uis(src)
	return TRUE

/obj/machinery/room_controller/attackby(obj/item/item, mob/user, params)
	if(istype(item, /obj/item/card/id))
		if(inserted_id)
			to_chat(user, span_warning("There's already an ID card inside!"))
			return
		if(!user.transferItemToLoc(item, src))
			return
		inserted_id = item
		playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, TRUE)
		update_appearance()
		SStgui.update_uis(src)
		return TRUE
	if(istype(item, /obj/item/storage/box/bluespace))
		if(bluespace_box)
			return
		if(!user.transferItemToLoc(item, src))
			return
		bluespace_box = item
		update_appearance()
		return TRUE
	return ..()

/obj/machinery/room_controller/click_ctrl(mob/user)
	. = ..()
	if(inserted_id)
		if(!eject_id(inserted_id, usr))
			return
		playsound(src, 'sound/machines/terminal/terminal_eject.ogg', 50, TRUE)
		return TRUE
	return ..()

/obj/machinery/room_controller/directional/north
	pixel_x = 0
	pixel_y = 28
	dir = NORTH

/obj/machinery/room_controller/directional/south
	pixel_x = 0
	pixel_y = -28
	dir = SOUTH

/obj/machinery/room_controller/directional/east
	pixel_x = 28
	pixel_y = 0
	dir = EAST

/obj/machinery/room_controller/directional/west
	pixel_x = -28
	pixel_y = 0
	dir = WEST

/obj/machinery/computer/cryopod/announce(message_type, user, rank)
	if(message_type == "CRYO_DEPART")
		radio.talk_into(src, "[user][rank ? ", [rank]" : ""] has departed from the station.", announcement_channel)
	..()

/obj/machinery/room_controller/proc/depart_user(mob/living/departing_mob)
	var/obj/item/card/id/depart_id = inserted_id
	if(!depart_id || !istype(departing_mob) || departing_mob.stat == DEAD)
		return FALSE

	var/job_name = depart_id.assignment
	var/real_name = departing_mob.real_name

	SSjob.FreeRole(job_name)

	if(!length(GLOB.cryopod_computers))
		message_admins("Attention: [ADMIN_VERBOSEJMP(src)] at room [room_number] failed to locate the station cryopod computer!")
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 10, TRUE)
		say("No valid destination points specified.")
		addtimer(CALLBACK(src, TYPE_PROC_REF(/atom/movable, say), "Please contact the hotel staff for further assistance."), 2 SECONDS)
		return
	var/obj/machinery/computer/cryopod/control_computer = GLOB.cryopod_computers[1] // locating the station cryopod computer
	if(control_computer)
		control_computer.announce("CRYO_DEPART", real_name, job_name)
		control_computer.frozen_crew += list(list("name" = real_name, "job" = job_name))

	bluespace_box.return_to_station(real_name)
	bluespace_box.forceMove(control_computer)
	control_computer.frozen_item += bluespace_box
	if(departing_mob.mind)
		departing_mob.mind.objectives = list()
		departing_mob.mind.special_role = null
	visible_message(span_notice("[src] whizzes as it swallows the ID card."))
	playsound(src, 'sound/machines/terminal/terminal_success.ogg', 20, TRUE)
	say("Transfer successful.")
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom/movable, say), "Thank you for your stay!"), 2 SECONDS)
	message_admins("[departing_mob.ckey]/[departing_mob.real_name] departed from room [room_number] as [departing_mob.job].")

	bluespace_box = new /obj/item/storage/box/bluespace(src)
	bluespace_box.origin_controller = WEAKREF(src)

	if(inserted_id)
		qdel(inserted_id)
		inserted_id = null
		update_appearance()
		SStgui.update_uis(src)
	return TRUE

/obj/machinery/room_controller/proc/say_message(message)
	say(message)

/datum/controller/subsystem/ticker/declare_completion(was_forced)
	if(!CONFIG_GET(flag/rounded_embeds)) // SPLURT EDIT - Discord rounded embeds.
		return ..()

	generate_roundend_embed()

	. = ..()

/datum/controller/subsystem/ticker/generate_quote_of_the_round(embed = FALSE)
	if(!embed)
		return ..()

	var/list/data = list()

	data["map_text"] = "__A shift on [SSmapping.current_map.map_name] has ended.__"
	if(quote_of_the_round_text)
		data["quote_presentation"] = "-# [pick(strings("quote_of_the_round.json", "workers"))] [pick(strings("quote_of_the_round.json", "action"))] [pick(strings("quote_of_the_round.json", "message"))] that occured during said shift:"
		data["quote_text"] = "**\"[quote_of_the_round_text]\"**"
		data["quote_attribution"] = "*- [quote_of_the_round_attribution]*"
		to_chat(world, span_notice("A quote of the round was found, and should have been sent to discord."))
		log_runtime("A quote of the round was found, and should have been sent to discord.")
	else
		if(world.time <= quote_of_the_round_record_start)
			to_chat(world, span_notice("A quote of the round could not be found due to the round being too short."))
			data["quote_presentation"] = "-# A quote of the round could not be found. The round ended too early."
			log_runtime("A quote of the round could not be found. The round ended too early.")
		else
			to_chat(world, span_notice("A quote of the round could not be found. Perhaps the crew should be more memorable."))
			data["quote_presentation"] = "-# A quote of the round could not be found. Perhaps the crew should be more memorable."
			log_runtime("A quote of the round could not be found. Perhaps the filters are too strict?")

	return data

/datum/controller/subsystem/ticker/proc/generate_roundend_embed()
	var/list/quote_of_the_round_data = generate_quote_of_the_round(TRUE)
	var/news_report = send_news_report()

	var/first_death = ""
	if(findtext(news_report, "NT Sanctioned Psykers proudly confirm reports that nobody died this shift!"))
		first_death = "NT Sanctioned Psykers proudly confirm reports that nobody died this shift!"
		news_report = replacetext(news_report, first_death, "")
	else if(findtext(news_report, "NT Sanctioned Psykers picked up faint traces of someone near the station, allegedly having had died. Their name was:"))
		var/start_pos = findtext(news_report, "NT Sanctioned Psykers picked up faint traces of someone near the station, allegedly having had died. Their name was:")
		var/end_pos = findtext(news_report, "(Shift on", start_pos)
		first_death = copytext(news_report, start_pos, end_pos)
		news_report = replacetext(news_report, first_death, "")

	var/datum/tgs_chat_embed/structure/embed = new()

	embed.url = "byond://" + (CONFIG_GET(string/public_address) || CONFIG_GET(string/server) || "[world.internet_address]:[world.port]")

	// Author
	embed.author = new("S.P.L.U.R.T. Round Reports")
	embed.author.url = embed.url

	// Title
	embed.title = quote_of_the_round_data["map_text"]

	// Description
	embed.description = "The current round has ended. Please standby for your shift interlude Nanotrasen News Network's report!\n\n```\n[news_report]\n```"

	// Fields
	embed.fields = list()
	embed.fields += new /datum/tgs_chat_embed/field(
		"News Report",
		quote_of_the_round_data["map_text"]
	)
	if(length(first_death))
		embed.fields += new /datum/tgs_chat_embed/field(
			"First Death",
			"```\n[first_death]\n```"
		)
	embed.fields += new /datum/tgs_chat_embed/field(
		"Quote of the round",
		quote_of_the_round_data["quote_presentation"] + (quote_of_the_round_data["quote_text"] ? "\n\n[quote_of_the_round_data["quote_text"]]\n[quote_of_the_round_data["quote_attribution"]]" : "")
	)

	// Embed Image
	/*
	embed.image = new("placeholder.png") // Needs implementation for splashscreens
	*/

	// Thumbnail
	/*
	embed.thumbnail = new("placeholder.png") // Needs implementation for server icon
	*/

	// Footer
	embed.footer = "Round #[GLOB.round_id] ([SSgamemode.storyteller.name])"
	embed.timestamp = time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")

	var/datum/tgs_message_content/message = new("# Round #[GLOB.round_id] ([SSgamemode.storyteller.name]) just ended. [CONFIG_GET(string/roundend_ping_role) ? "<@[CONFIG_GET(string/roundend_ping_role)]>" : ""]")
	message.embed = embed
	for(var/channel_tag in CONFIG_GET(str_list/channel_announce_new_game))
		send2chat(message, channel_tag)

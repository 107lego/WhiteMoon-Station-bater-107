/datum/quirk/succubus
	name = "Succubus"
	desc = "Your seductress-like metabolism can only be sated by semen."
	value = 0
	quirk_flags = /datum/quirk::quirk_flags | QUIRK_PROCESSES
	gain_text = "You feel a craving for certain reproductive fluids."
	lose_text = "Your bodily fluid craving fades back away."
	medical_record_text = "Patient claims to subsist entirely on milk based products."
	mob_trait = TRAIT_SUCCUBUS
	icon = FA_ICON_DROPLET
	mail_goodies = list (
		/datum/glass_style/drinking_glass/cum = 1
	)

/datum/quirk/succubus/add(client/client_source)
	. = ..()
	var/mob/living/carbon/human/H = quirk_holder
	ADD_TRAIT(H, TRAIT_NOHUNGER, QUIRK_TRAIT)
	//ADD_TRAIT(H,TRAIT_NOTHIRST,QUIRK_TRAIT) //Needs thirst system

/datum/quirk/succubus/remove()
	. = ..()
	var/mob/living/carbon/human/H = quirk_holder
	REMOVE_TRAIT(H, TRAIT_NOHUNGER, QUIRK_TRAIT)
	//REMOVE_TRAIT(H,TRAIT_NOTHIRST,QUIRK_TRAIT) //Needs thirst system

/datum/quirk/succubus/process(seconds_per_tick)
	var/mob/living/carbon/human/H = quirk_holder
	H.adjust_nutrition(-0.09)//increases their nutrition loss rate to encourage them to gain a partner they can essentially leech off of

/datum/reagent/consumable/cum/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, times_fired)
	. = ..()
	if(HAS_TRAIT(affected_mob, TRAIT_SUCCUBUS))
		affected_mob.adjust_nutrition(1)

/* Reagent doesn't exist yet
/datum/reagent/consumable/ethanol/cum_in_a_hot_tub/semen/on_mob_life(mob/living/carbon/drinker, seconds_per_tick, times_fired)
	. = ..()
	if(HAS_TRAIT(drinker, TRAIT_SUCCUBUS))
		drinker.adjust_nutrition(0.5)
*/

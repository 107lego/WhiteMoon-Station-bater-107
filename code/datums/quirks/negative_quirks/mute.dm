/datum/quirk/mute
	name = "Немой"
	desc = "По какой-то причине вы совершенно не можете говорить."
	icon = FA_ICON_VOLUME_XMARK
	value = -4
	mob_trait = TRAIT_MUTE
	gain_text = span_danger("Вы не можете говорить!")
	lose_text = span_notice("Вы чувствуете растущую силу в своих голосовых связках.")
	medical_record_text = "Пациент не может использовать свой голос в какой-либо форме. "
	hardcore_value = 4

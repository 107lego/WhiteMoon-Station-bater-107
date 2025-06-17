/datum/quirk/touchy
	name = "На ощуп"
	desc = "Вы очень чувствительны и должны иметь физическую возможность прикоснуться к чему-либо, чтобы это изучить."
	icon = FA_ICON_HAND
	value = -2
	gain_text = span_danger("Вы чувствуете, что не можете рассматривать вещи на расстоянии.")
	lose_text = span_notice("Возникает ощущение, что вы можете рассматривать вещи на расстоянии.")
	medical_record_text = "Пациент не может различать предметы на расстоянии."
	hardcore_value = 4

/datum/quirk/touchy/add(client/client_source)
	RegisterSignal(quirk_holder, COMSIG_CLICK_SHIFT, PROC_REF(examinate_check))

/datum/quirk/touchy/remove()
	UnregisterSignal(quirk_holder, COMSIG_CLICK_SHIFT)

///Checks if the mob is besides the  thing being examined, if they aren't then we cancel their examinate.
/datum/quirk/touchy/proc/examinate_check(mob/examiner, atom/examined)
	SIGNAL_HANDLER

	if(!examined.Adjacent(examiner))
		return COMSIG_MOB_CANCEL_CLICKON

class_name WaveNames
## Satirical wave names, leader assignments, and manifestation groups.
## Lookup by wave number (1-based).

# -- Manifestation groups (every 5 waves) --
const MANIFESTATION_LEADERS := {
	1: "rioter",
	2: "union_boss",
	3: "grandma",
	4: "union_boss",
	5: "student",
	6: "union_boss",
	7: "armored_van",
	8: "armored_van",
}

const MANIFESTATION_NAMES := {
	1: "THE FIRST GATHERING",
	2: "LABOR UPRISING",
	3: "THE ELDERS' MARCH",
	4: "GENERAL STRIKE",
	5: "CAMPUS REVOLT",
	6: "WORKERS' CONGRESS",
	7: "ARMORED CONVOY",
	8: "FINAL OFFENSIVE",
}

const LEADER_MESSAGES := {
	1: "Listen up, bootlicker! We're done asking nicely. The people are in the streets and your little guard towers won't stop us. This is just the beginning — a taste of what's coming. Try to keep up!",
	2: "The workers have spoken, and the answer is NO. No more poverty wages, no more broken promises. We've organized every factory floor in the district. Your budget won't buy you out of this one, comrade.",
	3: "You think rubber bullets scare ME? I survived the bread lines of '89, boy. My knitting circle has more backbone than your entire security apparatus. We're marching, and we brought sandwiches.",
	4: "Every union in the country has walked off the job. Your power grid? Ours. Your supply chain? Ours. You can't tear-gas an entire economy, you bureaucratic parasite. The general strike begins NOW.",
	5: "We read the constitution — you clearly didn't. Every campus in the city is emptying into your precious plaza. We've got nothing to lose but our student debt, and EVERYTHING to fight for!",
	6: "This isn't a protest anymore, it's a CONGRESS. Delegates from every sector, every district. We've drafted our demands and they're non-negotiable. The workers' council is in session.",
	7: "Surprise! We pooled our savings and bought TRUCKS. Your little water cannons look adorable next to reinforced steel. The convoy is rolling and we're not stopping for traffic lights OR tyrants.",
	8: "This is it. Everything we've built, every alliance, every sacrifice — it all comes down to this moment. Full mobilization. Every soul in this city who believes in freedom is at your gates. History is watching.",
}

const INFO := {
	1: {"name": "Unauthorized Loitering", "leader": "rioter"},
	2: {"name": "Disorderly Conduct", "leader": "rioter"},
	3: {"name": "Anonymous Troublemakers", "leader": "masked"},
	4: {"name": "Pensioner Provocation", "leader": "grandma"},
	5: {"name": "Flash Mob Incident", "leader": "rioter"},
	6: {"name": "Counter-Culture Infestation", "leader": "goth_protestor"},
	7: {"name": "Influencer Insurgency", "leader": "blonde_protestor"},
	8: {"name": "Jaywalking Epidemic", "leader": "rioter"},
	9: {"name": "Organized Dissidence", "leader": "masked"},
	10: {"name": "Labor Dispute Escalation", "leader": "union_boss"},
	11: {"name": "Radical Poetry Reading", "leader": "goth_protestor"},
	12: {"name": "Unauthorized Solidarity", "leader": "shield_wall"},
	13: {"name": "Thought Crime Parade", "leader": "masked"},
	14: {"name": "Mask Mandate Violation", "leader": "masked"},
	15: {"name": "Grandma's Tea Party Revolt", "leader": "grandma"},
	16: {"name": "Free Speech Incident", "leader": "rioter"},
	17: {"name": "Spontaneous Hooliganism", "leader": "rioter"},
	18: {"name": "Armored Pacifism", "leader": "shield_wall"},
	19: {"name": "Human Chain Provocation", "leader": "shield_wall"},
	20: {"name": "General Strike Assembly", "leader": "union_boss"},
	21: {"name": "Social Media Incitement", "leader": "blonde_protestor"},
	22: {"name": "Fortified Dissent", "leader": "shield_wall"},
	23: {"name": "Viral Hashtag Uprising", "leader": "blonde_protestor"},
	24: {"name": "LGBTQ March", "leader": "blonde_protestor"},
	25: {"name": "Academic Insurrection", "leader": "student"},
	26: {"name": "Midnight Vandal Swarm", "leader": "rioter"},
	27: {"name": "Candlelight Vigil Ambush", "leader": "blonde_protestor"},
	28: {"name": "Shield Wall Offensive", "leader": "shield_wall"},
	29: {"name": "Underground Railroad", "leader": "infiltrator"},
	30: {"name": "Workers' Congress", "leader": "union_boss"},
	31: {"name": "Barricade Builders", "leader": "rioter"},
	32: {"name": "Motorized Agitation", "leader": "armored_van"},
	33: {"name": "Demagogue's March", "leader": "union_boss"},
	34: {"name": "Convoy of Dissent", "leader": "armored_van"},
	35: {"name": "Armored Column", "leader": "armored_van"},
	36: {"name": "Charismatic Extremism", "leader": "union_boss"},
	37: {"name": "Iron Curtain Breach", "leader": "shield_wall"},
	38: {"name": "Wildcat Revolution", "leader": "rioter"},
	39: {"name": "Full Mobilization", "leader": "armored_van"},
	40: {"name": "REGIME CHANGE ATTEMPT", "leader": "armored_van"},
}


static func get_wave_name(wave_number: int) -> String:
	if INFO.has(wave_number):
		return INFO[wave_number]["name"]
	return "Incident " + str(wave_number)


static func get_wave_leader(wave_number: int) -> String:
	if INFO.has(wave_number):
		return INFO[wave_number]["leader"]
	return "rioter"


static func get_manifestation_group(wave_number: int) -> int:
	return ceili(float(wave_number) / 5.0)


static func get_manifestation_leader_id(wave_number: int) -> String:
	var group := get_manifestation_group(wave_number)
	return MANIFESTATION_LEADERS.get(group, "rioter")


static func get_manifestation_name(wave_number: int) -> String:
	var group := get_manifestation_group(wave_number)
	return MANIFESTATION_NAMES.get(group, "INCIDENT " + str(group))


static func get_leader_message(group: int) -> String:
	return LEADER_MESSAGES.get(group, "The people will not be silenced.")

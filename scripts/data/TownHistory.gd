class_name TownHistory
extends RefCounted

# The town's past, written at the start of each run to fit whoever the vampire is (see the design
# doc, "Registros da cidade"). The anemia deaths began about when the vampire came to Pallbrook
# (or came back to it). Two or three others arrived around the same time, so the books narrow the
# list without naming anyone. The Town Hall wrote the first death down as a fever; only the
# church book, through Father Elias, shows that one too and pins down when it all began.

const THIS_YEAR := 1888
const RECORDS_FROM := THIS_YEAR - 40   # Older pages were torn out (Sophia: "Someone tore the pages out")
const DOCTOR_CAME := THIS_YEAR - 12    # The old doctor served twelve years
const OLD_DOCTOR := "Dr. E. H."

# People buried in Pallbrook over the years (nobody alive today)
const DEAD_NAMES := ["Agnes Mill", "Peter Hale", "Rosa Brandt", "Walter Pryce", "Edith Crane",
		"Samuel Locke", "Ida Fenn", "Thomas Ware", "Martha Cole", "Henry Ashby", "Nell Garrow"]
# What the Town Hall wrote for the deaths that were not the vampire's
const PLAIN_CAUSES := ["old age", "childbirth", "drowned in the river", "winter fever", "a fall from a roof", "consumption"]
# Father Elias's notes in the burial book: on the pale dead, and on the others
const PALE_NOTES := [
	"Pale as wax. The women who washed the body said there was hardly any blood to wash.",
	"So light that two men carried the coffin alone. The colour had gone out of the lips days before.",
	"The candles at the wake made the face look whiter, not warmer. I prayed longer than usual.",
	"Wasted in a fortnight. The doctor could not say what it was.",
]
const PLAIN_NOTES := [
	"A long life. The whole town came.",
	"Rain all through the burial.",
	"The family asked for the old hymns.",
]


# history: {deaths: [{name, year, cause, note, pale}], people: {name: {kind, year, left}}}
# kind: "born" (born here, never left), "arrived" (came in year), "returned" (born here, left in
# "left", came back in year)
static func generate(vampire: String, residents: Array) -> Dictionary:
	var came := THIS_YEAR - randi_range(5, 10)  # When the vampire settled here
	var names := DEAD_NAMES.duplicate()
	names.shuffle()
	var deaths: Array[Dictionary] = []
	# The pale deaths: the first the year it came or the next, then every two or three years
	var year := came + randi_range(0, 1)
	var first := true
	while year < THIS_YEAR and deaths.size() < 3:
		deaths.append({"name": names.pop_back(), "year": year, "pale": true,
				"cause": "winter fever" if first else ["anemia", "weakness of the blood"].pick_random(),
				"note": PALE_NOTES[deaths.size() % PALE_NOTES.size()]})
		first = false
		year += randi_range(2, 3)
	# Ordinary deaths, before and between
	for i in randi_range(3, 4):
		deaths.append({"name": names.pop_back(), "year": randi_range(RECORDS_FROM + 2, THIS_YEAR - 1), "pale": false,
				"cause": PLAIN_CAUSES.pick_random(), "note": PLAIN_NOTES.pick_random()})
	# Jonas, this autumn: no doctor left to sign it, so the mayor did
	deaths.append({"name": "Jonas", "year": THIS_YEAR, "pale": true, "cause": "weakness",
			"note": "Jonas, Clara's husband. Light as a child when we carried him. Clara would not let go of the coffin."})
	deaths.sort_custom(func(a, b): return a["year"] < b["year"])

	# Who came when. The vampire and two decoys around the same years; the rest elsewhere
	var people := {}
	var others := residents.filter(func(n): return n != vampire)
	others.shuffle()
	people[vampire] = _event_near(came, 0)
	for i in mini(2, others.size()):
		people[others[i]] = _event_near(came, randi_range(-1, 1))
	for i in range(2, others.size()):
		people[others[i]] = _event_away_from(came)
	return {"deaths": deaths, "people": people, "came": came}


static func _event_near(year: int, shift: int) -> Dictionary:
	if randf() < 0.65:
		return {"kind": "arrived", "year": year + shift}
	return {"kind": "returned", "year": year + shift, "left": year + shift - randi_range(4, 9)}


# Born here and never left, or came well before or after the vampire did
static func _event_away_from(year: int) -> Dictionary:
	var roll := randf()
	if roll < 0.4:
		return {"kind": "born"}
	var when := randi_range(RECORDS_FROM + 5, year - 3) if roll < 0.75 else randi_range(year + 3, THIS_YEAR - 1)
	when = clampi(when, RECORDS_FROM + 1, THIS_YEAR - 1)
	return {"kind": "arrived", "year": when}

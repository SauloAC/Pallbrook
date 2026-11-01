class_name Items
extends RefCounted

# Ingredients and the remedies the doctor prepares from them (see the design doc, "Medicamentos
# feitos pelo médico"). Every ingredient has more than one source: Gideon sells nearly all of them
# (dearer), some grow by the river or in the woods beyond the bridge (free, but it takes time),
# and later the townsfolk will sell or give them (Tomás's iron filings, Clara's linen...).

# id -> {name, price at Gideon's (0 = he doesn't sell it), where (shown in the casebook)}
const INGREDIENTS := {
	"iron": {"name": "iron salts", "price": 2, "where": "Gideon; iron filings from the forge"},
	"wine": {"name": "red wine", "price": 1, "where": "Gideon; the tavern"},
	"wormwood": {"name": "wormwood", "price": 1, "where": "Gideon; the woods beyond the bridge"},
	"linen": {"name": "linen", "price": 1, "where": "Gideon; the seamstress"},
	"spirits": {"name": "spirits", "price": 1, "where": "Gideon; the tavern"},
	"beeswax": {"name": "beeswax", "price": 1, "where": "Gideon; the church candles"},
	"calendula": {"name": "calendula", "price": 1, "where": "Gideon"},
	"cloves": {"name": "cloves", "price": 2, "where": "Gideon (imported)"},
	"honey": {"name": "honey", "price": 1, "where": "Gideon"},
	"thyme": {"name": "thyme", "price": 1, "where": "Gideon; the woods beyond the bridge"},
	"willow": {"name": "willow bark", "price": 0, "where": "the riverbank, beyond the bridge"},
}

# id -> {name, needs {ingredient: count}, makes (per batch), hours (work), overnight (steeps until
# morning), learned (needs the library book)}
const REMEDIES := {
	"tonic": {"name": "iron tonic", "needs": {"iron": 1, "wine": 1, "wormwood": 1}, "makes": 1, "hours": 1.0, "overnight": true, "learned": true},
	"bandage": {"name": "bandages", "needs": {"linen": 1, "spirits": 1}, "makes": 2, "hours": 0.5},
	"salve": {"name": "burn salve", "needs": {"beeswax": 1, "calendula": 1}, "makes": 2, "hours": 0.5},
	"clove_oil": {"name": "clove oil", "needs": {"cloves": 1}, "makes": 2, "hours": 0.5},
	"syrup": {"name": "honey and thyme syrup", "needs": {"honey": 1, "thyme": 1}, "makes": 2, "hours": 0.5},
	"willow_tea": {"name": "willow bark tea", "needs": {"willow": 1}, "makes": 2, "hours": 0.5},
}
const REMEDY_ORDER := ["tonic", "bandage", "salve", "clove_oil", "syrup", "willow_tea"]


static func item_name(id: String) -> String:
	if INGREDIENTS.has(id):
		return INGREDIENTS[id]["name"]
	if REMEDIES.has(id):
		return REMEDIES[id]["name"]
	return id


# "1 iron salts, 1 red wine..." in the current language
static func needs_text(remedy: String) -> String:
	var parts := PackedStringArray()
	var needs: Dictionary = REMEDIES[remedy]["needs"]
	for ing: String in needs:
		parts.append("%d %s" % [needs[ing], TranslationServer.translate(item_name(ing))])
	return ", ".join(parts)

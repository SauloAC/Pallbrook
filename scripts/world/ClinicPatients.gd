class_name ClinicPatients
extends Node

# Ordinary patients (see the design doc, "Pacientes comuns na clínica"). Every morning from day 2,
# none, one or two townsfolk wake up with something everyday (a burn, a toothache) and walk to the
# clinic on their own. The doctor's daily trade: a coin and some trust for picking the right
# remedy, and they talk while he works. The anemia cases hide among them.

const FIRST_DAY := 2


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(is_night: bool) -> void:
	if is_night or GameState.game_over or GameState.day < FIRST_DAY:
		return
	var people := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if not npc.data or not npc.is_alive():
			continue
		npc.heal_complaint()
		if npc.has_complaint() or npc.has_flu() or npc.appointment_until >= 0.0 or npc.visit_day == GameState.day:
			continue
		if npc.is_vampire() and not npc.walks_by_day():
			continue  # Not on a sunny morning
		people.append(npc)
	people.shuffle()
	var roll := randf()
	var count := 0 if roll < 0.35 else (1 if roll < 0.8 else 2)
	for i in mini(count, people.size()):
		var npc = people[i]
		npc.come_with_complaint(npc.complaints_possible().pick_random())

class_name NPCData
extends Resource

# The "record" of a townsperson: pure data, no behavior

@export var npc_name: String = ""
@export var role: String = ""        # e.g. "Padre", "Taverneira"
@export var color: Color = Color.WHITE
@export_multiline var description: String = ""
@export var schedule: Dictionary[int, String] = {}  # hour -> location name

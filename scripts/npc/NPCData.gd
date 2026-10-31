class_name NPCData
extends Resource

# The "record" of a townsperson: pure data, no behavior

@export var npc_name: String = ""
@export var role: String = ""        # e.g. "Padre", "Taverneira"
@export var female := false  # For Portuguese and Spanish: examiná-la, cansada, culpada (see Lang.g)
@export var color: Color = Color.WHITE
@export_multiline var description: String = ""
@export var schedule: Dictionary[int, String] = {}  # hour -> location name
@export var home: String = ""  # Location name where this NPC sleeps
@export var dialogue_lines: Array[String] = []  # One is picked at random each time
@export var clue_trait: String = ""  # Trace this person leaves behind, e.g. "fuligem de forja"
@export var bedtime: int = 22  # Hour this person goes to bed (if at home)
@export var portrait: Texture2D

extends CharacterBody3D

@export var data: NPCData

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var name_label: Label3D = $NameLabel

func _ready() -> void:
	add_to_group("npcs")  # Lets any system find all townspeople later
	if data == null:
		push_warning("NPC without data: " + name)
		return
	name_label.text = data.npc_name
	# Each NPC gets its own colored material from its data
	var material := StandardMaterial3D.new()
	material.albedo_color = data.color
	mesh.material_override = material

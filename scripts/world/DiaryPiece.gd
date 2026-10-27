extends Node3D

# A torn piece of the old doctor's diary lying somewhere in town. Walk up to it and press E.

const PICK_RANGE := 1.6
const PAPER := Color(0.94, 0.9, 0.8)
const SCRAP_ART := "res://assets/ui/diary/scrap.png"

var piece := ""  # e.g. "5C": sheet 5, piece C ("9W" is the whole last page)
var prompt: Label3D


func _ready() -> void:
	var paper := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.42, 0.42) if not piece.ends_with("W") else Vector2(0.48, 0.48)
	paper.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PAPER
	mat.emission_enabled = true  # A faint glow: easy to miss, but findable at night
	mat.emission = PAPER
	mat.emission_energy_multiplier = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(SCRAP_ART):
		var art: Texture2D = load(SCRAP_ART)
		mat.albedo_color = Color.WHITE
		mat.albedo_texture = art
		mat.emission = Color(0.6, 0.57, 0.5)
		mat.emission_texture = art
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
	paper.material_override = mat
	paper.rotation.y = randf_range(0.0, TAU)
	paper.rotation.z = randf_range(-0.08, 0.08)
	add_child(paper)
	prompt = Label3D.new()
	prompt.text = tr("[E] Pick up")
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.font_size = 40
	prompt.outline_size = 10
	prompt.pixel_size = 0.004
	prompt.position.y = 0.7
	prompt.visible = false
	add_child(prompt)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := false
	if player:
		var gap := player.global_position - global_position
		near = Vector2(gap.x, gap.z).length() < PICK_RANGE and absf(gap.y) < 2.2
	prompt.visible = near and not GameState.in_dialogue and not GameState.reading


# _input, not _unhandled_input: with someone standing next to the paper, picking it up wins
# over starting a conversation
func _input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	GameState.diary["found"][piece] = GameState.day
	Audio.play("page", -4.0)
	Playtest.count("diary_pieces_found")
	Playtest.log_line("Found diary piece %s" % piece)
	if piece == "1W":
		GameState.diary["placed"][piece] = true
		EventBus.dialogue_started.emit("Doctor", tr("A sheet in your predecessor's hand, left where his successor would find it. You put it in your casebook (Tab, Diary)."))
	elif piece.ends_with("W"):
		GameState.diary["placed"][piece] = true  # Whole: straight into the casebook
		EventBus.dialogue_started.emit("Doctor", tr("A whole sheet in the old doctor's hand, hidden among the graves. You put it in your casebook (Tab, Diary)."))
	else:
		EventBus.dialogue_started.emit("Doctor", tr("A torn piece of the old doctor's diary. You tuck it into your casebook (Tab, Diary)."))
	queue_free()

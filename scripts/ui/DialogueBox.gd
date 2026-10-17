extends CanvasLayer

@onready var panel: Control = $Panel
@onready var speaker: Label = $Panel/HBox/VBox/Speaker
@onready var body: Label = $Panel/HBox/VBox/Body
@onready var portrait: TextureRect = $Panel/HBox/Portrait

var opened_frame := -1


func _ready() -> void:
	panel.visible = false
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.player_slept.connect(_close)
	EventBus.player_collapsed.connect(_close)


func _on_dialogue_started(speaker_name: String, line: String) -> void:
	speaker.text = speaker_name
	body.text = line
	panel.visible = true
	GameState.in_dialogue = true
	opened_frame = Engine.get_process_frames()
	var tex := _find_portrait(speaker_name)
	portrait.texture = tex
	portrait.visible = tex != null


func _unhandled_input(event: InputEvent) -> void:
	# Ignore the same key press that opened the box
	if not panel.visible or Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("interact"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	if not panel.visible:
		return
	panel.visible = false
	GameState.in_dialogue = false
	EventBus.dialogue_ended.emit()


func _find_portrait(speaker_name: String) -> Texture2D:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.data.npc_name == speaker_name:
			return npc.data.portrait
	return null

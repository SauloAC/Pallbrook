extends Node

# Music and sound effects. Any file that is missing is simply skipped,
# so sounds start working as soon as they are dropped into assets/audio.

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const EXTENSIONS := ["ogg", "mp3", "wav"]
const MUSIC_DB := -12.0
const AMBIENCE_DB := -16.0
const FADE := 3.0

var day_music: AudioStreamPlayer
var night_music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var title_music: AudioStreamPlayer
var in_title := false
var cache := {}
var last_played := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Book sounds play while the game is paused
	day_music = _looping_player(MUSIC_DIR + "day")
	night_music = _looping_player(MUSIC_DIR + "night")
	ambience = _looping_player(SFX_DIR + "night_amb")
	title_music = _looping_player(MUSIC_DIR + "title")
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.npc_died.connect(func(_n): play("death"))
	EventBus.clue_found.connect(_on_clue_found)
	if not GameState.intro_seen and title_music:
		# Title screen first: the town's music waits until the player presses E
		in_title = true
		_fade(title_music, true, true)
	else:
		_on_phase_changed.call_deferred(GameState.is_night, true)


# Called by the intro when the game begins: title theme out, town music in
func start_game() -> void:
	if not in_title:
		return
	in_title = false
	_fade(title_music, false, false)
	_on_phase_changed(GameState.is_night)


# Plays a short sound by name, e.g. play("page"). min_gap avoids machine-gun repeats.
func play(sound: String, volume_db := 0.0, min_gap := 0.0, pitch_jitter := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - last_played.get(sound, -100.0) < min_gap:
		return
	var stream := _load(SFX_DIR + sound)
	if stream == null:
		return
	last_played[sound] = now
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)  # Small variation so repeats don't sound identical
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


# A sound that comes from a place in the town (doors, steps): quieter when far away.
func play_at(sound: String, position: Vector3, volume_db := 0.0) -> void:
	var stream := _load(SFX_DIR + sound)
	var scene := get_tree().current_scene
	if stream == null or scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 30.0
	p.finished.connect(p.queue_free)
	scene.add_child(p)
	p.global_position = position
	p.play()


func _on_clue_found(_text: String) -> void:
	# Only real findings get the pencil scratch, not every line of conversation
	if not GameState.entries.is_empty() and GameState.entries[-1]["kind"] == "evidence":
		play("clue", -6.0, 0.5, 0.06)


func _on_phase_changed(is_night: bool, instant := false) -> void:
	if in_title:
		return  # Still on the title screen
	if is_night and not instant:
		play("bell", -4.0)
	_fade(day_music, not is_night, instant)
	_fade(night_music, is_night, instant)
	_fade(ambience, is_night, instant, AMBIENCE_DB)


func _fade(player: AudioStreamPlayer, on: bool, instant: bool, level := MUSIC_DB) -> void:
	if player == null:
		return
	var target := level if on else -60.0
	if on and not player.playing:
		player.volume_db = -60.0
		player.play()
	if instant:
		player.volume_db = target
		if not on:
			player.stop()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target, FADE)
	if not on:
		tween.tween_callback(player.stop)


func _looping_player(path: String) -> AudioStreamPlayer:
	var stream := _load(path)
	if stream == null:
		return null
	if "loop" in stream:
		stream.loop = true  # mp3 and ogg loop forever
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -60.0
	add_child(p)
	return p


func _load(path_without_extension: String) -> AudioStream:
	if cache.has(path_without_extension):
		return cache[path_without_extension]
	var stream: AudioStream = null
	for ext in EXTENSIONS:
		var path := "%s.%s" % [path_without_extension, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	cache[path_without_extension] = stream
	return stream

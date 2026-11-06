extends Node

# The town hall clock: its hands show the game's hour.
# (6 Nov) The hands are painted into the face's own picture, pixel by pixel from its centre, every
# game minute: as separate sprites turned on a pivot they were resampled at each angle and drifted a
# pixel or two off the centre. The face is the Clock's "Face" sprite (Cidade.tscn, on the 2D town
# hall's roof); its Clock_Hour and Clock_Minute nodes (the old turning hands) are hidden.

@export var face_name := "Clock"
@export var hour_hand := "Clock_Hour"
@export var minute_hand := "Clock_Minute"

const CENTRE := Vector2i(12, 12)          # The face's middle pixel (clock_face.png, 25 x 25)
const HOUR_LENGTH := 5.5
const MINUTE_LENGTH := 8.5
const HOUR_COLOR := Color8(42, 32, 38)
const MINUTE_COLOR := Color8(74, 42, 30)

var face: Sprite3D
var base: Image
var texture: ImageTexture
var shown_minute := -1


func _ready() -> void:
	# town.glb (and the 2D town hall) may finish loading after us
	await get_tree().process_frame
	var scene := get_tree().current_scene
	for clock in scene.find_children(face_name, "", true, false):
		face = clock.find_child("Face", false, false) as Sprite3D
		if face:
			break
	if face == null or face.texture == null:
		push_warning("ClockTower: clock face not found in the scene")
		return
	for hand in [hour_hand, minute_hand]:
		var node := face.get_parent().find_child(hand, false, false) as Node3D
		if node:
			node.visible = false
	base = face.texture.get_image()
	base.decompress()
	base.convert(Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(base)
	face.texture = texture


func _process(_delta: float) -> void:
	if face == null:
		return
	var minutes := int(fmod(GameState.hour, 12.0) * 60.0)   # Past midnight the hour can run past 24
	if minutes == shown_minute:
		return
	shown_minute = minutes
	var img := base.duplicate() as Image
	# The minute hand first, so the hour hand lies on top of it where they cross
	_hand(img, (minutes % 60) / 60.0, MINUTE_LENGTH, MINUTE_COLOR)
	_hand(img, minutes / 720.0, HOUR_LENGTH, HOUR_COLOR)
	texture.update(img)


# A one-pixel line from the centre at a share of the turn (0 = twelve o'clock, clockwise)
func _hand(img: Image, turn: float, length: float, color: Color) -> void:
	var angle := turn * TAU
	var tip := Vector2(CENTRE) + Vector2(sin(angle), -cos(angle)) * length
	var steps := int(ceil(length)) * 2
	for i in steps + 1:
		var p := Vector2(CENTRE).lerp(tip, float(i) / steps)
		img.set_pixel(roundi(p.x), roundi(p.y), color)

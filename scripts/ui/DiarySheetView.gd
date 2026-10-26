extends Control

# One sheet of the old doctor's diary, drawn from the paper texture and cut into its torn pieces.
# Each line of the sheet is one row; a row is one cell (full width) or two (left | right), and
# each cell belongs to piece A, B or C. Placed pieces are drawn with the paper and their words;
# where two different pieces meet, the edge is torn (a zigzag, the same seen from both sides).
# Missing pieces leave a hole outlined in faint red; clicking one tries the piece in hand there.

signal gap_clicked(letter: String)

const SPLIT := 0.47            # Where left and right halves meet (share of the width)
const TOP := 26.0              # Paper margin above the first line of text
const BOTTOM := 22.0
const SIDE := 26.0             # Paper margin at the outer left/right edges
const JAG := 5.0               # How deep the tear zigzags go
const JAG_STEP := 13.0
const INK := Color("2C2621")
const TEAR := Color(0.36, 0.27, 0.18, 0.75)
const HOLE := Color(0.55, 0.12, 0.09)

var paper: Texture2D
var hand: Font
var sheet := 0
var layout: Array = []         # [[left letter, right letter], ...]
var lines: Array = []          # [[left words, right words], ...]
var placed := {}               # letter -> true
var gap := ""                  # The gap chosen with the keys
var cells: Array = []          # {letter, rect, row, side}
var labels: Array[Label] = []


func _ready() -> void:
	resized.connect(func():
		_build_cells()
		_place_words()
		queue_redraw())


func show_sheet(id: int, sheet_layout: Array, sheet_lines: Array, placed_letters: Dictionary, chosen_gap: String) -> void:
	sheet = id
	layout = sheet_layout
	lines = sheet_lines
	placed = placed_letters
	gap = chosen_gap
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_cells()
	_place_words()
	queue_redraw()


func _build_cells() -> void:
	cells.clear()
	var rows := layout.size()
	if rows == 0:
		return
	var row_h := (size.y - TOP - BOTTOM) / rows
	var split_x := size.x * SPLIT
	for r in rows:
		var y0 := 0.0 if r == 0 else TOP + row_h * r
		var y1 := size.y if r == rows - 1 else TOP + row_h * (r + 1)
		var pair: Array = layout[r]
		if pair[0] == pair[1]:
			cells.append({"letter": pair[0], "rect": Rect2(0, y0, size.x, y1 - y0), "row": r, "side": "full"})
		else:
			cells.append({"letter": pair[0], "rect": Rect2(0, y0, split_x, y1 - y0), "row": r, "side": "left"})
			cells.append({"letter": pair[1], "rect": Rect2(split_x, y0, size.x - split_x, y1 - y0), "row": r, "side": "right"})


func _place_words() -> void:
	for label in labels:
		label.queue_free()
	labels.clear()
	for cell in cells:
		if not placed.has(cell["letter"]):
			continue
		var r: int = cell["row"]
		var halves: Array = lines[r]
		var words: String = halves[0]
		match cell["side"]:
			"left":
				words = halves[0] + "…"
			"right":
				words = "…" + halves[1]
		var rect: Rect2 = cell["rect"]
		var row_h := (size.y - TOP - BOTTOM) / layout.size()
		var text_top := TOP + row_h * r  # The text sits on the line, not in the outer margin
		var label := Label.new()
		label.text = words
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", INK)
		label.add_theme_font_size_override("font_size", 20)
		if hand:
			label.add_theme_font_override("font", hand)
		var left := SIDE if cell["side"] != "right" else 8.0
		var right := SIDE if cell["side"] != "left" else 8.0
		label.position = Vector2(rect.position.x + left, text_top)
		label.size = Vector2(rect.size.x - left - right, row_h)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		labels.append(label)


func _draw() -> void:
	if layout.is_empty():
		# A whole sheet: the paper as it is (its words are a child scroll, see Notebook)
		if paper:
			draw_texture_rect(paper, Rect2(Vector2.ZERO, size), false)
		return
	for cell in cells:
		var points := _cell_outline(cell)
		if placed.has(cell["letter"]):
			var uvs := PackedVector2Array()
			for p in points:
				uvs.append(Vector2(p.x / size.x, p.y / size.y))
			if paper:
				draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, paper)
			else:
				draw_colored_polygon(points, Color(0.94, 0.9, 0.8))
	# Torn seams between two different pieces that are both in place, and the holes
	for cell in cells:
		var letter: String = cell["letter"]
		var points := _cell_outline(cell)
		if not placed.has(letter):
			var chosen := letter == gap
			draw_colored_polygon(points, Color(HOLE, 0.16 if chosen else 0.06))
			var ring := points.duplicate()
			ring.append(points[0])
			draw_polyline(ring, Color(HOLE, 0.95 if chosen else 0.45), 3.0 if chosen else 1.5)
		else:
			for edge in _torn_edges(cell):
				draw_polyline(edge, TEAR, 1.5)


func _letter_at(row: int, x_mid: float) -> String:
	if row < 0 or row >= layout.size():
		return ""
	var pair: Array = layout[row]
	return pair[0] if x_mid < size.x * SPLIT or pair[0] == pair[1] else pair[1]


# The cell's border: straight where it joins the same piece or the sheet's own edge, torn elsewhere
func _cell_outline(cell: Dictionary) -> PackedVector2Array:
	var rect: Rect2 = cell["rect"]
	var a := rect.position
	var b := Vector2(rect.end.x, rect.position.y)
	var c := rect.end
	var d := Vector2(rect.position.x, rect.end.y)
	var out := PackedVector2Array()
	for side in [[a, b, "top"], [b, c, "right"], [c, d, "bottom"], [d, a, "left"]]:
		var from: Vector2 = side[0]
		var to: Vector2 = side[1]
		out.append(from)
		if _is_tear(cell, side[2]):
			out.append_array(_zigzag(from, to))
	return out


func _torn_edges(cell: Dictionary) -> Array:
	var rect: Rect2 = cell["rect"]
	var a := rect.position
	var b := Vector2(rect.end.x, rect.position.y)
	var c := rect.end
	var d := Vector2(rect.position.x, rect.end.y)
	var edges := []
	for side in [[a, b, "top"], [b, c, "right"], [c, d, "bottom"], [d, a, "left"]]:
		if _is_tear(cell, side[2]):
			var line := PackedVector2Array([side[0]])
			line.append_array(_zigzag(side[0], side[1]))
			line.append(side[1])
			edges.append(line)
	return edges


func _is_tear(cell: Dictionary, side: String) -> bool:
	var rect: Rect2 = cell["rect"]
	var row: int = cell["row"]
	var letter: String = cell["letter"]
	match side:
		"top":
			if row == 0:
				return false
			return _letter_at(row - 1, rect.position.x + 1.0) != letter or _letter_at(row - 1, rect.end.x - 1.0) != letter
		"bottom":
			if row == layout.size() - 1:
				return false
			return _letter_at(row + 1, rect.position.x + 1.0) != letter or _letter_at(row + 1, rect.end.x - 1.0) != letter
		"left":
			return cell["side"] == "right" and _letter_at(row, 1.0) != letter
		"right":
			return cell["side"] == "left" and _letter_at(row, size.x - 1.0) != letter
	return false


# Points between two corners, wobbling across the line. Seeded by the edge itself, so the two
# pieces that share an edge tear along exactly the same line.
func _zigzag(from: Vector2, to: Vector2) -> PackedVector2Array:
	var lo := from if (from.x + from.y * 10000.0) < (to.x + to.y * 10000.0) else to
	var hi := to if lo == from else from
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sheet, roundi(lo.x), roundi(lo.y), roundi(hi.x), roundi(hi.y)])
	var length := lo.distance_to(hi)
	var steps := maxi(2, int(length / JAG_STEP))
	var normal := (hi - lo).normalized().orthogonal()
	var pts := PackedVector2Array()
	for i in range(1, steps):
		var t := float(i) / steps
		pts.append(lo.lerp(hi, t) + normal * rng.randf_range(-JAG, JAG))
	if lo != from:
		pts.reverse()
	return pts


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for cell in cells:
			if (cell["rect"] as Rect2).has_point(event.position) and not placed.has(cell["letter"]):
				gap_clicked.emit(cell["letter"])
				accept_event()
				return

class_name EcgDisplay extends Control

@export var samples_per_second: float = 120.0
@export var pixels_per_sample: float = 1.0
@export var background_color: Color = Color(0.02,0.06,0.03)
@export var grid_color: Color = Color(0.12,0.25,0.14,0.45)

var history := PackedFloat32Array()
var sample_accum := 0.0
var phase := 0.0

var bpm := 60.0
var amplitude := 1.0
var noise := 0.01
var trace_color := Color.LIME_GREEN

func _ready() -> void:
	clip_contents = true
	resized.connect(_rebuild_buffer)
	_rebuild_buffer()


func _rebuild_buffer() -> void:
	var count := maxi(int(size.x / maxf(pixels_per_sample, 0.1)) + 1,2)
	history.resize(count)
	history.fill(0.0)
	queue_redraw()
	
func set_health_ratio(ratio: float) -> void:
	
	ratio = clampf(ratio, 0.0, 1.0)
	
	if ratio > 0.6:
		trace_color = Color(0.25,1.0,0.35)
		bpm = 60.0
		amplitude = 1.0
		noise = 0.01
	elif ratio > 0.3:
		trace_color = Color(1.0,0.85,0.15)
		bpm = 95.0
		amplitude = 0.8
		noise = 0.02
	else:
		trace_color = Color(1.0,0.15,0.12)
		bpm = 120.0
		amplitude = 0.65
		noise = 0.04

func _g(t: float, mu: float, sigma: float) -> float:
	var d:= (t-mu) /sigma
	return exp(-0.5 * d * d)

func _beat(t: float) -> float:
	return(
		0.12 * _g(t, 0.15,0.04)
		- 0.15 * _g(t, 0.28, 0.012)
		+ 1.0 * _g(t, 0.31, 0.012)
		- 0.25 * _g(t, 0.34, 0.012)
		+ 0.25 * _g(t, 0.6, 0.6)
	)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or history.is_empty():
		return
		
	sample_accum += delta * samples_per_second
	var steps := mini(int(sample_accum), history.size())
	
	if steps <= 0:
		return
		
	sample_accum -= steps
	
	var sample_step := 1.0 / maxf(samples_per_second, 1.0)
	
	for i in range(steps):
		phase = fmod(phase + (bpm/60.0) * sample_step, 1.0)
		
		var value := _beat(phase) * amplitude
		value += randf_range(-noise, noise)
		
		for j in range(history.size() - 1):
			history[j] = history[j+1]
			
		history[history.size() - 1] = value
	queue_redraw()
	
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	
	for x in range(0, int(size.x), 8):
		draw_line(
			Vector2(x,0),
			Vector2(x, size.y),
			grid_color,
			1.0
		)
		
	for y in range(0, int(size.y), 8): 
		draw_line(
			Vector2(0,y),
			Vector2(size.x, y),
			grid_color,
			1.0
		)		
	if history.size() < 2:
		return
		
	var mid := size.y * 0.5
	var half := size.y * 0.42
	var points := PackedVector2Array()
	
	for i in range(history.size()):
		points.append(
			Vector2(
				i * pixels_per_sample,
				mid - history[i] * half
			)
		)
	draw_polyline(points, trace_color, 1.5, true)

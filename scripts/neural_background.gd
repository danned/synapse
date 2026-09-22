class_name NeuralBackground
extends Node2D

var phase := 0.0
var points: Array[Vector2] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90421
	for index in range(28):
		points.append(Vector2(rng.randf_range(0.02, 0.98), rng.randf_range(0.03, 0.97)))
	set_process(true)

func _process(delta: float) -> void:
	phase += delta
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("071022"))
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.08, 0.25, 0.34, 0.07), 1.0)
	for x in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.08, 0.25, 0.34, 0.06), 1.0)
	for i in range(points.size()):
		var p := Vector2(points[i].x * size.x, points[i].y * size.y)
		var q := Vector2(points[(i * 7 + 3) % points.size()].x * size.x, points[(i * 7 + 3) % points.size()].y * size.y)
		if p.distance_to(q) < 390.0:
			draw_line(p, q, Color(0.2, 0.78, 0.95, 0.045), 1.0)
		var glow := 2.0 + sin(phase * 1.4 + i) * 1.2
		draw_circle(p, maxf(1.0, glow), Color(0.38, 0.96, 0.82, 0.16))


extends Node2D

const SIZE := 3000
const STEP := 120

func _draw() -> void:
	for x in range(-SIZE, SIZE + 1, STEP):
		for y in range(-SIZE, SIZE + 1, STEP):
			draw_circle(Vector2(x, y), 4.0, Color(1, 1, 1, 0.12))

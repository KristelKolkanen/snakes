extends Node2D

@onready var snake = $Snake
@onready var boost_button = $HUD/BoostButton


func _ready() -> void:
	boost_button.boost_changed.connect(snake.set_boost_requested)
	snake.died.connect(_on_snake_died)


func _on_snake_died() -> void:
	# Temporary: just restart. A proper game-over screen comes in Phase 5.
	get_tree().call_deferred("reload_current_scene")

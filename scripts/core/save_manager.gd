extends Node

const PATH := "user://save.cfg"

var player_name := "YOU"
var high_score := 0
var skin_index := 0
var difficulty := "normal"


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		player_name = cfg.get_value("player", "name", player_name)
		high_score = cfg.get_value("player", "high_score", 0)
		skin_index = cfg.get_value("player", "skin", 0)
		difficulty = cfg.get_value("player", "difficulty", "normal")
	Constants.difficulty = difficulty


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "high_score", high_score)
	cfg.set_value("player", "skin", skin_index)
	cfg.set_value("player", "difficulty", difficulty)
	cfg.save(PATH)


# Returns true if this is a new best
func submit_score(score: int) -> bool:
	if score > high_score:
		high_score = score
		save_data()
		return true
	return false

class_name Skins

# colors: stripes of 3 segments each. unlock: best score needed.
const LIST := [
	{"name": "Mint",   "colors": [Color("#5eead4")], "unlock": 0},
	{"name": "Sunset", "colors": [Color("#ff9f1c"), Color("#ff4d6d")], "unlock": 0},
	{"name": "Grape",  "colors": [Color("#b25cff"), Color("#7a3cff")], "unlock": 0},
	{"name": "Candy",  "colors": [Color("#ff5cc8"), Color("#ffffff")], "unlock": 1000},
	{"name": "Ocean",  "colors": [Color("#3a6bff"), Color("#4cc9f0")], "unlock": 2500},
	{"name": "Lime",   "colors": [Color("#5bff8a"), Color("#ffd23f")], "unlock": 4000},
	{"name": "Fire",   "colors": [Color("#ff4d6d"), Color("#ffd23f"), Color("#ff9f1c")], "unlock": 6000},
	{"name": "Ghost",  "colors": [Color("#e8ecff"), Color("#9aa4c7")], "unlock": 9000},
]


static func colors_of(i: int) -> Array:
	return LIST[clampi(i, 0, LIST.size() - 1)]["colors"]


static func is_unlocked(i: int, best: int) -> bool:
	return best >= LIST[i]["unlock"]

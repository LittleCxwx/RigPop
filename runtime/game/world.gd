extends Node2D

var enabled := false
@onready var player: CharacterBody2D = $Character

func configure(model: Dictionary, textures: Dictionary) -> void:
	player.configure(model, textures)

func clear_input() -> void:
	player.clear_input()

func reset_world() -> void:
	player.position = $Spawn.position
	clear_input()

func _process(_delta: float) -> void:
	player.enabled = enabled
	var viewport_size := get_viewport_rect().size
	$Camera.zoom = Vector2.ONE * minf(viewport_size.x / 640.0, viewport_size.y / 400.0)

func _draw() -> void:
	draw_rect(Rect2(-2000, -2000, 4000, 4000), Color("303c39"))
	draw_rect(Rect2(16, 16, 608, 368), Color("778b6c"))
	for y in range(24, 380, 16):
		for x in range(24, 620, 16):
			if (x * 13 + y * 7) % 5 == 0:
				draw_rect(Rect2(x, y, 2, 3), Color("8c9d7b"))
	draw_rect(Rect2(270, 16, 92, 368), Color("a8b6a2"))
	draw_rect(Rect2(16, 204, 608, 52), Color("a8b6a2"))
	for p in [Vector2(128, 112), Vector2(500, 300)]:
		draw_rect(Rect2(p + Vector2(2, 5), Vector2(76, 40)), Color("52684f"))
		draw_rect(Rect2(p, Vector2(76, 40)), Color("a9b7aa"))
		draw_rect(Rect2(p, Vector2(76, 5)), Color("d2dbca"))
		draw_rect(Rect2(p + Vector2(0, 30), Vector2(76, 10)), Color("7e9386"))
	for p in [Vector2(62, 60), Vector2(550, 100), Vector2(70, 330), Vector2(450, 60)]:
		draw_rect(Rect2(p, Vector2(30, 18)), Color("476453"))
		draw_rect(Rect2(p + Vector2(4, -5), Vector2(22, 20)), Color("587a58"))
		draw_rect(Rect2(p + Vector2(10, -8), Vector2(12, 8)), Color("91aa77"))
	draw_circle(Vector2(320, 230), 18, Color("bfd1b0"), false, 1)
	draw_line(Vector2(310, 230), Vector2(330, 230), Color("e0e6cf"))
	draw_line(Vector2(320, 220), Vector2(320, 240), Color("e0e6cf"))

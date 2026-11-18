extends CharacterBody2D

const View = preload("res://runtime/shared/character_view.gd")
const Character = preload("res://core/character.gd")
const Router = preload("res://core/input_router.gd")
const ActionPlayer = preload("res://core/action_player.gd")

var model: Dictionary = {}
var textures: Dictionary = {}
var enabled := true
var router := Router.new()
var view: Node2D
var elapsed := 0.0
var overlay_clock := 0.0
var overlay_id := ""
var forced_id := ""
var forced_clock := 0.0
var actions := ActionPlayer.new()
@export_file("*.json") var character_file := ""

func _ready() -> void:
	view = View.new()
	view.scale = Vector2(2, 2)
	add_child(view)
	if model.is_empty() and not character_file.is_empty():
		load_character(character_file)

func load_character(path: String) -> String:
	var Store = load("res://services/project_store.gd")
	var doc = Store.new()
	var error: String = doc.open_file(path)
	if error.is_empty(): configure(doc.model, doc.textures)
	return error

func configure(data: Dictionary, art: Dictionary) -> void:
	model = data.duplicate(true)
	textures = art
	router.bindings = model.get("bindings", []).duplicate(true)
	actions.configure(model)
	overlay_id = ""
	forced_id = ""
	clear_input()
	if view != null:
		view.model = model
		view.textures = textures
	var collision := get_node_or_null("Collision") as CollisionShape2D
	if collision != null:
		var shape := CircleShape2D.new()
		shape.radius = float(model.get("game", {}).get("collision_radius", 9))
		collision.shape = shape

func clear_input() -> void:
	router.clear()
	velocity = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventKey and (event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
		clear_input()
		return
	var key := Router.key_from_event(event)
	if not key.is_empty():
		for command in router.feed(key, event.pressed, elapsed): execute(command)

func execute(command: String) -> bool:
	if not actions.play(command): return false
	sync_actions()
	return true

func sync_actions() -> void:
	var primary := actions.primary()
	forced_id = str(primary.get("clip", {}).get("id", ""))
	forced_clock = float(primary.get("clock", 0))
	if view == null: return
	view.layers = actions.layers()
	overlay_id = str(view.layers.back().clip.id) if not view.layers.is_empty() else ""
	view.overlay_id = ""

func _physics_process(delta: float) -> void:
	if view == null or model.is_empty(): return
	elapsed += delta
	if not enabled: clear_input()
	actions.advance(delta)
	for command in router.advance(elapsed): execute(command)
	var direction: Vector2 = router.movement() if enabled else Vector2.ZERO
	if actions.blocks_movement(): direction = Vector2.ZERO
	velocity = direction * float(model.get("game", {}).get("speed", 115))
	move_and_slide()
	if direction.x != 0: view.mirrored = direction.x < 0
	view.action_id = "walk" if direction != Vector2.ZERO else "idle"
	var clock := elapsed
	sync_actions()
	if not forced_id.is_empty():
		view.action_id = forced_id
		clock = forced_clock
	var clip := Character.find_action(model, view.action_id)
	if clip.is_empty() and not model.actions.is_empty():
		clip = model.actions[0]
		view.action_id = clip.id
	view.frame = int(clock * float(clip.get("fps", 8))) % maxi(1, int(clip.get("frames", 8)))
	view.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: clear_input()

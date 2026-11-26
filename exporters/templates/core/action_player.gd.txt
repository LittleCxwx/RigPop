extends RefCounted

const Character = preload("res://core/character.gd")

var model: Dictionary = {}
var active: Array[Dictionary] = []

func configure(data: Dictionary) -> void:
	model = data
	active.clear()

func affected_parts(clip: Dictionary) -> Dictionary:
	var result := {}
	for id in clip.get("tracks", {}):
		if not clip.tracks[id].is_empty(): result[id] = true
	if not clip.get("overlay", false):
		for p in model.get("parts", []): result[p.id] = true
	# A joint or parent track also moves all of its descendants.
	for _pass in model.get("parts", []).size():
		var changed := false
		for p in model.get("parts", []):
			if result.has(p.parent) and not result.has(p.id):
				result[p.id] = true
				changed = true
		if not changed: break
	return result

func play(id: String, max_duration: float = INF) -> bool:
	var clip := Character.find_action(model, id)
	if clip.is_empty(): return false
	var parts := affected_parts(clip)
	var replaced: Array[Dictionary] = []
	for current in active:
		var conflicts: bool = not clip.get("overlay", false) or not current.clip.get("overlay", false)
		for part in parts:
			if current.parts.has(part): conflicts = true
		if not conflicts: continue
		if clip.get("conflict", "replace") == "reject" or int(current.clip.get("priority", 0)) > int(clip.get("priority", 0)):
			return false
		replaced.append(current)
	for current in replaced: active.erase(current)
	var duration := float(clip.frames) / maxf(1, float(clip.fps))
	active.append({"clip": clip, "clock": 0.0, "parts": parts,
		"speed": maxf(1.0, duration / maxf(0.01, max_duration))})
	return true

func advance(delta: float) -> void:
	for i in range(active.size() - 1, -1, -1):
		active[i].clock += delta * float(active[i].speed)
		var clip: Dictionary = active[i].clip
		if float(active[i].clock) >= float(clip.frames) / maxf(1, float(clip.fps)):
			active.remove_at(i)

func blocks_movement() -> bool:
	for current in active:
		if current.clip.get("lock_movement", false): return true
	return false

func primary() -> Dictionary:
	for current in active:
		if not current.clip.get("overlay", false): return current
	return {}

func layers() -> Array:
	var result: Array = []
	for current in active:
		if current.clip.get("overlay", false):
			result.append({"clip": current.clip, "frame": int(float(current.clock) * float(current.clip.fps))})
	return result

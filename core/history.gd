extends RefCounted

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

func push(before: Dictionary, label: String) -> void:
	undo_stack.append({"state": before, "label": label})
	if undo_stack.size() > 60:
		undo_stack.pop_front()
	redo_stack.clear()

func undo(current: Dictionary) -> Dictionary:
	if undo_stack.is_empty():
		return {}
	var item: Dictionary = undo_stack.pop_back()
	redo_stack.append({"state": current, "label": item.label})
	return item.state

func redo(current: Dictionary) -> Dictionary:
	if redo_stack.is_empty():
		return {}
	var item: Dictionary = redo_stack.pop_back()
	undo_stack.append({"state": current, "label": item.label})
	return item.state

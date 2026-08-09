extends SceneTree

const PLAYGROUND := "res://scenes/playground.tscn"
const ZONE_B := "res://scenes/zone_b.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveManager._loading = true
	GameState.reset(PLAYGROUND)
	GameState.collect_static_pickup(PLAYGROUND, "mysterious_key")
	GameState.enter_area(ZONE_B)
	GameState.enter_area(PLAYGROUND)

	var level := (load(PLAYGROUND) as PackedScene).instantiate()
	root.add_child(level)
	await process_frame

	var collected_item_removed := not level.has_node("Props/MysteriousKey")
	var uncollected_item_present := level.has_node("Props/OldCoin")
	if not collected_item_removed or not uncollected_item_present:
		push_error("Static pickup persistence regression detected.")
		quit(1)
		return
	quit()

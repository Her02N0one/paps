extends SceneTree

const PLAYGROUND := "res://scenes/levels/playground.tscn"
const ZONE_B := "res://scenes/levels/zone_b.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := GameState.new()
	root.add_child(game_state)
	await process_frame  # allow _ready() to fire so "game_state" group is populated

	game_state.reset(PLAYGROUND)
	game_state.collect_static_pickup(PLAYGROUND, "mysterious_key")
	game_state.enter_area(ZONE_B)
	game_state.enter_area(PLAYGROUND)

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

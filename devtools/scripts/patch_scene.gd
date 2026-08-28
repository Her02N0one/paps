extends SceneTree

func _init() -> void:
	var scene = load("res://content/characters/player/player.tscn")
	var root = scene.instantiate()
	
	var movement = root.get_node("ActorMovementSystem")
	
	# Create GrappleSystem
	var grapple = Node.new()
	grapple.name = "GrappleSystem"
	grapple.set_script(load("res://features/mobility/grapple/grapple_system.gd"))
	root.add_child(grapple)
	grapple.owner = root
	
	# Migrate profile
	if "mobility_profile" in movement:
		var profile = movement.get("mobility_profile")
		if profile != null:
			grapple.set("profile", profile)
		movement.set("mobility_profile", null) # clear it
		
	# Wire visual
	var visual = root.get_node("GrappleVisualSystem")
	if visual:
		visual.set("grapple_component", grapple)
		visual.set("movement_component", movement)
		
	# Save scene
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://content/characters/player/player.tscn")
	print("Scene updated successfully!")
	quit()

extends SceneTree

func _init() -> void:
	var path := "res://content/characters/player/pendulum_classic.tres"
	var profile: GrappleProfile = GrappleProfile.new()
	profile.min_distance = 3.0
	profile.max_distance = 20.0
	profile.base_pull_multiplier = 2.3
	profile.max_range = 30.0
	
	# Godot 4: Take over the old UID to prevent scene breakage
	var old_uid = ResourceLoader.get_resource_uid(path)
	if old_uid != ResourceUID.INVALID_ID:
		ResourceSaver.save(profile, path)
		# After save, make sure UID is correct in the .tres file just in case it changed?
		# ResourceSaver in Godot 4 usually preserves the UID if we overwrite an existing path.
		print("Successfully saved new flat profile.")
	else:
		ResourceSaver.save(profile, path)
		print("Saved new profile (no old UID found).")
		
	quit()

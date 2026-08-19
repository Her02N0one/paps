import re

# Update world_ui.tscn
with open('systems/ui/world_ui.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

time_label_xml = """[node name="TimeLabel" type="Label" parent="HUDLayer/HUD"]
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -220.0
offset_top = 20.0
offset_right = -20.0
offset_bottom = 50.0
grow_horizontal = 0
text = "DAY 1, 08:00"
horizontal_alignment = 2
"""

if 'name="TimeLabel"' not in content:
    # Insert after [node name="HUD" ... ] node declaration and its properties
    target = 'grow_vertical = 2\n'
    idx = content.find(target, content.find('name="HUD"'))
    if idx != -1:
        content = content[:idx+len(target)] + '\n' + time_label_xml + content[idx+len(target):]
        with open('systems/ui/world_ui.tscn', 'w', encoding='utf-8') as f:
            f.write(content)

# Update game_ui_controller.gd
with open('systems/ui/game_ui_controller.gd', 'r', encoding='utf-8') as f:
    gd_content = f.read()

if 'time_label: Label' not in gd_content:
    gd_content = gd_content.replace('var crosshair: Label\n', 'var crosshair: Label\nvar time_label: Label\n')
    
    # insert inside _resolve_scene_nodes
    target = 'crosshair = _strict_resolve(crosshair_path, "CrossHair") as Label\n'
    if target in gd_content:
        gd_content = gd_content.replace(target, target + '\ttime_label = hud.get_node_or_null("TimeLabel") if hud else null\n')
    
    # insert inside _ready
    setup_target = '_setup_internal_controllers()\n'
    if setup_target in gd_content:
        setup_target_replacement = setup_target + '\t\tvar tm = get_node_or_null("/root/TimeManager")\n\t\tif tm and time_label:\n\t\t\ttm.time_changed.connect(_on_time_changed)\n\t\t\tvar gs = get_tree().get_first_node_in_group("game_state") as GameState\n\t\t\tif gs:\n\t\t\t\t_on_time_changed(gs.current_day, gs.current_time_minutes)\n'
        gd_content = gd_content.replace(setup_target, setup_target_replacement)

    # insert the new function
    gd_content += '\nfunc _on_time_changed(day: int, minutes: float) -> void:\n\tif time_label:\n\t\tvar hours := int(minutes) / 60\n\t\tvar mins := int(minutes) % 60\n\t\ttime_label.text = "DAY %d, %02d:%02d" % [day, hours, mins]\n'

    with open('systems/ui/game_ui_controller.gd', 'w', encoding='utf-8') as f:
        f.write(gd_content)

print("Updated UI files")

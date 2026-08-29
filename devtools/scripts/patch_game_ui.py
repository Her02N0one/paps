import re

with open("/home/ayden/Desktop/paps/core/ui/game_ui.tscn", "r") as f:
    data = f.read()

# Add ext_resource for hud_controller
if "hud_controller.gd" not in data:
    ext_res = '[ext_resource type="Script" path="res://core/ui/hud/hud_controller.gd" id="99_hud"]\n'
    # Insert after first ext_resource
    data = re.sub(r'(\[ext_resource.*?\]\n)', r'\1' + ext_res, data, count=1)

# Attach script to HUD node
data = re.sub(
    r'(\[node name="HUD" type="Control" parent="HUDLayer"\]\n)',
    r'\1script = ExtResource("99_hud")\ninteract_hint = NodePath("InteractHint")\ncrosshair = NodePath("CrossHair")\n',
    data
)

# Remove old exports from WorldUI
data = re.sub(r'hud = NodePath\("HUDLayer/HUD"\)\n', '', data)
data = re.sub(r'interact_hint = NodePath\("HUDLayer/HUD/InteractHint"\)\n', '', data)
data = re.sub(r'crosshair = NodePath\("HUDLayer/HUD/CrossHair"\)\n', '', data)

# Add unique names to continue buttons if missing
data = data.replace('name="IntroContinue"', 'name="IntroContinue" unique_name_in_owner=true')

with open("/home/ayden/Desktop/paps/core/ui/game_ui.tscn", "w") as f:
    f.write(data)

print("Patched game_ui.tscn successfully")

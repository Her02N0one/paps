import re

with open('scenes/maps/playground.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add ExtResources
if 'id="campfire_scene"' not in content:
    # find the last ext_resource
    last_ext_idx = content.rfind('[ext_resource')
    if last_ext_idx != -1:
        end_of_line = content.find('\n', last_ext_idx)
        # insert
        injection = '\n[ext_resource type="PackedScene" path="res://entities/interfacables/campfire/campfire.tscn" id="campfire_scene"]'
        content = content[:end_of_line] + injection + content[end_of_line:]

# 2. Update Jerry
jerry_block = r'(\[node name="PersonJerry".*?\n(?:.+?\n)*?)\n'
# We want to replace Jerry's block with added properties
def jerry_repl(m):
    block = m.group(1)
    if 'active_start_hour' not in block:
        block += 'active_start_hour = 8.0\nactive_end_hour = 18.0\n'
    return block + '\n'

content = re.sub(jerry_block, jerry_repl, content, count=1)

# 3. Add DayNightCycle and Campfire Nodes
if 'name="DayNightCycle"' not in content:
    content += '\n[node name="DayNightCycle" type="Node" parent="."]\n'
    content += 'script = ExtResource("2_x453x")\n'
    content += 'sun_light = NodePath("../DirectionalLight3D")\n'
    content += 'world_environment = NodePath("../WorldEnvironment")\n'

if 'name="Campfire"' not in content:
    content += '\n[node name="Campfire" parent="." instance=ExtResource("campfire_scene")]\n'
    content += 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 2.7, 5)\n'

with open('scenes/maps/playground.tscn', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated playground.tscn")

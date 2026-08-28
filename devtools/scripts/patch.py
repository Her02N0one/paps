import re

path = r"C:\Users\ayd3n\OneDrive\Desktop\PAPS\paps\entities\characters\player\player.tscn"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix ext_resource
content = content.replace('path="res://features/mobility/mobility_profile.gd"', 'path="res://features/mobility/grapple/grapple_profile.gd"')

# Fix ActorMovementComponent
content = re.sub(
    r'\[node name="ActorMovementComponent".*?mobility_profile = SubResource\("Resource_0d5hj"\)',
    r'[node name="ActorMovementComponent" type="Node" parent="." unique_id=2056943079 node_paths=PackedStringArray("body", "facing_reference")]\nscript = ExtResource("3_wxsjw")\nbody = NodePath("..")\nfacing_reference = NodePath("../Head")\n\n[node name="GrappleComponent" type="Node" parent="." unique_id=987654321 node_paths=PackedStringArray("movement_component")]\nscript = ExtResource("12_grapple")\nmovement_component = NodePath("../ActorMovementComponent")\nprofile = SubResource("Resource_0d5hj")',
    content,
    flags=re.DOTALL
)

# Fix GrappleVisualComponent
content = re.sub(
    r'\[node name="GrappleVisualComponent".*?movement_component = NodePath\("\.\./ActorMovementComponent"\)',
    r'[node name="GrappleVisualComponent" type="Node3D" parent="." unique_id=981240182 node_paths=PackedStringArray("grapple_component", "movement_component")]\nscript = ExtResource("11_gvc")\ngrapple_component = NodePath("../GrappleComponent")\nmovement_component = NodePath("../ActorMovementComponent")',
    content,
    flags=re.DOTALL
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Done")

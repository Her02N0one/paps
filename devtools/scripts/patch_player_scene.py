import re

with open("/home/ayden/Desktop/paps/content/characters/player/player.tscn", "r") as f:
    data = f.read()

# Add unique name to WorldModel if missing
if 'unique_name_in_owner=true' not in data and 'name="WorldModel"' in data:
    data = data.replace('name="WorldModel"', 'name="WorldModel" unique_name_in_owner=true')

with open("/home/ayden/Desktop/paps/content/characters/player/player.tscn", "w") as f:
    f.write(data)

print("Patched player.tscn successfully")

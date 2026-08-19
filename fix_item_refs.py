import os, re
count = 0
for root, _, files in os.walk('.'):
    if '.git' in root or '.godot' in root: continue
    for file in files:
        if file.endswith('.tscn') or file.endswith('.tres'):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                orig = content
                
                # Update script path
                content = content.replace('res://systems/inventory/data/item_data.gd', 'res://shared/items/item_definition.gd')
                # Update script_class
                content = content.replace('script_class="ItemData"', 'script_class="ItemDefinition"')
                
                # Remove UID from the item_definition.gd script reference so Godot generates a new one or finds it by path
                content = re.sub(r'uid="[^"]*"\s+path="res://shared/items/item_definition.gd"', 'path="res://shared/items/item_definition.gd"', content)
                
                if content != orig:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print('Fixed ' + filepath)
                    count += 1
            except Exception as e:
                pass
print('Fixed ' + str(count) + ' files.')

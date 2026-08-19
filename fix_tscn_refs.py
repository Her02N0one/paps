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
                
                # Replace old item paths with new ones
                content = content.replace('res://systems/inventory/items/', 'res://shared/items/')
                
                # Replace item_data property with item_definition
                content = re.sub(r'^item_data =', 'item_definition =', content, flags=re.MULTILINE)
                
                if content != orig:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print('Fixed ' + filepath)
                    count += 1
            except Exception as e:
                pass
print('Fixed ' + str(count) + ' files.')

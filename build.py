"""Build a self-contained Roblox Studio place using only Python's standard library."""
from pathlib import Path
import xml.etree.ElementTree as ET
import sys

ROOT = Path(__file__).resolve().parent
doc = ET.Element('roblox', {'version': '4'})
ET.SubElement(doc, 'External').text = 'null'
ET.SubElement(doc, 'External').text = 'nil'
counter = 0

def item(parent, cls, name, source=None):
    global counter
    counter += 1
    node = ET.SubElement(parent, 'Item', {'class': cls, 'referent': f'RBX{counter}'})
    props = ET.SubElement(node, 'Properties')
    ET.SubElement(props, 'string', {'name': 'Name'}).text = name
    if source:
        ET.SubElement(props, 'ProtectedString', {'name': 'Source'}).text = (ROOT / 'src' / source).read_text(encoding='utf-8')
    return node

workspace = item(doc, 'Workspace', 'Workspace')
ET.SubElement(workspace.find('Properties'), 'float', {'name': 'FallenPartsDestroyHeight'}).text = '-80'
shared = item(item(doc, 'ReplicatedStorage', 'ReplicatedStorage'), 'Folder', 'GodGame')
item(shared, 'ModuleScript', 'TargetingGeometry', 'TargetingGeometry.luau')
item(shared, 'ModuleScript', 'Config', 'Config.luau')
item(shared, 'ModuleScript', 'AbilityDefinitions', 'AbilityDefinitions.luau')
server = item(item(doc, 'ServerScriptService', 'ServerScriptService'), 'Folder', 'GodGame')
item(server, 'ModuleScript', 'World', 'World.luau')
item(server, 'ModuleScript', 'DamageService', 'DamageService.luau')
item(server, 'ModuleScript', 'AbilityService', 'AbilityService.luau')
item(server, 'Script', 'Main', 'Main.server.luau')
starter = item(doc, 'StarterPlayer', 'StarterPlayer')
scripts = item(starter, 'StarterPlayerScripts', 'StarterPlayerScripts')
item(scripts, 'ModuleScript', 'TargetingController', 'TargetingController.luau')
item(scripts, 'LocalScript', 'HUD', 'HUD.client.luau')
testing = '--test' in sys.argv
if testing:
    item(server, 'Script', 'GameplayTest', '../tests/Gameplay.server.luau')
    item(scripts, 'LocalScript', 'GameplayTest', '../tests/Gameplay.client.luau')
out = ROOT / ('Phase 2 Test.rbxlx' if testing else 'One Player Is God v03.rbxlx')
ET.indent(doc)
ET.ElementTree(doc).write(out, encoding='utf-8', xml_declaration=True)
loaded = ET.parse(out)
sources = loaded.findall('.//ProtectedString')
assert len(sources) == (11 if testing else 9)
assert loaded.find(".//float[@name='FallenPartsDestroyHeight']").text == '-80'
assert 'workspace.FallenPartsDestroyHeight =' not in (ROOT / 'src' / 'World.luau').read_text()
assert all(s.text and len(s.text) > 100 for s in sources)
expected = list((ROOT / 'src').glob('*.luau'))
if testing:
    expected += list((ROOT / 'tests').glob('*.luau'))
assert {s.text for s in sources} == {p.read_text(encoding='utf-8') for p in expected}
print(f'Built and verified {out.name}: {len(sources)} embedded scripts, {out.stat().st_size:,} bytes.')


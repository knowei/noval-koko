import sys
sys.stdout.reconfigure(encoding='utf-8')
p="lib/src/ui/reader/text_reader.dart"
t=open(p,encoding="utf-8").read()
pairs=[
("            style: TextStyle(\n              fontSize: prefs.fontSize,\n              height: prefs.lineHeight,\n              color: palette.text,\n            ),",
 "            style: ReaderFont.byId(prefs.fontId).apply(\n              fontSize: prefs.fontSize,\n              lineHeight: prefs.lineHeight,\n              color: palette.text,\n            ),"),
("              style: TextStyle(\n                fontSize: prefs.fontSize,\n                height: prefs.lineHeight,\n                color: palette.text,\n              ),",
 "              style: ReaderFont.byId(prefs.fontId).apply(\n                fontSize: prefs.fontSize,\n                lineHeight: prefs.lineHeight,\n                color: palette.text,\n              ),"),
]
for old,new in pairs:
    print("hits", t.count(old))
    t=t.replace(old,new)
open(p,"w",encoding="utf-8",newline="").write(t)

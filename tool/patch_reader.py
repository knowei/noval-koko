import io, sys
sys.stdout.reconfigure(encoding='utf-8')
p="lib/src/ui/reader/text_reader.dart"
t=open(p,encoding="utf-8").read()
pairs=[
("                    prefs.fontSize,\n                    prefs.lineHeight,\n                  );",
 "                    prefs.fontSize,\n                    prefs.lineHeight,\n                    prefs.fontId,\n                  );"),
("                style: TextStyle(\n                  fontSize: prefs.fontSize,\n                  height: prefs.lineHeight,\n                  color: palette.text,\n                ),",
 "                style: ReaderFont.byId(prefs.fontId).apply(\n                  fontSize: prefs.fontSize,\n                  lineHeight: prefs.lineHeight,\n                  color: palette.text,\n                ),"),
("                      style: TextStyle(\n                        fontSize: prefs.fontSize,\n                        height: prefs.lineHeight,\n                        color: palette.text,\n                      ),",
 "                      style: ReaderFont.byId(prefs.fontId).apply(\n                        fontSize: prefs.fontSize,\n                        lineHeight: prefs.lineHeight,\n                        color: palette.text,\n                      ),"),
]
for old,new in pairs:
    n=t.count(old)
    print("hits", n, "|", old.strip().split("\n")[0][:40])
    t=t.replace(old,new)
open(p,"w",encoding="utf-8",newline="").write(t)

import sys
sys.stdout.reconfigure(encoding='utf-8')
p="lib/src/ui/reader/text_reader.dart"
t=open(p,encoding="utf-8").read()
anchor="                    const SizedBox(height: 8),\n                    const Text('翻页方式'),\n"
assert t.count(anchor)==1, t.count(anchor)
block = '''                    const SizedBox(height: 8),
                    const Text('字体'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: <Widget>[
                        for (final ReaderFont f in ReaderFont.all)
                          ChoiceChip(
                            label: Text(
                              f.label,
                              style: f.apply(fontSize: 14, lineHeight: 1.2),
                            ),
                            selected: p.fontId == f.id,
                            onSelected: (bool v) {
                              p.fontId = f.id;
                              setSheet(() {});
                              state.updatePrefs(p);
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('翻页方式'),
'''
t=t.replace(anchor, block)
open(p,"w",encoding="utf-8",newline="").write(t)
print("ok")

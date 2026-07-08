DOC="/mnt/c/Users/m352395/Downloads/2DGS_Stereotactic_MICCAI_LNCS.docx"
OUT="/mnt/c/Users/m352395/Downloads/paper_extract.md"
if command -v pandoc >/dev/null 2>&1; then
  echo "using pandoc"
  pandoc "$DOC" -t markdown -o "$OUT"
else
  echo "pandoc not found -> python-docx"
  PY="$HOME/miniconda3/envs/facescan/bin/python"
  "$PY" -c "import docx" 2>/dev/null || "$PY" -m pip install -q python-docx
  "$PY" - "$DOC" "$OUT" <<'PYEOF'
import sys, docx
d = docx.Document(sys.argv[1])
lines = []
for p in d.paragraphs:
    t = p.text.rstrip()
    if t:
        sty = (p.style.name or '')
        if sty.lower().startswith('heading') or sty.lower().startswith('title'):
            lines.append('\n## ' + t)
        else:
            lines.append(t)
for i, tbl in enumerate(d.tables):
    lines.append('\n[TABLE %d]' % i)
    for row in tbl.rows:
        lines.append(' | '.join(c.text.strip() for c in row.cells))
open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(lines))
PYEOF
fi
echo "--- size ---"
wc -l "$OUT"

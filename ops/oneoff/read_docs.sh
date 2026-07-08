#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
pip install -q python-docx 2>&1 | tail -1
python - <<'PY'
from docx import Document
for path, name in [
    ('/mnt/c/Users/M352395/Documents/Claude/Projects/2DGS Paper/Experiment_Plans_PaperA_and_PaperB.docx', 'PLAN'),
    ('/mnt/c/Users/M352395/Documents/Claude/Projects/2DGS Paper/2DGS_Stereotactic_MICCAI_LNCS.docx', 'PAPER'),
]:
    print(f"\n=========== {name} ===========")
    d = Document(path)
    for p in d.paragraphs:
        t = p.text.strip()
        if t:
            style = p.style.name if p.style else ''
            prefix = '## ' if 'Heading' in style else ''
            print(prefix + t)
    for i, tb in enumerate(d.tables):
        print(f"--- TABLE {i} ---")
        for row in tb.rows:
            print(' | '.join(c.text.strip().replace('\n',' ') for c in row.cells))
PY

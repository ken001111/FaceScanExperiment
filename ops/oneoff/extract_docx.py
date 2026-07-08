import sys, glob, os
path = "/mnt/c/Users/M352395/OneDrive - Mayo Clinic/PrecisionSurgery/2DGS/2DGS_Stereotactic_MICCAI_LNCS.docx"
if not os.path.exists(path):
    print("NOT FOUND at:", path)
    # try to locate it
    for c in glob.glob("/mnt/c/Users/M352395/OneDrive*/**/2DGS_Stereotactic*.docx", recursive=True):
        print("found:", c)
    sys.exit(1)
try:
    import docx  # python-docx
except ImportError:
    os.system(sys.executable + " -m pip install -q python-docx")
    import docx
d = docx.Document(path)

def iter_block_items(parent):
    from docx.document import Document as _Doc
    from docx.oxml.table import CT_Tbl
    from docx.oxml.text.paragraph import CT_P
    from docx.table import Table
    from docx.text.paragraph import Paragraph
    body = parent.element.body
    for child in body.iterchildren():
        if isinstance(child, CT_P):
            yield Paragraph(child, parent)
        elif isinstance(child, CT_Tbl):
            yield Table(child, parent)

out = []
for blk in iter_block_items(d):
    from docx.table import Table
    if isinstance(blk, Table):
        out.append("\n[TABLE]")
        for row in blk.rows:
            out.append(" | ".join(c.text.strip() for c in row.cells))
        out.append("[/TABLE]\n")
    else:
        t = blk.text.strip()
        if t:
            sty = blk.style.name if blk.style else ""
            prefix = f"## " if sty.startswith("Heading") else ""
            out.append(prefix + t)
print("\n".join(out))

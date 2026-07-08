sec = open('/tmp/main_readme_section.md', encoding='utf-8').read()
p = 'README.md'
s = open(p, encoding='utf-8').read()
marker = "## What's in this folder"
if 'Run locally (RTX GPU' in s:
    print('main README already has the local section')
elif marker in s:
    open(p, 'w', encoding='utf-8').write(s.replace(marker, sec + marker, 1))
    print('inserted local section before the folder marker')
else:
    open(p, 'a', encoding='utf-8').write('\n' + sec)
    print('appended local section to end of README')

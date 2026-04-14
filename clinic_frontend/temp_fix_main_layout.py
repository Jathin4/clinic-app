from pathlib import Path
p = Path(r"E:\Flutter Project\clinic_frontend\lib\screens\main_layout.dart")
text = p.read_text()
start = text.find('  Widget _buildNavItem(')
print('start', start)
if start != -1:
    text = text[:start] + '}' + '\n'
    p.write_text(text)
    print('removed helper block')
else:
    print('no helper block found')

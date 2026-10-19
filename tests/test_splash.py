"""Static public-playtest entry, privacy and delivery contracts."""
from pathlib import Path
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[1]
class Page(HTMLParser):
    def __init__(self):
        super().__init__(); self.tags=[]
    def handle_starttag(self,tag,attrs):
        self.tags.append((tag,dict(attrs)))
page=ROOT/"docs/index.html"
assert page.exists(), "Public playtest entry missing"
text=page.read_text(); dom=Page(); dom.feed(text)
assert ('html',{'lang':'en'}) in dom.tags
assert any(t=='meta' and a.get('name')=='viewport' for t,a in dom.tags)
links=[a for t,a in dom.tags if t=='a']
assert any(a.get('class')=='download' and a.get('href')=='https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.1/NULL-CHOIR-0.2.3-alpha.1-Apple-Silicon.zip' for a in links)
assert '<title>NULL CHOIR — Mac alpha</title>' in text
assert 'Download Mac alpha' in text and 'Alpha checkpoint, not a finished release' in text
assert 'Expect bugs, hitches and balance changes.' in text
download=next(a['href'] for a in links if a.get('class')=='download')
assert 'suno' not in download.lower() and '/v0.2.3-alpha.1/' in download
assert 'Full campaign and 120 FPS performance are not yet verified.' in text
assert any(a.get('class')=='skip' and a.get('href')=='#main' for a in links)
assert not any(t in ['script','iframe','video','audio'] for t,a in dom.tags)
assert 'Developer ID-signed and Apple-notarized' in text
assert 'not Apple Developer ID-signed or notarized' not in text
assert 'Illustrated key art' in text and 'not a gameplay screenshot' in text
assert 'five minutes' in text and 'six weapon slots' in text
assert '/Users/' not in text and 'whatsapp.net' not in text
css=(ROOT/'docs/site-assets/splash.css').read_text()
assert ':focus-visible' in css and 'max-width:760px' in css
assert (ROOT/'docs/site-assets/arch.jpg').is_file()
assert (ROOT/'docs/site-assets/arch.jpg').stat().st_size<1_500_000
assert (ROOT/'LICENSE').read_bytes()==(ROOT/'game/licenses/NULL-CHOIR.txt').read_bytes()
workflow=(ROOT/'.github/workflows/site.yml').read_text()
assert "      - 'LICENSE'" in workflow and "      - 'game/licenses/NULL-CHOIR.txt'" in workflow, 'License-only changes must run parity checks'
assert '@media(max-width:480px)' in css and 'repeat(2,minmax(0,1fr))' in css, "Narrow mobile chapter grid requires two columns"
assert '.skip:hover{color:var(--ink)}' in css, "Hovered skip link contrast must remain readable"
print('PASS static splash entry, links, responsive/focus rules, asset budget, privacy and license parity')

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
assert any(a.get('class')=='download' and a.get('href')=='https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.2-suno.1' for a in links)
assert any(a.get('class')=='skip' and a.get('href')=='#main' for a in links)
assert not any(t in ['script','iframe','video','audio'] for t,a in dom.tags)
assert 'not Apple Developer ID-signed or notarized' in text
assert 'Illustrated key art' in text and 'not a gameplay screenshot' in text
assert 'five minutes' in text and 'six weapon slots' in text
assert '/Users/' not in text and 'whatsapp.net' not in text
css=(ROOT/'docs/site-assets/splash.css').read_text()
assert ':focus-visible' in css and 'max-width:760px' in css
assert (ROOT/'docs/site-assets/arch.jpg').is_file()
assert (ROOT/'docs/site-assets/arch.jpg').stat().st_size<1_500_000
assert (ROOT/'LICENSE').read_bytes()==(ROOT/'game/licenses/NULL-CHOIR.txt').read_bytes()
assert '@media(max-width:480px)' in css and 'repeat(2,minmax(0,1fr))' in css, "Narrow mobile chapter grid requires two columns"
assert '.skip:hover{color:var(--ink)}' in css, "Hovered skip link contrast must remain readable"
print('PASS static splash entry, links, responsive/focus rules, asset budget, privacy and license parity')

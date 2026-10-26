"""Current hosted playtest delivery plus retained static-page/privacy/license contracts.
GitHub Pages is retired. docs/ is historical material, NOT the current download host.
Preview04 must not become primary until its matching standalone artifact is verified.
"""
from pathlib import Path
from html.parser import HTMLParser
import re
ROOT=Path(__file__).resolve().parents[1]
SITE='https://null-choir.jaymoney.chatgpt.site'
DOWNLOAD='https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.4/NULL-CHOIR-0.2.3-alpha.4-major-features-preview-03-Apple-Silicon.zip'
SHA256='d953d8bbc8611a30fdeed46669c4f86bbf9a02157ce6eb64a20e637c71d2e247'
SOURCE='a99595a89f0bff0febc2e76bb6bf48053f6e823d'
readme=(ROOT/'README.md').read_text()
primary=readme.split('## Playtest download',1)[1].split('### ',1)[0]
assert re.search(r'\[Enter the NULL CHOIR download page\]\('+re.escape(SITE)+r'/?\)',primary), 'Current entry must be the existing ChatGPT Site'
assert 'ihearttokyo.github.io' not in primary, 'Retired Pages must not be the primary host'
assert re.search(r'\[Download[^\]]*Preview 03[^\]]*\]\('+re.escape(DOWNLOAD)+r'\)',primary), 'Keep the actual verified Preview03 primary until04verification'
assert SHA256 in primary and '204,674,603 bytes' in primary, 'Primary archive identity must match the verified03package'
assert SOURCE+'/game' in primary, 'Pin the source corresponding to the current verified package'
assert 'macOS 14' in primary and 'Apple Silicon' in primary
assert 'Developer ID-signed' in primary and 'Apple-notarized' in primary
assert 'Keep system security protections enabled.' in primary
assert 'preview' in primary.lower() and 'roadmap remains in progress' in primary
assert 'releases/tag/v0.2.3-alpha.4' in primary
for rollback in ['major-features-preview-02-Apple-Silicon.zip','chapter-preview-Apple-Silicon.zip','releases/tag/v0.2.3-alpha.2']:
    assert rollback in readme, 'Earlier verified rollback link retained: '+rollback
assert '__PREVIEW04_VERIFIED_' not in readme, 'Do not publish unfilled release-copy templates'
# Historical static page checks remain real; they no longer dictate README's current version.
class Page(HTMLParser):
    def __init__(self):super().__init__();self.tags=[]
    def handle_starttag(self,tag,attrs):self.tags.append((tag,dict(attrs)))
page=ROOT/'docs/index.html';assert page.is_file(), 'Retain historical public-page source'
text=page.read_text();dom=Page();dom.feed(text);links=[a for t,a in dom.tags if t=='a']
assert ('html',{'lang':'en'}) in dom.tags
assert any(t=='meta'and a.get('name')=='viewport'for t,a in dom.tags)
assert any(a.get('class')=='skip'and a.get('href')=='#main'for a in links)
assert len([t for t,a in dom.tags if t=='h1'])==1
assert not any(t in ['script','iframe','video','audio']for t,a in dom.tags)
assert 'Illustrated key art'in text and 'not a gameplay screenshot'in text
assert '© 2026 ihearttokyo'in text
for private in ['/Users/','whatsapp.net','Jared','Bland']:assert private not in text and private not in readme
css=(ROOT/'docs/site-assets/splash.css').read_text()
for rule in [':focus-visible','max-width:760px','@media(max-width:480px)','repeat(2,minmax(0,1fr))','.skip:hover{color:var(--ink)}','@media(max-width:1100px)']:
    assert rule in css, 'Retain actual historical responsive/focus rule: '+rule
asset=ROOT/'docs/site-assets/arch.jpg';assert asset.is_file()and asset.stat().st_size<1_500_000
assert (ROOT/'LICENSE').read_bytes()==(ROOT/'game/licenses/NULL-CHOIR.txt').read_bytes()
license_text=(ROOT/'LICENSE').read_text()
assert 'Copyright (c) 2026 ihearttokyo. All rights reserved.'in license_text
assert 'Third-party components remain governed by their own notices and licenses.'in license_text
assert 'Jared'not in license_text and 'Bland'not in license_text
workflow=(ROOT/'.github/workflows/site.yml').read_text()
assert 'pull_request:'in workflow and 'python3 -B tests/test_splash.py'in workflow
assert 'contents: read'in workflow and 'persist-credentials: false'in workflow
for path in ['LICENSE','game/licenses/NULL-CHOIR.txt','README.md','AGENTS.md','CHECKPOINT.md','tests/test_splash.py']:
    assert "      - '"+path+"'"in workflow, 'Relevant ownership/delivery changes must run this check'
for retired in ['deploy-pages','upload-pages-artifact','pages: write','id-token: write']:
    assert retired not in workflow, 'Retired GitHubPages deployment must not be reintroduced'
agents=(ROOT/'AGENTS.md').read_text()
assert 'matching tested standalone build'in agents and 'unverified build'in agents
print('PASS current ChatGPT Site/verified Preview03/rollback contract, historical page accessibility/privacy, license parity and non-deploying CI')

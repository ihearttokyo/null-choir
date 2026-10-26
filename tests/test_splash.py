"""Current hosted playtest delivery plus retained static-page/privacy/license contracts.
GitHub Pages is retired. docs/ is historical material, NOT the current download host.
Preview06.1 primary must be pinned to its matching verified standalone artifact.
"""
from pathlib import Path
from html.parser import HTMLParser
import re
ROOT=Path(__file__).resolve().parents[1]
SITE='https://null-choir.jaymoney.chatgpt.site'
DOWNLOAD='https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.4/NULL-CHOIR-0.2.3-alpha.4-major-features-preview-06-1-Apple-Silicon.zip'
SHA256='b65e081ea4d81c8a49728d8f465990c0aa2318b3d7a778084f4f6d699fc8a95a'
ZIP_BYTES='289931781'
ZIP_BYTES_DISPLAY='289,931,781'
PCK_SHA256='fc43c05bff0dabd9966f4ca3959fd9bd3cf5a87f92a544863058de36204e3b7c'
EXPORT_SOURCE='4a5268e5b80bf937f5e2b0a0f8ce4ac6363ced4a'
SOURCE='5e3032b0204809e994281ce7ede09f44424b6ee2'
SOURCE_TREE='088208959db676bfcb021df572a83ccc435e88d5'
ROLLBACK_DOWNLOAD='https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.4/NULL-CHOIR-0.2.3-alpha.4-major-features-preview-06-Apple-Silicon.zip'
ROLLBACK_SHA='79f8e2e3e90a5a987344bbbb97be4bd032e060db385ac2717ee172ee4df6ee16'
ROLLBACK_PCK='8d4b4c2dbf5d3289f081a666619fbb6a9d8c8cb4ec3cabddfdfe60484dfc6d60'
readme=(ROOT/'README.md').read_text()
release=(ROOT/'docs/releases/major-features-preview-06-1.md').read_text()
assert '__PREVIEW061_' not in readme+release+SHA256+ZIP_BYTES+ZIP_BYTES_DISPLAY+PCK_SHA256, 'Preview06.1 metadata is pending; do not publish an unfilled release-copy draft'
assert re.fullmatch(r'[0-9a-f]{64}',SHA256) and re.fullmatch(r'[0-9a-f]{64}',PCK_SHA256)
assert re.fullmatch(r'[0-9]+',ZIP_BYTES) and int(ZIP_BYTES)>0
assert ZIP_BYTES_DISPLAY==format(int(ZIP_BYTES),','), 'Archive display size must equal the exact verified byte count'
primary=readme.split('## Playtest download',1)[1].split('### ',1)[0]
assert re.search(r'\[Enter the NULL CHOIR download page\]\('+re.escape(SITE)+r'/?\)',primary), 'Current entry must be the existing ChatGPT Site'
assert 'ihearttokyo.github.io' not in primary, 'Retired Pages must not be the primary host'
assert re.search(r'\[Download[^\]]*Preview 06\.1[^\]]*\]\('+re.escape(DOWNLOAD)+r'\)',primary), 'Current primary must match the exact verified Preview06.1 package'
assert SHA256 in primary and ZIP_BYTES_DISPLAY+' bytes' in primary, 'Primary archive identity must match the verified06.1package'
assert EXPORT_SOURCE+'/game' in primary, 'Pin the exact export source'
assert SOURCE+'/game' in primary, 'Also pin the shipping-identical source successor'
assert 'macOS 14' in primary and 'Apple Silicon' in primary
assert 'Developer ID-signed' in primary and 'Apple-notarized' in primary
assert 'Keep system security protections enabled.' in primary
assert 'preview' in primary.lower() and 'Alpha 4 remains in progress' in primary
assert 'releases/tag/v0.2.3-alpha.4' in primary
assert ROLLBACK_DOWNLOAD in readme and ROLLBACK_SHA in readme and '289,894,541 bytes' in readme
assert '2ae7ab195417635a8cb7f181c977e9611e791af67f918d3bdc9d4422d81742ff' in readme
for rollback in ['major-features-preview-05-Apple-Silicon.zip','major-features-preview-04-Apple-Silicon.zip','major-features-preview-03-Apple-Silicon.zip','major-features-preview-02-Apple-Silicon.zip','chapter-preview-Apple-Silicon.zip','releases/tag/v0.2.3-alpha.2']:
    assert rollback in readme, 'Earlier verified rollback link retained: '+rollback
assert '__PREVIEW05_VERIFIED_' not in readme and '__PREVIEW06_' not in readme, 'Do not publish unfilled older release-copy templates'
assert '<!-- Local release-copy draft:' not in readme, 'Remove local-only marker after the public archive is verified'
preview05=readme.split('### What changed in Major Features Preview 05\n',1)[1].split('### What changed in Major Features Preview 04\n',1)[0]
for name in ['Impact Tool','Rivet Pistol','Scattergun','Sawtooth Repeater','Marrow Launcher','Choir Disruptor']:
    assert name in preview05, 'List every shipped weapon: '+name
assert 'gameplay statistics, firing cadence and existing HUD placement are unchanged' in preview05
assert 'not first-person screenshots' in preview05
assert 'Gate assemblies first ship in Preview 06, not in Preview 05.' in preview05
assert 'Neither Preview 05 nor Preview 06 is a completed Alpha 4 milestone.' in preview05
assert '960×200' in preview05 and 'idle pose' in preview05
preview06=readme.split('### What changed in Major Features Preview 06\n',1)[1].split('### What changed in Major Features Preview 05\n',1)[0]
for chapter in ['Intake','Foundry','Processional','Reliquary','Nursery','Ossuary','Inversion','Heart']:
    assert chapter in preview06, 'Identify each delivered threshold: '+chapter
for invariant in ['Blood and Ivory','collider','key requirements','route authority','save format','weapon balance','not native8K chapter masters','not a whole-map rebuild']:
    assert invariant in preview06, 'Keep accurate delivered scope: '+invariant
preview061=readme.split('### What changed in Major Features Preview 06.1\n',1)[1].split('### What changed in Major Features Preview 06\n',1)[0]
for feature in ['forward-aiming Rivet Pistol','idle','fire','recover','editable master','portable exporter','16-color','beetle','spring blob','antenna bird','owned playback time','measured Music-bus frequency bands','No Tyrian code or assets','weapon statistics and firing timing are unchanged','other five weapon designs','all eight living thresholds','pause','reduced motion','ownership']:
    assert feature.lower() in preview061.lower(), 'Keep accurate06.1 feature copy: '+feature
assert DOWNLOAD in release and SHA256 in release and ZIP_BYTES in release and PCK_SHA256 in release
assert EXPORT_SOURCE in release and SOURCE in release and SOURCE_TREE in release
assert ROLLBACK_DOWNLOAD in release and ROLLBACK_SHA in release and ROLLBACK_PCK in release
for limit in ['human physical-input','audible-listening','music-fit','sustained-FPS','whole-campaign','not Alpha 4 or full-goal completion']:
    assert limit in release, 'Retain actual qualification limit: '+limit
previous=(ROOT/'docs/releases/major-features-preview-06.md').read_text()
assert ROLLBACK_DOWNLOAD in previous and ROLLBACK_SHA in previous and '289,894,541' in previous
assert 'a126e4064e33190c7da8b42503c4b1a6c05b43b1' in previous and '6e798220c16594c56f8be84cd959764999037157' in previous
assert 'No new human physical-play' in previous and 'full-campaign claim' in previous
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
print('PASS current ChatGPT Site/verified Preview06.1/Preview06 rollback contract, historical page accessibility/privacy, license parity and non-deploying CI')

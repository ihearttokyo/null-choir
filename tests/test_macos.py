"""Real exported ZIP contract: Apple Silicon-only, offline, packaged notices."""
from pathlib import Path
import plistlib
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[1]
ZIP = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'builds/macos/NULL CHOIR-arm64.zip'

with tempfile.TemporaryDirectory(prefix='null-choir-check-', dir='/private/tmp') as tmp:
    subprocess.run(['ditto','-x','-k',str(ZIP),tmp],check=True)
    app, = Path(tmp).glob('*.app')
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'com.ihearttokyo.nullchoir'
    binary = app/'Contents/MacOS'/info['CFBundleExecutable']
    architecture = subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip()
    assert architecture == 'arm64', f'Apple Silicon-only required, got {architecture}'
    dependencies = subprocess.check_output(['otool','-L',str(binary)],text=True)
    assert '/opt/homebrew' not in dependencies and '/usr/local' not in dependencies
    subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
    result = subprocess.run([str(binary),'--headless','--audio-driver','CoreAudio','--','--verify-export'],capture_output=True,text=True,timeout=30)
    output = result.stdout+result.stderr
    assert result.returncode == 0 and 'PASS packaged' in output and 'ERROR:' not in output, output
    assert 'Foundry' in output, 'Packaged second-level load/MIDI/art acceptance missing'
    print(output.strip())
print('PASS exported ARM64 ZIP, strict ad-hoc signature, system-only dependencies and offline native title startup')

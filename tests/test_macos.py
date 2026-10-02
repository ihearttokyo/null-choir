"""Real exported ZIP contract: Apple Silicon-only, offline, packaged notices."""
from pathlib import Path
import os
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
    assert all(line.strip().split(' (',1)[0].startswith(('/System/Library/','/usr/lib/')) for line in dependencies.splitlines()[1:]), dependencies
    subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
    home = Path(tmp)/'validation-home'
    home.mkdir()
    env = {**os.environ, 'HOME':str(home), 'XDG_DATA_HOME':str(home/'data'), 'XDG_CONFIG_HOME':str(home/'config')}
    result = subprocess.run([str(binary),'--headless','--audio-driver','CoreAudio','--','--verify-export'],capture_output=True,text=True,timeout=30,env=env)
    output = result.stdout+result.stderr
    assert result.returncode == 0 and 'PASS packaged' in output and 'ERROR:' not in output, output
    assert 'Foundry' in output, 'Packaged second-level load/MIDI/art acceptance missing'
    assert 'Processional' in output, 'Packaged third-level/caster/scattergun acceptance missing (intended RED)'
    assert 'PASS packaged title, start, fire, pause, checkpoint restoration, Foundry and Processional scene/art/live MIDI, scattergun/caster flight, MIDI source and notices' in output, 'Legacy packed workflow acceptance missing'
    assert 'PASS packaged full8 scenes/art/retained-bank/live MIDI: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart' in output, 'Full-eight packed scenes/art/live MIDI acceptance missing (intended RED)'
    assert 'PASS packaged late weapon pickups/fire/ammo: sawtooth_repeater,marrow_launcher,choir_disruptor; actor/boss imports: brute,guardian,summoner,nursery_warden,choir_avatar' in output, 'Actual packed late weapon/actor/boss acceptance missing'
    assert 'PASS packaged isolated userdata' in output, 'Validation must not use real campaign/preferences userdata'
    assert not any(message in output.lower() for message in ['error:', 'leaked', 'resources still in use', 'orphan']), output
    assert info['CFBundleShortVersionString'] == '0.2.0' and info['CFBundleVersion'] == '0.2.0', 'Current development app version required'
    print(output.strip())
print('PASS exported ARM64 ZIP, strict ad-hoc signature, system-only dependencies and offline native title startup')

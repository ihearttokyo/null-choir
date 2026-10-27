"""Real exported ZIP contract: Apple Silicon-only, offline, packaged notices."""
from pathlib import Path
import os
import importlib.util
import json
import plistlib
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[1]
_version_spec = importlib.util.spec_from_file_location('null_choir_validator_build_iterations', ROOT / 'tools/build_iterations.py')
_versions = importlib.util.module_from_spec(_version_spec)
_version_spec.loader.exec_module(_versions)


def build_identity(root=ROOT):
    """Same validated ledger/identity boundary as tools/build_macos.py."""
    return _versions.active_identity(json.loads((root / _versions.LEDGER).read_text()))


def selected_archive(arguments=None, root=ROOT, identity=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    if len(arguments) > 1:
        raise ValueError('Supply at most one explicit exported ZIP path')
    archive = Path(arguments[0]) if arguments else root / 'builds/macos' / (identity if identity is not None else build_identity(root))['archive_name']
    if not archive.is_file():
        raise FileNotFoundError('Selected exported ZIP does not exist: ' + str(archive))
    return archive


def require_build_identity(app, info, expected):
    fields = {'CFBundleName': expected['display_name'],
              'CFBundleShortVersionString': expected['version'],
              'CFBundleVersion': expected['cfbundle_version']}
    if app.name != expected['app_name'] or any(info.get(key) != value for key, value in fields.items()):
        raise AssertionError('Exported app identity must match the current validated development iteration')
    if info.get('CFBundleDisplayName', expected['display_name']) != expected['display_name']:
        raise AssertionError('Exported display name must match the current development iteration')

def require_recorded_audio_receipts(output):
    for receipt in ('PASS packaged title, start, fire, pause, checkpoint restoration, Foundry and Processional scene/art/recorded PCM, scattergun/caster flight, retained MIDI sources and notices', 'PASS packaged full8 scenes/art/recorded PCM: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart', 'PASS packaged retained MIDI sources: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart'):
        if receipt not in output:
            raise AssertionError("Packed audio receipt missing: " + receipt)


def main():
    expected = build_identity()
    ZIP = selected_archive(identity=expected)

    with tempfile.TemporaryDirectory(prefix='null-choir-check-', dir='/private/tmp') as tmp:
        subprocess.run(['ditto','-x','-k',str(ZIP),tmp],check=True)
        app, = Path(tmp).glob('*.app')
        info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
        require_build_identity(app, info, expected)
        assert info['CFBundleIdentifier'] == 'com.ihearttokyo.nullchoir'
        assert info.get('LSMinimumSystemVersionByArchitecture', {}).get('arm64') == '14.00', 'Native Metal baking requires the macOS14 arm64 target'
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
        require_recorded_audio_receipts(output)
        assert 'PASS packaged late weapon pickups/fire/ammo: sawtooth_repeater,marrow_launcher,choir_disruptor; actor/boss imports: brute,guardian,summoner,nursery_warden,choir_avatar' in output, 'Actual packed late weapon/actor/boss acceptance missing'
        assert 'PASS packaged native Metal shader caches' in output, 'Actual packed native Metal cache acceptance missing'
        assert 'PASS packaged isolated userdata' in output, 'Validation must not use real campaign/preferences userdata'
        assert not any(message in output.lower() for message in ['error:', 'leaked', 'resources still in use', 'orphan']), output
        print(output.strip())
    print('PASS exported ARM64 ZIP, strict code signature, system-only dependencies and offline native title startup')


if __name__ == '__main__':
    main()

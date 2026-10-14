"""Check truthful packed-audio receipts without launching an app or using user data."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("macos_contract", ROOT / "tests/test_macos.py")
macos = importlib.util.module_from_spec(spec)
spec.loader.exec_module(macos)
RECEIPTS = (
    "PASS packaged title, start, fire, pause, checkpoint restoration, Foundry and Processional scene/art/recorded PCM, scattergun/caster flight, retained MIDI sources and notices",
    "PASS packaged full8 scenes/art/recorded PCM: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart",
    "PASS packaged retained MIDI sources: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart",
)

class RecordedAudioReceipts(unittest.TestCase):
    def test_new_receipts_are_accepted(self):
        macos.require_recorded_audio_receipts("\n".join(RECEIPTS))

    def test_each_missing_receipt_is_rejected(self):
        for missing in RECEIPTS:
            with self.subTest(missing=missing), self.assertRaises(AssertionError):
                macos.require_recorded_audio_receipts("\n".join(r for r in RECEIPTS if r != missing))

    def test_legacy_labels_do_not_certify_recordings(self):
        with self.assertRaises(AssertionError):
            macos.require_recorded_audio_receipts("PASS packaged title, start, fire, pause, checkpoint restoration, Foundry and Processional scene/art/live MIDI, scattergun/caster flight, MIDI source and notices\nPASS packaged full8 scenes/art/retained-bank/live MIDI: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart")

    def test_runtime_prints_the_required_receipts(self):
        source = (ROOT / "game/scripts/main.gd").read_text().split("func _verify_export()", 1)[1]
        printed = set(re.findall(r'print\("([^"\n]+)"\)', source))
        self.assertTrue(set(RECEIPTS) <= printed)

if __name__ == "__main__":
    unittest.main()

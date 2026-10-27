"""Focused actual-atlas and negative structural contracts; no native/Blender run.

Production completion remains a separate strict validator invocation; synthetic
registration metadata below is NOT a native run or production acceptance.
"""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import runpy
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

ROOT=Path(__file__).resolve().parents[1]
v=runpy.run_path(str(ROOT/'tools/rivet_forward_art_ledger.py'))
Error=v['ContractError']

def write(root,rel,data):
    p=root/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);return p

def encode(width,height,pixels):
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    scan=b''.join(b'\0'+pixels[y*width*4:(y+1)*width*4] for y in range(height))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b'')

class NativeRivetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.atlas=(ROOT/v['OUTPUT']).read_bytes()
        cls.doc=json.loads((ROOT/v['LEDGER']).read_text())
        # Historical v4 fixtures retain the exact d3ff Player, never current v5
        # without its qualified dependency packet.
        old=(ROOT/'source/art/rivet-forward-v5/provenance/player-before-v5.gd').read_bytes()
        assert hashlib.sha256(old).hexdigest()=='d3ff20a302f8ead0f6808683e6ccdd9a2b3f10f711b019fe9808a788faef7bff'
        cls.player=old.decode()

    def temporary(self):
        # Resolved temporary root avoids macOS /var -> /private/var aliases.
        t=tempfile.TemporaryDirectory(dir=str(Path(tempfile.gettempdir()).resolve()))
        self.addCleanup(t.cleanup)
        return Path(t.name)

    def validate_json_overlay(self, relative, mutate):
        """Mutate complete historical v4 evidence, not the current v5 packet.

        The actual current-v5 alias has its own full positive/foreign negative.
        Old metadata type checks must not revalidate its nine context images.
        """
        root=self.qualified_private_fixture()
        self.assertEqual(hashlib.sha256((root/'game/scripts/player.gd').read_bytes()).hexdigest(),
                         'd3ff20a302f8ead0f6808683e6ccdd9a2b3f10f711b019fe9808a788faef7bff')
        function=v['validate_ledger']
        original=function.__globals__['read_json']
        def altered(path):
            value=original(path)
            if path==root/relative:
                value=copy.deepcopy(value)
                mutate(value)
            return value
        with patch.dict(function.__globals__,{'read_json':altered}):
            return function(root)

    def test_schema_bool_and_float_are_not_integer_version(self):
        for bad in [True,1.0]:
            with self.subTest(value=bad),self.assertRaises(Error):
                self.validate_json_overlay(v['LEDGER'],lambda d:d.update(schema_version=bad))

    def test_output_byte_count_requires_exact_integer(self):
        with self.assertRaises(Error):
            self.validate_json_overlay(v['LEDGER'],lambda d:d['assets'][0]['output'].update(bytes=41941.0))

    def test_output_dimensions_require_exact_integers(self):
        with self.assertRaises(Error):
            self.validate_json_overlay(v['LEDGER'],lambda d:d['assets'][0]['output'].update(dimensions=[960.0,200.0]))

    def test_source_byte_count_requires_exact_integer(self):
        with self.assertRaises(Error):
            self.validate_json_overlay(v['LEDGER'],lambda d:d['assets'][0]['source'].update(bytes=219389.0))

    def test_frame_byte_count_requires_exact_integer(self):
        with self.assertRaises(Error):
            self.validate_json_overlay(v['FAMILY']+'registration.json',lambda d:d['frame_pngs'][0].update(bytes=float(d['frame_pngs'][0]['bytes'])))

    def test_hud_evidence_byte_count_requires_exact_integer(self):
        with self.assertRaises(Error):
            self.validate_json_overlay(v['FAMILY']+'qualification.json',lambda d:d['actual_hud_images'][0].update(bytes=float(d['actual_hud_images'][0]['bytes'])))

    def qualified_private_fixture(self, sidecar_mutator=lambda text:text):
        root=self.lineage_fixture()
        paths={r['path'] for r in self.doc['public_inputs']}
        paths.update(['game/scripts/player.gd','game/scripts/hud.gd',v['OUTPUT']+'.import',v['FAMILY']+'native-import.json'])
        for relative in paths:write(root,relative,self.player.encode() if relative=='game/scripts/player.gd' else (ROOT/relative).read_bytes())
        sidecar=root/(v['OUTPUT']+'.import')
        sidecar.write_text(sidecar_mutator(sidecar.read_text()))
        sidecar_sha=hashlib.sha256(sidecar.read_bytes()).hexdigest()
        import_path=root/(v['FAMILY']+'native-import.json')
        receipt=json.loads(import_path.read_text());receipt['sidecar_sha256']=sidecar_sha
        import_path.write_text(json.dumps(receipt))
        doc=copy.deepcopy(self.doc)
        doc['assets'][0]['import_sidecar']['sha256']=sidecar_sha
        doc['assets'][0]['native_import']['sha256']=hashlib.sha256(import_path.read_bytes()).hexdigest()
        write(root,v['LEDGER'],json.dumps(doc).encode())
        return root

    def test_full_qualified_private_fixture_passes(self):
        result=v['validate_ledger'](self.qualified_private_fixture())
        self.assertEqual(result['status'],'STRUCTURAL_SINGLE_NATIVE_RIVET_VALID')

    def test_active_sidecar_comments_and_packed_string_array(self):
        text=(ROOT/(v['OUTPUT']+'.import')).read_text()
        uid,imported=v['validate_import_sidecar'](text)
        text='; ignored heading\n'+text.replace('process/fix_alpha_border=false','process/fix_alpha_border=false ; active false')
        text=text.replace('dest_files=["'+imported+'"]','dest_files=PackedStringArray("'+imported+'")')
        self.assertEqual(v['validate_import_sidecar'](text),(uid,imported))

    def test_active_sidecar_comment_spoof_and_duplicate_keys_rejected(self):
        mutators=[
            lambda text:text.replace('process/fix_alpha_border=false','#process/fix_alpha_border=false\nprocess/fix_alpha_border=true'),
            lambda text:text+'\nprocess/fix_alpha_border=true\n',
            lambda text:text+'\n[params]\nprocess/fix_alpha_border=true\n',
            lambda text:text.replace('process/fix_alpha_border=false','').replace('[deps]','[deps]\nprocess/fix_alpha_border=false')]
        for index,mutate in enumerate(mutators):
            with self.subTest(case=index),self.assertRaises(Error):
                v['validate_ledger'](self.qualified_private_fixture(mutate))

    def test_actual_accepted_threepose_atlas(self):
        result=v['validate_atlas'](self.atlas)
        self.assertEqual(hashlib.sha256(self.atlas).hexdigest(),v['OUTPUT_SHA'])
        self.assertEqual(result['dimensions'],[960,200])
        self.assertEqual(len(set(result['pose_rgba8_sha256'])),3)
        self.assertEqual(result['rgba8_pixel_sha256'],self.doc['assets'][0]['output']['rgba8_pixel_sha256'])

    def test_tampered_output_rejected(self):
        with self.assertRaises(Error):v['validate_atlas'](self.atlas[:-1]+b'X')

    def test_wrong_dimensions_rejected(self):
        with self.assertRaisesRegex(Error,'dimensions'):
            v['validate_atlas'](encode(1,1,b'\0\0\0\xff'))

    def test_nonbinary_alpha_rejected_before_hash(self):
        dims,pixels=v['png_rgba'](self.atlas)
        pixels=bytearray(pixels);pixels[3]=128
        with self.assertRaisesRegex(Error,'alpha'):
            v['validate_atlas'](encode(*dims,bytes(pixels)))

    def test_tampered_source_rejected(self):
        with self.assertRaisesRegex(Error,'native source'):
            v['validate_source'](b'BLENDER-tampered-not-the-accepted-source')

    def test_actual_source_when_present_or_explicit_missing_block(self):
        source=ROOT/v['SOURCE']
        if source.is_file():
            v['validate_source'](source.read_bytes())
        else:
            with self.assertRaisesRegex(Error,'public file missing'):
                v['checked'](ROOT,self.doc['assets'][0]['source'],v['SOURCE'],v['SOURCE_SHA'])

    def test_missing_output_rejected(self):
        with self.assertRaisesRegex(Error,'public file missing'):
            v['checked'](self.temporary(),self.doc['assets'][0]['output'],v['OUTPUT'],v['OUTPUT_SHA'])

    def test_pending_or_forged_reference_hash_rejected(self):
        for digest in [None,'PENDING','0'*64]:
            row={'path':v['SOURCE'],'sha256':digest}
            with self.subTest(digest=digest),self.assertRaises(Error):
                v['checked'](self.temporary(),row,v['SOURCE'],v['SOURCE_SHA'])

    def test_unknown_missing_duplicate_owner_and_wrong_index_rejected(self):
        for mutate in [lambda d:d.update(assets=[]),
                       lambda d:d['assets'].append(copy.deepcopy(d['assets'][0])),
                       lambda d:d['assets'][0].update(id='unknown'),
                       lambda d:d['assets'][0].update(weapon_index=0),
                       lambda d:d['assets'][0].update(weapon_index=True)]:
            doc=copy.deepcopy(self.doc);mutate(doc);root=self.temporary()
            write(root,v['LEDGER'],json.dumps(doc).encode())
            with self.assertRaises(Error):v['validate_ledger'](root)

    def test_current_qualified_v5_alias_and_foreign_URI_negative(self):
        current=(ROOT/'game/scripts/player.gd').read_bytes()
        self.assertEqual(hashlib.sha256(current).hexdigest(),'0a1c0959513a068d13a0ac0f3b5a6ad3dca2064155028a568155e11b8f83a5a7')
        self.assertEqual(v['validate_pistol_player_compatibility'](ROOT,current),self.player.encode())
        foreign=current.replace(b'native-v5/rivet_pistol',b'native-v6/rivet_pistol')
        with self.assertRaises(ValueError):v['validate_pistol_player_compatibility'](ROOT,foreign)

    def test_only_index1_runtime_alternate(self):
        v['validate_player'](self.player)
        old=self.player.replace('native-v4/rivet_pistol','painted-v3/rivet_pistol')
        v['validate_player'](old,native=False)
        for bad in [self.player.replace('native-v4/rivet_pistol','native-v4/unknown'),
                    self.player.replace('painted-v3/scattergun','native-v4/rivet_pistol'),
                    self.player.replace('"asset":"native-v4/rivet_pistol"','"asset":"painted-v3/scattergun"',1)]:
            with self.assertRaises(Error):v['validate_player'](bad)

    def test_bad_registration_landmarks_pose_order_and_hash_rejected(self):
        pixels=v['validate_atlas'](self.atlas)
        reg={'schema_version':1,'kind':'native-forward-rivet-registration','source_sha256':v['SOURCE_SHA'],
             'atlas_sha256':v['OUTPUT_SHA'],'runtime_contract':copy.deepcopy(v['CONTRACT']),
             'pose_rgba8_sha256':pixels['pose_rgba8_sha256']}
        v['validate_registration'](reg,pixels) # Synthetic schema only, not native evidence.
        for mutate in [lambda d:d['runtime_contract'].update(origin_px=[0,0]),
                       lambda d:d['runtime_contract'].update(muzzle_px=[141,62]),
                       lambda d:d['runtime_contract'].update(neutral_vanishing_point_px=[140,38]),
                       lambda d:d['runtime_contract'].update(frames=['fire','idle','recover']),
                       lambda d:d.update(source_sha256='0'*64),
                       lambda d:d['runtime_contract'].update(columns=3.0),
                       lambda d:d['pose_rgba8_sha256'].reverse()]:
            bad=copy.deepcopy(reg);mutate(bad)
            with self.assertRaisesRegex(Error,'registration'):v['validate_registration'](bad,pixels)

    def test_unowned_png_rejected_no_directory_skip(self):
        root=self.temporary();write(root,v['OUTPUT'],self.atlas)
        v['check_native_directory'](root)
        write(root,'game/assets/art/weapons/native-v4/unowned.png',self.atlas)
        with self.assertRaisesRegex(Error,'unowned PNG'):v['check_native_directory'](root)

    def lineage_fixture(self):
        root=self.temporary()
        paths={row['path'] for row in v['LINEAGE'].values()}
        raster=json.loads((ROOT/'source/art/weapon-raster-v3.json').read_text())
        paths.update(row['output']['path'] for row in raster['assets'])
        for rel in paths:write(root,rel,(ROOT/rel).read_bytes())
        return root

    def test_actual_all_six_rasters_and119_catalog_retained(self):
        root=self.lineage_fixture()
        result=v['validate_lineage'](root,copy.deepcopy(v['LINEAGE']))
        self.assertEqual(len(result['assets']),6)

    def test_old_raster_output_retention_is_mandatory(self):
        root=self.lineage_fixture()
        p=root/v['LINEAGE']['retained_painted_output']['path'];p.write_bytes(p.read_bytes()+b'tampered')
        with self.assertRaisesRegex(Error,'hash mismatch'):v['validate_lineage'](root,v['LINEAGE'])

    def test_missing_or_wrong_original_lineage_rejected(self):
        for bad in [{}, {k:val for k,val in v['LINEAGE'].items() if k!='original_native_source'}]:
            with self.assertRaisesRegex(Error,'lineage'):v['validate_lineage'](self.temporary(),bad)

    def test_actual26_public_inputs_bound(self):
        v['validate_public_inputs'](ROOT,self.doc['public_inputs'])

    def test_public_input_owner_set_not_extensible(self):
        for rows in [[],self.doc['public_inputs'][:-1],self.doc['public_inputs']+[self.doc['public_inputs'][0]]]:
            with self.assertRaises(Error):v['validate_public_inputs'](ROOT,rows)

    def test_private_or_noncanonical_references_rejected(self):
        for path in ['/Users/private/source.blend','source/../secret.blend','source//file.blend']:
            with self.assertRaises(Error):v['safe_rel'](self.temporary(),path,label='negative')

if __name__=='__main__':unittest.main()

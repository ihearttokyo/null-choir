"""Real private resident files, synthetic telemetry/PNG; no engine or HTTP."""
import hashlib
import json
import os
from pathlib import Path
import stat
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from tools import playtest_protocol as p
from tools import playtest_report as report
from tests.test_playtest_protocol import observation
from tests.test_playtest_capture import VALID_PNG
from tests.test_playtest_recorder import PNG


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='null-choir-report-')
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve()/'run'
        j=self.journal=p.Journal(self.root,'run-01','a'*64,0)
        self.addCleanup(j.close)
        state=observation(frame=1)
        j.record('state',state,0.01)
        self.command(state,'fire',0.02)
        after=observation(frame=2,action_sequence=1,pose=[3.5,0,2],yaw=15,
                          ammo=[0,27,0,0,0,0],health=68)
        j.capture('frame-0000.png',VALID_PNG,after,0.1)
        self.command(after,'wait',0.11)
        j.record('stop',after,0.3)
        j.close()

    def command(self,state,action,now):
        row=self.journal._row('command_attempt',state,now)
        row.update(action=action,model=p.MODEL,usage={'input_tokens':10,'output_tokens':2},
                   issued_frame=state['frame'],expires_monotonic=now+0.2,duration_seconds=0.15)
        self.journal._append(row)

    def run_report(self,**changes):
        return report.report_run(self.root,run_id='run-01',
                                  build_sha256=changes.get('build_sha256','a'*64))

    def rows(self):
        return [json.loads(line) for line in (self.root/'index.jsonl').read_text().splitlines()]

    def rewrite(self,rows):
        (self.root/'index.jsonl').write_text(''.join(json.dumps(x)+'\n' for x in rows))

    def test_sample_coverage_ammo_actions_and_missing_capture_without_overclaim(self):
        before={path.name:path.read_bytes() for path in self.root.iterdir()}
        result=self.run_report()
        self.assertEqual(result['run_id'],'run-01')
        self.assertEqual(result['captures'][0]['sha256'],hashlib.sha256(VALID_PNG).hexdigest())
        self.assertEqual(result['capture_count'],1)
        self.assertEqual(result['command_attempts'],{'fire':1,'wait':1})
        self.assertEqual(result['usage_tokens'],{'input_tokens':20,'output_tokens':4})
        self.assertEqual(result['unique_pose_bins'],2)
        self.assertEqual(result['sampled_pose_displacement_world_units'],2)
        self.assertEqual(result['sampled_absolute_yaw_change_degrees'],15)
        self.assertEqual(result['observed_ammo_decreases'],[0,10,0,0,0,0])
        self.assertEqual(result['observed_health_decreases'],5)
        self.assertTrue(result['journal_has_stop'])
        self.assertEqual(result['missing_post_action_frames'],[
            {'level_id':11,'player_id':22,'issued_sequence':1,'expected_sequence':2,'action':'wait'}])
        self.assertEqual(result['evidence'],'local journal and PNG integrity only')
        for unsupported in ('campaign_complete','coverage_percent','actual_cost_usd','native_input_verified'):
            self.assertNotIn(unsupported,result)
        self.assertEqual(before,{path.name:path.read_bytes() for path in self.root.iterdir()})

    def test_identity_and_global_sequence_frame_time_guards(self):
        original=self.rows()
        with self.assertRaises(report.ReportError): self.run_report(build_sha256='b'*64)
        for field,value in (('sequence',999),('frame',0),('monotonic',-1),
                            ('action_sequence',False),('run_id','wrong-run')):
            rows=json.loads(json.dumps(original)); rows[-1][field]=value; self.rewrite(rows)
            with self.subTest(field=field), self.assertRaises(report.ReportError): self.run_report()
        self.rewrite(original)

    def test_capture_size_hash_png_and_name_guards(self):
        original=self.rows()
        frame=next(x for x in original if x['kind']=='frame')
        for field,value in (('sha256','b'*64),('size_bytes',len(VALID_PNG)+1),('capture','../canary.png')):
            rows=json.loads(json.dumps(original)); next(x for x in rows if x['kind']=='frame')[field]=value
            self.rewrite(rows)
            with self.subTest(field=field), self.assertRaises(report.ReportError): self.run_report()
        self.rewrite(original)
        (self.root/'frame-0000.png').write_bytes(PNG)
        frame['sha256']=hashlib.sha256(PNG).hexdigest(); frame['size_bytes']=len(PNG);self.rewrite(original)
        with self.assertRaises(report.ReportError): self.run_report()

    def test_private_regular_root_index_and_capture_required(self):
        for path,good in ((self.root,0o700),(self.root/'index.jsonl',0o600),(self.root/'frame-0000.png',0o600)):
            path.chmod(0o755 if path.is_dir() else 0o644)
            with self.subTest(path=path.name), self.assertRaises(report.ReportError): self.run_report()
            path.chmod(good)

    def test_symlink_and_hardlink_targets_preserved(self):
        link=self.root.parent/'linked-run'; link.symlink_to(self.root,target_is_directory=True)
        with self.assertRaises(report.ReportError): report.report_run(link,run_id='run-01',build_sha256='a'*64)
        frame=self.root/'frame-0000.png'; target=self.root.parent/'canary.png'
        target.write_bytes(VALID_PNG); target.chmod(0o600); frame.unlink(); frame.symlink_to(target)
        with self.assertRaises(report.ReportError): self.run_report()
        self.assertEqual(target.read_bytes(),VALID_PNG)
        frame.unlink(); os.link(target,frame)
        with self.assertRaises(report.ReportError): self.run_report()
        self.assertEqual(target.read_bytes(),VALID_PNG)

    def test_fifo_rejected_without_waiting_for_writer(self):
        index=self.root/'index.jsonl'; index.unlink(); os.mkfifo(index,0o600)
        with self.assertRaises(report.ReportError): self.run_report()

    def test_dataless_metadata_rejected_before_any_content_read(self):
        fstat=os.fstat
        def dataless(fd):
            info=fstat(fd)
            fields={k:getattr(info,k) for k in ('st_mode','st_uid','st_nlink','st_size','st_dev','st_ino','st_mtime_ns','st_ctime_ns')}
            return SimpleNamespace(**fields,st_flags=getattr(stat,'SF_DATALESS',0x40000000))
        with patch.object(report.os,'fstat',side_effect=dataless), \
             patch.object(report.os,'read',wraps=os.read) as read:
            with self.assertRaises(report.ReportError): self.run_report()
            read.assert_not_called()

    def test_duplicate_unknown_fields_and_nonfinite_values_are_rejected(self):
        original=self.rows()
        index=self.root/'index.jsonl'
        index.write_text(index.read_text().replace('"version":1','"version":1,"version":1',1))
        with self.assertRaises(report.ReportError): self.run_report()
        self.rewrite(original)
        for field,value in (('action','unapproved'),('model','unapproved'),('duration_seconds',float('nan'))):
            rows=json.loads(json.dumps(original)); next(x for x in rows if x['kind']=='command_attempt')[field]=value
            self.rewrite(rows)
            with self.subTest(field=field), self.assertRaises(report.ReportError): self.run_report()
        self.rewrite(original); rows=original; rows[1]['state']['private_source']='must not escape';self.rewrite(rows)
        with self.assertRaises(report.ReportError) as raised: self.run_report()
        self.assertNotIn('must not escape',str(raised.exception))
        self.assertNotIn(str(self.root),str(raised.exception))

    def test_row_byte_and_count_caps_are_preflighted(self):
        for name,bound in (('MAX_ROW_BYTES',8),('MAX_ROWS',2),('MAX_INDEX_BYTES',8)):
            with patch.object(report,name,bound),self.subTest(name=name),self.assertRaises(report.ReportError):
                self.run_report()

    def test_scene_reset_does_not_count_teleport_or_cross_scene_ammo(self):
        rows=self.rows(); row=rows[-1]
        row['level_id']=33;row['player_id']=44;row['frame']=3;row['state']['pose']=[100,0,100]
        row['state']['ammo']=[0,0,0,0,0,0];self.rewrite(rows)
        result=self.run_report()
        self.assertEqual(result['sampled_pose_displacement_world_units'],2)
        self.assertEqual(result['observed_ammo_decreases'],[0,10,0,0,0,0])
        self.assertEqual(result['unique_pose_bins'],3)

    def test_open_or_interrupted_journal_has_explicit_missing_stop_diagnostic(self):
        self.rewrite(self.rows()[:-1]);result=self.run_report()
        self.assertFalse(result['journal_has_stop'])
        self.assertIn('no_local_stop_record',result['diagnostics'])


    def test_total_budget_preflights_index_even_without_captures(self):
        self.rewrite(self.rows()[:1])
        size=(self.root/'index.jsonl').stat().st_size
        with patch.object(report.p,'MAX_BYTES',size-1), \
             patch.object(report.os,'read',wraps=os.read) as read:
            with self.assertRaises(report.ReportError): self.run_report()
            read.assert_not_called()

    def test_clean_contact_schema_is_preserved_without_raw_provenance(self):
        result=self.run_report()
        text=json.dumps(result)
        for field in ('sensitivity','contacts','obstacles','objective','visible'):
            self.assertNotIn('"'+field+'"',text)
        original=self.rows()
        for field,value in (('sensitivity',1),('visible',True)):
            rows=json.loads(json.dumps(original))
            if field=='visible': rows[1]['state']['contacts'][0][field]=value
            else: rows[1]['state'][field]=value
            self.rewrite(rows)
            with self.subTest(field=field),self.assertRaises(report.ReportError): self.run_report()

    def test_command_lease_usage_and_clean_numeric_bounds(self):
        original=self.rows()
        for field,value in (('expires_monotonic',0.021),('duration_seconds',0),
                            ('issued_frame',999),('usage',{'input_tokens':True,'output_tokens':2}),
                            ('usage',{'input_tokens':64000,'output_tokens':1}),
                            ('usage',{'input_tokens':10,'output_tokens':2,'provider_body':'private'})):
            rows=json.loads(json.dumps(original))
            next(x for x in rows if x['kind']=='command_attempt')[field]=value
            self.rewrite(rows)
            with self.subTest(field=field,value=value),self.assertRaises(report.ReportError): self.run_report()
        for field,value in (('phase','unknown'),('health',True),('armor',201),('ammo',[0]),
                            ('weapon',6),('pose',[0,0,100001]),('yaw',181),('objective','private')):
            rows=json.loads(json.dumps(original));rows[1]['state'][field]=value;self.rewrite(rows)
            with self.subTest(field=field),self.assertRaises(report.ReportError): self.run_report()

    def test_duplicate_capture_and_command_sequence_are_rejected(self):
        original=self.rows()
        rows=json.loads(json.dumps(original));row=dict(rows[3]);row['sequence']=4
        rows.insert(4,row)
        for i,row in enumerate(rows): row['sequence']=i
        self.rewrite(rows)
        with self.assertRaises(report.ReportError): self.run_report()
        rows=json.loads(json.dumps(original));rows[4]['action_sequence']=0
        rows[3]['action_sequence']=0;self.rewrite(rows)
        with self.assertRaises(report.ReportError): self.run_report()

    def test_capture_and_total_caps_preflight_without_capture_reads(self):
        size=(self.root/'index.jsonl').stat().st_size
        for namespace,name,bound in ((report.p,'MAX_CAPTURES',0),
                                     (report.capture,'MAX_CAPTURE_BYTES',len(VALID_PNG)-1),
                                     (report.p,'MAX_BYTES',size+len(VALID_PNG)-1)):
            with patch.object(namespace,name,bound), \
                 patch.object(report.os,'open',wraps=os.open) as opened:
                with self.subTest(name=name),self.assertRaises(report.ReportError): self.run_report()
                self.assertFalse(any(call.args[0]=='frame-0000.png' for call in opened.call_args_list))

    def test_dataless_capture_stat_rejected_before_open(self):
        real_stat=os.stat
        def placeholder(path,*args,**kwargs):
            info=real_stat(path,*args,**kwargs)
            if path!='frame-0000.png': return info
            fields={k:getattr(info,k) for k in ('st_mode','st_uid','st_nlink','st_size','st_dev','st_ino','st_mtime_ns','st_ctime_ns')}
            return SimpleNamespace(**fields,st_flags=stat.SF_DATALESS)
        with patch.object(report.os,'stat',side_effect=placeholder), \
             patch.object(report.os,'open',wraps=os.open) as opened:
            with self.assertRaises(report.ReportError): self.run_report()
            self.assertFalse(any(call.args[0]=='frame-0000.png' for call in opened.call_args_list))

    def test_symlink_ancestor_foreign_uid_and_capture_fifo_are_rejected(self):
        link=self.root.parent/'linked-parent';link.symlink_to(self.root.parent,target_is_directory=True)
        with self.assertRaises(report.ReportError):
            report.report_run(link/'run',run_id='run-01',build_sha256='a'*64)
        with patch.object(report.os,'getuid',return_value=os.getuid()+1):
            with self.assertRaises(report.ReportError): self.run_report()
        frame=self.root/'frame-0000.png';frame.unlink();os.mkfifo(frame,0o600)
        with self.assertRaises(report.ReportError): self.run_report()

    def test_index_capture_and_root_drift_are_rejected(self):
        validate=report.capture.validate_png
        for target in ('index.jsonl','frame-0000.png','new-file'):
            def change(data,width,height):
                validate(data,width,height)
                with (self.root/target).open('ab') as output: output.write(b'x')
            with self.subTest(target=target),patch.object(report.capture,'validate_png',side_effect=change):
                with self.assertRaises(report.ReportError): self.run_report()
            if target=='new-file': (self.root/target).unlink()
            elif target=='index.jsonl':
                raw=(self.root/target).read_bytes();(self.root/target).write_bytes(raw[:-1])
            else: (self.root/target).write_bytes(VALID_PNG)

    def test_shortest_yaw_wrap_and_same_scene_health_decreases(self):
        rows=self.rows()
        for row in rows[1:3]: row['state']['yaw']=179
        for row in rows[3:]: row['state']['yaw']=-179
        self.rewrite(rows)
        self.assertEqual(self.run_report()['sampled_absolute_yaw_change_degrees'],2)

    def test_nonadvancing_or_cross_scene_frame_is_still_missing(self):
        original=self.rows()
        for field,value in (('frame',1),('level_id',33),('action_sequence',0)):
            rows=json.loads(json.dumps(original));rows[3][field]=value;self.rewrite(rows)
            result=self.run_report()
            self.assertEqual([row['action'] for row in result['missing_post_action_frames']],['fire','wait'])

    def test_empty_truncated_header_schema_and_time_cap(self):
        original=(self.root/'index.jsonl').read_bytes()
        for data in (b'',original[:-1],original.replace(b'"version":1',b'"version":true',1)):
            (self.root/'index.jsonl').write_bytes(data)
            with self.subTest(data_length=len(data)),self.assertRaises(report.ReportError): self.run_report()
        (self.root/'index.jsonl').write_bytes(original)
        rows=self.rows();rows[-1]['monotonic']=120;self.rewrite(rows)
        with self.assertRaises(report.ReportError): self.run_report()



    def test_exact_row_count_limit_streams_without_corpus_retention(self):
        header,sample=self.rows()[:2]
        index=self.root/'index.jsonl'
        with index.open('w') as output:
            output.write(json.dumps(header)+'\n')
            for sequence in range(1,report.MAX_ROWS):
                sample['sequence']=sequence;output.write(json.dumps(sample)+'\n')
        self.assertEqual(self.run_report()['row_count'],4096)
        sample['sequence']=report.MAX_ROWS
        with index.open('a') as output: output.write(json.dumps(sample)+'\n')
        with self.assertRaises(report.ReportError): self.run_report()

    def test_exact_row_byte_limit_includes_newline(self):
        header=json.dumps(self.rows()[0]).encode()
        padding=report.MAX_ROW_BYTES-len(header)-1
        (self.root/'index.jsonl').write_bytes(header+b' '*padding+b'\n')
        self.assertEqual(self.run_report()['row_count'],1)
        (self.root/'index.jsonl').write_bytes(header+b' '*(padding+1)+b'\n')
        with self.assertRaises(report.ReportError): self.run_report()

    def test_exact_capture_limit_uses_small_resident_pngs(self):
        original=self.rows();frame=original[3]
        frames=[]
        for i in range(p.MAX_CAPTURES+1):
            name=f'frame-{i:04d}.png'
            path=self.root/name;path.write_bytes(VALID_PNG);path.chmod(0o600)
            frames.append({**frame,'capture':name})
        rows=original[:3]+frames[:-1]+original[4:]
        for i,row in enumerate(rows): row['sequence']=i
        self.rewrite(rows)
        self.assertEqual(self.run_report()['capture_count'],300)
        rows.insert(-2,frames[-1])
        for i,row in enumerate(rows): row['sequence']=i
        self.rewrite(rows)
        with self.assertRaises(report.ReportError): self.run_report()



if __name__=='__main__': unittest.main()

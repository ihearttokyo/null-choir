"""Real private files; simulated native post-draw and provider, never GPU/HTTP."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools import playtest_capture as capture
from tools import playtest_bridge as wire
from tools import playtest_mailbox as ipc
from tools import playtest_pilot as pilot
from tools import playtest_protocol as p
from tools import playtest_supervisor as supervisor
from tests.test_playtest_pilot import Clock, Peer
from tests.test_playtest_protocol import observation, reply
from tests.test_playtest_capture import VALID_PNG


class DrawPeer(Peer):
    """Fixed-slot ACK/backpressure simulation. No native renderer exists here."""
    def __init__(self, root, clock):
        super().__init__(root,clock)
        self.capture_id=0
        self.draw_sequence=-1
        self.suppress=False
        self.malformed=False
        self.capture_frame_offset=0
        self.capture_change={}

    def step(self):
        # Existing receiver models physics independently of an RPC arrival.
        self.frame+=1
        state=observation(frame=self.frame,action_sequence=self.receiver.next_sequence,**self.change)
        self.receiver.tick(state,9000+self.clock.now)
        super().step()
        if self.suppress or self.receiver.active or self.receiver.observed is not None:
            return
        ack=json.loads((self.root/'capture_ack.json').read_text())
        if ack['capture_id'] != self.capture_id or not ack['next_byte_bound']:
            return
        if self.draw_sequence == self.receiver.next_sequence:
            return
        self.capture_id+=1
        self.draw_sequence=self.receiver.next_sequence
        state=observation(frame=self.frame+self.capture_frame_offset,
                          action_sequence=self.draw_sequence,**{**self.change,**self.capture_change})
        packet={**ack,'post_draw':True,'width':1,'height':1,'capture_id':self.capture_id,
                'payload_bytes':len(VALID_PNG),'payload_sha256':hashlib.sha256(VALID_PNG).hexdigest(),
                'observation':json.loads(wire.encode_observation(state,9000+self.clock.now))}
        packet.pop('next_byte_bound')
        if self.malformed: packet['payload_sha256']='b'*64
        for name,data in (('capture.bin',VALID_PNG),('capture.json',json.dumps(packet).encode())):
            path=self.root/name;path.write_bytes(data);path.chmod(0o600)


class CapturePilotTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='null-choir-capture-pilot-')
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve()/'run'
        self.clock=Clock()
        self.journal=p.Journal(self.root,'run-01','a'*64,0,
                    max_bytes=p.MAX_BYTES-ipc.IPC_RESERVED_BYTES-capture.CAPTURE_RESERVED_BYTES)
        self.addCleanup(self.journal.close)
        self.controller=p.Controller(0,setup_fee_usd='0',pricing_verified=True,account_active=True)
        self.pilot=pilot.Pilot(self.controller,self.journal,clock=self.clock,sleep=self.clock.sleep,
                               capture_byte_bound=1024)
        self.peer=self.clock.peer=DrawPeer(self.root,self.clock)

    def worker(self,fn,args,timeout):
        self.clock.now+=0.02
        return reply('move_forward')

    def run_one(self):
        with patch.object(supervisor.transport,'LIVE_TEST_ENABLED',True), \
             patch.object(supervisor,'_run_owned_worker',side_effect=self.worker):
            return self.pilot.run_one(credential='synthetic-not-real')

    def test_two_actions_each_wait_for_indexed_matching_postdraw_frame(self):
        for sequence in (1,2):
            result=self.run_one()
            self.assertEqual(result['acknowledged_sequence'],sequence)
            self.assertEqual(self.pilot.capture.last_state['action_sequence'],sequence)
            self.assertEqual(self.peer.draw_sequence,sequence)
        rows=[json.loads(x) for x in (self.root/'index.jsonl').read_text().splitlines()]
        frames=[row for row in rows if row['kind']=='frame']
        self.assertEqual([row['action_sequence'] for row in frames],[1,2])
        self.assertEqual(self.journal.captures,2)
        self.assertEqual(len(self.peer.commands),2)

    def test_missing_frame_stops_before_any_second_action(self):
        self.peer.suppress=True
        with self.assertRaises(pilot.PilotError): self.run_one()
        self.assertEqual(self.controller.attempts,1)
        self.assertEqual(len(self.peer.commands),1)
        self.assertTrue(self.pilot.stopped)
        self.assertTrue(self.journal.closed)
        self.assertLessEqual(self.clock.now,1.3)

    def test_corrupt_postdraw_frame_is_terminal_without_replay(self):
        self.peer.malformed=True
        with self.assertRaises(pilot.PilotError): self.run_one()
        self.assertEqual(self.controller.attempts,1)
        self.assertEqual(self.journal.captures,0)
        self.assertTrue(self.controller.stopped)

    def test_final_capture_budget_stops_without_discarding_completed_action(self):
        self.journal.max_captures=1
        self.assertEqual(self.run_one()['acknowledged_sequence'],1)
        self.assertTrue(self.pilot.stopped)
        self.assertTrue(self.journal.closed)
        self.assertEqual(self.journal.captures,1)
        with self.assertRaises(pilot.PilotError): self.run_one()
        self.assertEqual(self.controller.attempts,1)

    def test_postdraw_newer_than_queued_rpc_keeps_order_without_relabeling_command(self):
        self.peer.capture_frame_offset=1
        self.assertEqual(self.run_one()['acknowledged_sequence'],1)
        rows=[json.loads(x) for x in (self.root/'index.jsonl').read_text().splitlines()]
        frames=[x['frame'] for x in rows if 'frame' in x]
        self.assertEqual(frames,sorted(frames))
        command=next(x for x in rows if x['kind']=='command_attempt')
        self.assertEqual(command['issued_frame'],self.peer.commands[0]['frame'])
        self.assertEqual(self.journal.captures,1)

    def test_menu_frame_after_command_is_terminal_even_with_alive_rpc(self):
        self.peer.capture_change={'phase':'menu'}
        with self.assertRaises(pilot.PilotError): self.run_one()
        self.assertTrue(self.pilot.stopped)
        self.assertEqual(len(self.peer.commands),1)
        self.assertEqual(self.controller.attempts,1)

    def test_stale_player_frame_is_terminal_before_another_decision(self):
        self.peer.capture_change={'player_id':3}
        with self.assertRaises(pilot.PilotError): self.run_one()
        self.assertTrue(self.pilot.stopped)
        self.assertEqual(len(self.peer.commands),1)
        self.assertEqual(self.controller.attempts,1)

    def test_same_frame_capture_requires_consistent_observations(self):
        state=observation()
        self.pilot.capture.last_state=observation()
        self.assertIs(self.pilot._newest_state(state),state)
        for change in ({'level_id':12}, {'player_id':23}, {'action_sequence':1},
                       {'phase':'menu'}, {'health':0}, {'health':72},
                       {'ammo':[0,36,0,0,0,0]}, {'pose':[2,0,2]}, {'sensitivity':2}):
            with self.subTest(change=change):
                self.pilot.capture.last_state=observation(**change)
                with self.assertRaises(ValueError): self.pilot._newest_state(state)
        self.pilot.capture.last_state=observation(frame=state['frame']-1,player_id=23)
        self.assertIs(self.pilot._newest_state(state),state)

    def test_same_frame_menu_conflict_stops_before_provider_or_command(self):
        # The first simulated RPC uses frame 2; a queued draw disagrees at that frame.
        self.pilot.capture.last_state=observation(frame=2,phase='menu')
        with patch.object(supervisor,'_run_owned_worker',side_effect=self.worker) as worker:
            with self.assertRaises(pilot.PilotError): self.run_one()
        worker.assert_not_called()
        self.assertEqual(self.controller.attempts,0)
        self.assertEqual(self.peer.commands,[])
        self.assertTrue(self.journal.closed)

    def test_same_frame_capture_cannot_finish_action_or_allow_next_decision(self):
        barrier=self.pilot._frame_barrier
        def same_frame(*args):
            self.peer.suppress=True
            self.pilot.capture.last_state=observation(
                frame=self.peer.commands[0]['frame'],action_sequence=1)
            with patch.object(self.pilot,'_drain_capture'):
                return barrier(*args)
        with patch.object(self.pilot,'_frame_barrier',side_effect=same_frame):
            with self.assertRaises(pilot.PilotError): self.run_one()
        self.assertTrue(self.pilot.stopped)
        self.assertEqual(self.controller.attempts,1)
        self.assertEqual(len(self.peer.commands),1)
        with self.assertRaises(pilot.PilotError): self.run_one()
        self.assertEqual(self.controller.attempts,1)
        self.assertEqual(len(self.peer.commands),1)

    def test_frame_barrier_waits_for_strictly_newer_issued_frame(self):
        state=observation()
        ticket,_=self.controller.begin(state,0)
        def advance(seconds): self.clock.now+=seconds
        with patch.object(self.pilot,'_drain_capture'), \
             patch.object(self.pilot,'sleep',side_effect=advance):
            for frame in (state['frame']-1,state['frame']):
                with self.subTest(frame=frame):
                    self.clock.now=0
                    self.pilot.capture.last_state=observation(frame=frame,action_sequence=1)
                    with self.assertRaisesRegex(ValueError,'Missing completed frame'):
                        self.pilot._frame_barrier(ticket,1,state['frame'])
            self.clock.now=0
            self.pilot.capture.last_state=observation(frame=state['frame']+1,action_sequence=1)
            self.pilot._frame_barrier(ticket,1,state['frame'])
            self.assertEqual(self.clock.now,0)
    def test_completed_ack_cannot_be_accepted_after_deadline(self):
        state=observation()
        ticket,_=self.controller.begin(state,0)
        self.controller.accept(ticket,reply('move_forward'),state,0.01)
        self.pilot.last_state=observation(action_sequence=1,frame=1)
        self.clock.now=ticket.expires_at+p.LEASE_SECONDS+0.01
        with self.assertRaises(ValueError): self.pilot._acknowledge(ticket)

    def test_slow_capture_validation_cannot_bypass_frame_deadline(self):
        self.peer.suppress=True
        barrier=self.pilot._frame_barrier
        poll=self.pilot.capture.poll
        def slow_poll(now):
            result=poll(now)
            if result is not None: self.clock.now+=1.1
            return result
        def delayed_frame(ticket,sequence,issued_frame):
            self.peer.suppress=False
            self.peer.step()
            with patch.object(self.pilot.capture,'poll',side_effect=slow_poll):
                return barrier(ticket,sequence,issued_frame)
        with patch.object(self.pilot,'_frame_barrier',side_effect=delayed_frame):
            with self.assertRaises(pilot.PilotError): self.run_one()
        self.assertTrue(self.pilot.stopped)
        self.assertEqual(len(self.peer.commands),1)
        self.assertEqual(self.controller.attempts,1)
        self.assertEqual(self.journal.captures,1) # Preserve completed write; no replay.


if __name__=='__main__': unittest.main()

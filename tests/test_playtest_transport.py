"""Offline transport fixtures; BytesIO sockets, synthetic replies, no HTTP traffic."""
import http.client
import importlib.util
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('protocol_fixtures', ROOT / 'tests/test_playtest_protocol.py')
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)
sys.path.insert(0, str(ROOT))
from tools import playtest_transport as t


class SocketFixture:
    def __init__(self, wire):
        self.wire = wire
        self.timeouts = []

    def makefile(self, mode):
        return io.BytesIO(self.wire)

    def settimeout(self, timeout):
        self.timeouts.append(timeout)


class ConnectionFixture:
    def __init__(self, wire):
        self.sock = SocketFixture(wire)
        self.requests = []
        self.closes = 0
        self.fail = None

    def request(self, *args, **kwargs):
        self.requests.append((args, kwargs))
        if self.fail:
            raise self.fail

    def getresponse(self):
        response = http.client.HTTPResponse(self.sock)
        response.begin()
        return response

    def close(self):
        self.closes += 1


def wire(body=None, *, status='200 OK', headers=None):
    if body is None:
        body = json.dumps(fixtures.reply()).encode()
    fields = {'Content-Type': 'application/json', 'Content-Length': str(len(body))}
    fields.update(headers or {})
    fields = {key: value for key, value in fields.items() if value is not None}
    return ('HTTP/1.1 ' + status + '\r\n' + ''.join(f'{k}: {v}\r\n' for k, v in fields.items()) + '\r\n').encode() + body


class TransportTests(unittest.TestCase):
    def controller(self, **changes):
        options = {'setup_fee_usd': '0', 'pricing_verified': True, 'account_active': True}
        options.update(changes)
        return t.protocol.Controller(0, **options)

    def invoke(self, conn, *, state=None, current=None, clock=lambda: 0.01, controller=None):
        controller = controller or self.controller()
        with patch.object(t, 'LIVE_TEST_ENABLED', True), patch.object(t.http.client, 'HTTPSConnection', return_value=conn) as factory:
            result = t.decide(controller, state or fixtures.observation(),
                              credential='synthetic-key-not-real',
                              observe=lambda: current or fixtures.observation(), clock=clock)
        return controller, result, factory

    def test_activation_hold_prevents_connection(self):
        self.assertFalse(t.LIVE_TEST_ENABLED)
        controller = self.controller()
        with patch.object(t.http.client, 'HTTPSConnection') as factory, self.assertRaises(t.TransportError):
            t.decide(controller, fixtures.observation(), credential='synthetic',
                     observe=fixtures.observation, clock=lambda: 0)
        factory.assert_not_called()
        self.assertTrue(controller.stopped)
        self.assertEqual(controller.attempts, 0)

    def test_unknown_account_fee_or_price_never_connects(self):
        for changes in ({'setup_fee_usd': None}, {'pricing_verified': False}, {'account_active': False}):
            c = self.controller(**changes)
            with patch.object(t, 'LIVE_TEST_ENABLED', True), patch.object(t.http.client, 'HTTPSConnection') as factory, self.assertRaises(t.TransportError):
                t.decide(c, fixtures.observation(), credential='synthetic', observe=fixtures.observation, clock=lambda: 0)
            factory.assert_not_called()
            self.assertTrue(c.stopped)

    def test_official_response_real_http_parser_and_private_request(self):
        conn = ConnectionFixture(wire())
        c, result, factory = self.invoke(conn, state=fixtures.observation(source='PRIVATE SOURCE', path='/Users/private', screenshot='PRIVATE IMAGE'))
        self.assertEqual(factory.call_args.args, ('api.typesafe.ai',))
        self.assertGreater(factory.call_args.kwargs['timeout'], 0)
        self.assertLessEqual(factory.call_args.kwargs['timeout'], 0.2)
        context = factory.call_args.kwargs['context']
        self.assertTrue(context.check_hostname)
        self.assertEqual(context.verify_mode, t.ssl.CERT_REQUIRED)
        args, kwargs = conn.requests[0]
        self.assertEqual(args[:2], ('POST', '/v1/systemone'))
        self.assertNotIn('PRIVATE', kwargs['body'].decode())
        self.assertNotIn('synthetic-key', kwargs['body'].decode())
        self.assertEqual(kwargs['headers']['Authorization'], 'Bearer synthetic-key-not-real')
        self.assertEqual(result['plan']['action'], 'move_forward')
        self.assertEqual(result['usage'], {'input_tokens': 100, 'output_tokens': 10})
        self.assertEqual(result['model'], t.protocol.MODEL)
        self.assertEqual(c.attempts, 1)
        self.assertTrue(conn.closes)

    def test_status_encoding_type_length_and_json_fail_closed(self):
        valid = json.dumps(fixtures.reply()).encode()
        cases = [wire(status='401 Unauthorized'), wire(status='302 Found'),
                 wire(headers={'Content-Type': 'image/png'}), wire(headers={'Content-Encoding': 'gzip'}),
                 wire(headers={'Content-Length': str(t.MAX_RESPONSE_BYTES + 1)}),
                 wire(headers={'Content-Length': str(len(valid) + 1)}),
                 wire(body=b'{not json}'), wire(body=b'\xff'),
                 wire(body=b'{"model":"bad","model":"also bad"}'),
                 wire(body=b'x' * (t.MAX_RESPONSE_BYTES + 1))]
        for raw in cases:
            c = self.controller()
            conn = ConnectionFixture(raw)
            with self.subTest(raw=raw[:70]), self.assertRaises(t.TransportError):
                self.invoke(conn, controller=c)
            self.assertTrue(c.stopped)
            self.assertEqual(set(c.release_plan['release']), set(t.protocol.HELD_INPUTS))
            self.assertEqual(c.attempts, 1)
            self.assertTrue(conn.closes)

    def test_menu_and_stale_player_after_reply_cannot_act(self):
        for current in (fixtures.observation(phase='menu', player_id=0, level_id=0),
                        fixtures.observation(player_id=33), fixtures.observation(action_sequence=1)):
            c = self.controller()
            with self.assertRaises(t.TransportError):
                self.invoke(ConnectionFixture(wire()), current=current, controller=c)
            self.assertTrue(c.stopped)
            self.assertFalse(c.held)

    def test_clock_cannot_regress_during_response(self):
        values = iter([0, 0.01, 0.005])
        c = self.controller()
        with self.assertRaises(t.TransportError):
            self.invoke(ConnectionFixture(wire()), controller=c, clock=lambda: next(values, 0.005))
        self.assertTrue(c.stopped)

    def test_chunked_and_eof_framing_and_stream_limit(self):
        body = json.dumps(fixtures.reply()).encode()
        chunked = f'{len(body):x}\r\n'.encode() + body + b'\r\n0\r\n\r\n'
        _, result, _ = self.invoke(ConnectionFixture(wire(body=chunked,
            headers={'Content-Length': None, 'Transfer-Encoding': 'chunked'})))
        self.assertEqual(result['plan']['action'], 'move_forward')
        _, result, _ = self.invoke(ConnectionFixture(wire(body=body,
            headers={'Content-Length': None, 'Connection': 'close'})))
        self.assertEqual(result['model'], t.protocol.MODEL)
        for raw in (wire(body=b'x'*(t.MAX_RESPONSE_BYTES+1), headers={'Content-Length': None}),
                    wire(body=chunked, headers={'Transfer-Encoding': 'chunked'})):
            c = self.controller()
            with self.assertRaises(t.TransportError):
                self.invoke(ConnectionFixture(raw), controller=c)
            self.assertTrue(c.stopped)

    def test_credentials_and_callback_interrupts_stop_without_connection_leaks(self):
        for key in ('', 'Bearer key', 'secret\r\nInjected: value', '\u00e9', 'x'*4097):
            c = self.controller()
            with patch.object(t, 'LIVE_TEST_ENABLED', True), patch.object(t.http.client, 'HTTPSConnection') as factory, self.assertRaises(t.TransportError):
                t.decide(c, fixtures.observation(), credential=key, observe=fixtures.observation, clock=lambda: 0)
            factory.assert_not_called()
            self.assertTrue(c.stopped)
        conn = ConnectionFixture(wire())
        c = self.controller()
        def interrupt():
            raise KeyboardInterrupt()
        with patch.object(t, 'LIVE_TEST_ENABLED', True), patch.object(t.http.client, 'HTTPSConnection', return_value=conn), self.assertRaises(KeyboardInterrupt):
            t.decide(c, fixtures.observation(), credential='synthetic', observe=interrupt, clock=lambda: 0.01)
        self.assertTrue(c.stopped)
        self.assertTrue(conn.closes)

    def test_expired_response_and_network_error_no_retry_or_key_echo(self):
        c = self.controller()
        times = iter([0, 0.01, 0.3])
        with self.assertRaises(t.TransportError):
            self.invoke(ConnectionFixture(wire()), controller=c, clock=lambda: next(times))
        self.assertTrue(c.stopped)
        conn = ConnectionFixture(wire())
        conn.fail = OSError('Authorization: Bearer synthetic-key-not-real')
        c = self.controller()
        with self.assertRaises(t.TransportError) as caught:
            self.invoke(conn, controller=c)
        self.assertNotIn('synthetic-key', str(caught.exception))
        self.assertTrue(caught.exception.__suppress_context__)
        self.assertEqual(len(conn.requests), 1)
        self.assertEqual(c.attempts, 1)
        self.assertEqual(str(c.reserved_usd), '0.002688')
        self.assertTrue(conn.closes)


if __name__ == '__main__':
    unittest.main()

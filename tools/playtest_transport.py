"""Prepared HTTPS transport, disabled pending native/profile/account activation.

No CLI or automatic calls. Offline fixtures replace only the connection boundary.
Socket timeouts do not certify a hard DNS/whole-pilot wall deadline: the eventual
owned sidecar supervisor and independent native input lease are still required.
"""
import http.client
import json
import ssl

from . import playtest_protocol as protocol

LIVE_TEST_ENABLED = False  # Keep held until native route/account/supervisor gates clear.
MAX_RESPONSE_BYTES = 16384


class TransportError(Exception):
    """Public sanitized error; never include provider bodies or credentials."""


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key')
        result[key] = value
    return result


def _remaining(clock, controller, ticket):
    controller._clock(clock())
    remaining = ticket.expires_at - controller.last_time
    if remaining <= 0:
        raise TimeoutError('expired decision')
    return remaining


def _validate_activation(controller, credential):
    if not LIVE_TEST_ENABLED or not controller.budget_verified:
        raise ValueError('activation held')
    if type(credential) is not str or not 1 <= len(credential) <= 4096 or any(not 33 <= ord(ch) <= 126 for ch in credential):
        raise ValueError('invalid bearer credential')


def _exchange(controller, payload, ticket, credential, clock):
    """Shared fixed-endpoint wire exchange; raw reply stays in private process memory."""
    connection = None
    response = None
    try:
        _validate_activation(controller, credential)
        if ticket != controller.pending:
            raise ValueError('unreserved request')
        body = json.dumps(payload, separators=(',', ':'), allow_nan=False).encode('utf-8')
        if len(body) > MAX_RESPONSE_BYTES:
            raise ValueError('request body limit')
        context = ssl.create_default_context()
        connection = http.client.HTTPSConnection('api.typesafe.ai',
            timeout=_remaining(clock, controller, ticket), context=context)
        connection.request('POST', '/v1/systemone', body=body,
            headers={'Authorization': 'Bearer ' + credential,
                     'Content-Type': 'application/json', 'Accept': 'application/json',
                     'Connection': 'close'})
        # getresponse can detach the connection socket when the server closes.
        stream_socket = connection.sock
        stream_socket.settimeout(_remaining(clock, controller, ticket))
        response = connection.getresponse()
        if response.status != 200:
            raise ValueError('provider status')
        if response.getheader('Content-Type', '').split(';')[0].strip().lower() != 'application/json':
            raise ValueError('provider content type')
        if response.getheader('Content-Encoding', 'identity').lower() != 'identity':
            raise ValueError('compressed response rejected')
        length = response.getheader('Content-Length')
        transfer = response.getheader('Transfer-Encoding')
        if transfer and (transfer.lower() != 'chunked' or length is not None):
            raise ValueError('ambiguous response framing')
        if length is not None:
            if not length.isascii() or not length.isdecimal():
                raise ValueError('invalid response length')
            length = int(length)
            if length > MAX_RESPONSE_BYTES:
                raise ValueError('response byte limit')
        data = bytearray()
        while True:
            stream_socket.settimeout(_remaining(clock, controller, ticket))
            part = response.read1(min(4096, MAX_RESPONSE_BYTES + 1 - len(data)))
            if not part:
                break
            data.extend(part)
            if len(data) > MAX_RESPONSE_BYTES:
                raise ValueError('response byte limit')
        if length is not None and len(data) != length:
            raise ValueError('truncated response')
        reply = json.loads(data.decode('utf-8'), object_pairs_hook=_unique_object)
        response.close()
        response = None
        connection.close()
        connection = None
        return reply
    except Exception:
        controller.fail()
        raise TransportError('Decision unavailable; release inputs and stop the pilot.') from None
    except BaseException:
        controller.fail()
        raise
    finally:
        for resource in (response, connection):
            if resource is not None:
                try:
                    resource.close()
                except Exception:
                    pass  # Failed request remains stopped/reserved; never retry cleanup.


def decide(controller, state, *, credential, observe, clock):
    """One reserved decision and fresh observation; return plans/usage, never input."""
    try:
        _validate_activation(controller, credential)
        ticket, payload = controller.begin(state, clock())
        reply = _exchange(controller, payload, ticket, credential, clock)
        plan = controller.accept(ticket, reply, observe(), clock())
        return {'plan': plan, 'model': reply['model'],
                'usage': {key: reply['usage'][key] for key in ('input_tokens', 'output_tokens')}}
    except Exception:
        controller.fail()
        raise TransportError('Decision unavailable; release inputs and stop the pilot.') from None
    except BaseException:
        controller.fail()
        raise

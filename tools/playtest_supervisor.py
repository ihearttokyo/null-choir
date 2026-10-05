"""Private spawned network worker; no CLI, native launch or hosted activation.

Parent reserves once and validates a fresh observation. It never persists raw
replies or credentials. Worker stdout/stderr are discarded, never public logs.
The native bridge must still enforce its input lease independently.
"""
import json
import multiprocessing
import os
import signal
import time

from . import playtest_protocol as protocol
from . import playtest_transport as transport

MAX_FRAME_BYTES = 32768


class WorkerError(Exception):
    """Sanitized terminal outcome; no secret or provider body in error text."""


def _child_main(sender, worker, args):
    # The fixed wrapper owns the session before any worker code can run/spawn.
    os.setsid()
    fd = os.open(os.devnull, os.O_WRONLY)
    os.dup2(fd, 1)
    os.dup2(fd, 2)
    os.close(fd)
    try:
        sender.send_bytes(b'{"ready":true}')
        if sender.recv_bytes(16) != b'start':
            raise ValueError('parent ownership not acknowledged')
        result = worker(*args)
        data = json.dumps({'ok': True, 'result': result}, separators=(',', ':'), allow_nan=False).encode('utf-8')
        if len(data) > MAX_FRAME_BYTES:
            raise ValueError('worker result cap')
        sender.send_bytes(data)
    except BaseException:
        sender.send_bytes(b'{"ok":false}')
    finally:
        sender.close()


def _run_owned_worker(worker, args, timeout):
    """Trusted local callable only; model text never selects executable workers."""
    try:
        protocol.number(timeout, 0.000001, protocol.MAX_SECONDS)
        if os.name != 'posix':
            raise ValueError('owned POSIX process group required')
    except ValueError:
        raise WorkerError('Worker bounds unavailable.') from None
    context = multiprocessing.get_context('spawn')
    receiver, sender = context.Pipe(duplex=True)
    process = context.Process(target=_child_main, args=(sender, worker, args))
    ready = False
    deadline = time.monotonic() + timeout

    def receive():
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not receiver.poll(remaining):
            raise TimeoutError('worker deadline')
        return json.loads(receiver.recv_bytes(MAX_FRAME_BYTES).decode('utf-8'),
                          object_pairs_hook=transport._unique_object)

    try:
        process.start()
        sender.close()
        if receive() != {'ready': True}:
            raise ValueError('worker session not established')
        ready = True
        receiver.send_bytes(b'start')
        result = receive()
        if type(result) is not dict or set(result) != {'ok', 'result'} or result['ok'] is not True:
            raise ValueError('worker failed')
        if time.monotonic() >= deadline:
            raise TimeoutError('late worker result')
        return result['result']
    except Exception:
        raise WorkerError('Worker stopped; release inputs and preserve its reservation.') from None
    finally:
        # Do not reap/poll the owned leader before killing its group: its PID
        # cannot be recycled while unreaped, including after a successful reply.
        if process.pid is not None:
            try:
                if ready:
                    os.killpg(process.pid, signal.SIGKILL)
                else:
                    process.kill()  # No target executes before the parent's ACK.
            except ProcessLookupError:
                pass
            process.join()
            process.close()
        receiver.close()
        sender.close()


def _http_worker(controller, payload, ticket, credential, epoch_offset):
    # Translate real elapsed time, not a mutable/unpicklable parent clock callable.
    return transport._exchange(controller, payload, ticket, credential,
                               lambda: time.monotonic()+epoch_offset)


def decide(controller, state, *, credential, observe, clock=time.monotonic):
    """Supervised HTTP reply, then original parent ticket and fresh scene validation."""
    try:
        transport._validate_activation(controller, credential)
        ticket, payload = controller.begin(state, clock())
        now = clock()
        controller._clock(now)
        epoch_offset = now-time.monotonic()
        reply = _run_owned_worker(_http_worker, (controller, payload, ticket, credential, epoch_offset),
                                  ticket.expires_at - now)
        plan = controller.accept(ticket, reply, observe(), clock())
        return {'plan': plan, 'model': reply['model'],
                'usage': {key: reply['usage'][key] for key in ('input_tokens', 'output_tokens')}}
    except Exception:
        controller.fail()
        raise WorkerError('Decision unavailable; release inputs and stop the pilot.') from None
    except BaseException:
        controller.fail()
        raise

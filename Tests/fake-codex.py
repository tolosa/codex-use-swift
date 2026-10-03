#!/usr/bin/python3
"""Protocol fixture: enforces the handshake and fragments each response."""
import json
import sys
import time

initialized = False

def send(message):
    text = json.dumps(message) + '\n'
    midpoint = len(text) // 2
    sys.stdout.write(text[:midpoint])
    sys.stdout.flush()
    time.sleep(0.02)
    sys.stdout.write(text[midpoint:])
    sys.stdout.flush()

for line in sys.stdin:
    request = json.loads(line)
    method = request['method']
    if method == 'initialized':
        initialized = True
        continue
    if method == 'initialize':
        result = {'userAgent': 'fixture'}
    elif not initialized:
        send({'id': request['id'], 'error': {'message': 'Handshake missing'}})
        continue
    elif method == 'account/read':
        result = {'account': {'type': 'chatgpt', 'planType': 'plus'}}
    elif method == 'account/rateLimits/read':
        send({'method': 'account/rateLimits/updated', 'params': {}})
        result = {'rateLimits': {'primary': {'usedPercent': 37, 'windowDurationMins': 300}, 'secondary': None}}
    else:
        raise RuntimeError('Unexpected method: ' + method)
    send({'id': request['id'], 'result': result})

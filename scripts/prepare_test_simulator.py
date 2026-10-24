#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Resolve a named iOS test destination, creating its simulator when missing."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

DEFAULT_DESTINATION = 'platform=iOS Simulator,name=iPhone 18 Pro'


def version(value):
    parts = tuple(int(p) for p in value.split('.'))
    return parts + (0,) * (3 - len(parts))


def parse(destination):
    return dict(part.strip().split('=', 1) for part in destination.split(','))


def prepare(destination, minimum):
    fields = parse(destination)
    if fields.get('platform') != 'iOS Simulator':
        return destination
    inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', '--json'], text=True))
    if 'id' in fields:
        # Explicit IDs keep xcodebuild's destination semantics while they exist;
        # a deleted simulator falls back to the default instead of failing the release.
        if any(d['udid'] == fields['id'] and d.get('isAvailable')
               for devices in inventory['devices'].values() for d in devices):
            return destination
        print(f'Simulator {fields["id"]} no longer exists; using {DEFAULT_DESTINATION}', file=sys.stderr)
        fields = parse(DEFAULT_DESTINATION)
    name = fields.get('name')
    if not name:
        raise ValueError('An iOS Simulator destination needs name= or id=.')
    device_type = next((d for d in inventory['devicetypes'] if d['name'] == name), None)
    requested = fields.get('OS', 'latest')
    runtimes = [r for r in inventory['runtimes']
                if r.get('isAvailable') and '.iOS-' in r['identifier']
                and version(r['version']) >= version(minimum)
                and (requested == 'latest' or version(r['version']) == version(requested))]
    if device_type:
        # A version range is not enough: a newer runtime can omit a device type
        # (simctl create then fails with "Incompatible device"), so honor its list.
        runtimes = [r for r in runtimes
                    if version(device_type.get('minRuntimeVersionString', '0')) <= version(r['version'])
                    <= version(device_type.get('maxRuntimeVersionString', '65535'))
                    and ('supportedDeviceTypes' not in r
                         or any(s['identifier'] == device_type['identifier'] for s in r['supportedDeviceTypes']))]
    if not runtimes:
        raise ValueError(f'No installed compatible iOS simulator runtime for {name} (OS={requested}, minimum {minimum}). Install it in Xcode Settings > Components.')
    runtime = max(runtimes, key=lambda r: version(r['version']))
    devices = inventory['devices'].get(runtime['identifier'], [])
    matches = [d for d in devices if d.get('isAvailable') and d['name'] == name]
    if matches:
        device = sorted(matches, key=lambda d: (d['state'] != 'Booted', d['udid']))[0]
        udid = device['udid']
        booted = device['state'] == 'Booted'
        print(f'Reusing {name} on iOS {runtime["version"]}: {udid}', file=sys.stderr)
    else:
        if not device_type:
            raise ValueError(f'No simulator named {name!r} or installed device type with that name. Set TEST_DESTINATION to a valid name or UUID.')
        udid = subprocess.check_output(['xcrun', 'simctl', 'create', name, device_type['identifier'], runtime['identifier']], text=True).strip()
        booted = False
        print(f'Created {name} on iOS {runtime["version"]}: {udid}', file=sys.stderr)
    if not booted:
        subprocess.run(['xcrun', 'simctl', 'boot', udid], check=True, stdout=sys.stderr)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'], check=True, stdout=sys.stderr)
    fields.pop('name', None)
    fields.pop('OS', None)
    fields['id'] = udid
    return ','.join(f'{key}={value}' for key, value in fields.items())


def deployment_target():
    project = (Path(__file__).resolve().parents[1] / 'project.yml').read_text()
    match = re.search(r'^\s+iOS:\s*[\"\x27]?([0-9.]+)', project, re.MULTILINE)
    if not match:
        raise ValueError('Cannot read the iOS deployment target from project.yml')
    return match.group(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', default=DEFAULT_DESTINATION)
    args = parser.parse_args()
    try:
        print(prepare(args.destination, deployment_target()))
    except (ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f'Simulator preparation failed: {error}')


if __name__ == '__main__':
    main()

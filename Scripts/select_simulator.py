import json
import subprocess
import sys

family = sys.argv[1]
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
for runtime, entries in reversed(list(devices.items())):
    if '.iOS-' not in runtime:
        continue
    for device in entries:
        if device.get('isAvailable') and family in device['name']:
            print(device['udid'])
            raise SystemExit(0)
raise SystemExit(f'No installed {family} simulator. Install an iOS runtime in Xcode settings.')

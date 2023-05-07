# Tuya IP Control
This is a simple driver to bridge Tuya devices and Control4.
## Python Setup
Python3 and pip need to be installed.
- Install dependencies
  - `pip3 install tinytuya flask`
- Configure TinyTuya
  - Follow [these](https://github.com/jasonacox/tinytuya#setup-wizard---getting-local-keys) instructions
  - Be sure `app.py` is in the same directory, as the script will read the generated JSON files.
  - Make sure devices and their keys are present when running `python -m tinytuya scan` after pairing your Tuya Dev account.

## Control4 Setup
- Input server IP/port in Device Address Property
  - Default port is 5000
  - `ip:5000`
- Run Scan Devices from Actions. This will take 15 seconds to complete.
- Devices should populate in Device Selector.
- After selecting the device, the driver is ready to use.

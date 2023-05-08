from flask import Flask, jsonify, request
import json
import tinytuya
import time
import colorsys
import threading

"""
GLOBALS
"""

deviceArray = {}

api = Flask(__name__)

scanresult = {}

keepalive = True
keepalive_interval = 5

"""
API ROUTES
"""

@api.route("/scan", methods=["GET"])
def scan_devices():
    global scanresult
    duration = request.args.get('duration') or 15
    d = tinytuya.deviceScan(False, duration)
    scanresult = d
    return jsonify(scanresult)

@api.route("/scanresult", methods=["GET"])
def scan_result():
    global scanresult
    return jsonify(scanresult)

@api.route("/control", methods=["POST"])
def control_device():
    req = request.get_json()
    res = control_cmd(req)
    return jsonify(res)

@api.route("/state", methods=["POST"])
def device_state():
    req = request.get_json()
    res = get_state(req)
    return jsonify(res)

"""
MAIN FUNCTIONS
"""

#tinytuya.set_debug(True)

def add_device(data):
    id = data["id"]
    print("------Device not found in array. Adding...------")
    deviceArray[id] = tinytuya.BulbDevice(id, data["ip"], data["key"])
    deviceArray[id].set_version(float(data["ver"]))
    deviceArray[id].set_socketPersistent(True)
    print("------Done adding.------")

def get_state(data):
    
    id = data["id"]

    if id not in deviceArray:
      add_device(data)

    d = deviceArray[id]

    attribs = {}

    for key,val in d.__dict__.items():
        if isinstance(val,bytes):
            val = val.decode('utf-8')
        if key == "socket":
            print("skipping:",key)
            continue
        print("---")
        print("key:",key)
        print("val:",json.dumps(val))
        attribs[key] = val

    #print("Attribs:",attribs)

    return {"status":d.status(),"state":d.state(),"attributes":attribs}



def control_cmd(data):
    
    id = data["id"]

    if id not in deviceArray:
      add_device(data)

    d = deviceArray[id]

    #Send main payload
    print("------Generate payload...------")
    rawpayload = gen_payload(d, data["cmd"])
    data = d.set_multiple_values(rawpayload)
    #genPayload = d.generate_payload(tinytuya.CONTROL, rawpayload)
    #data = d._send_receive(genPayload)
    status = {"status": "OK", "payload": rawpayload, "response": data}
    print(f"------Done. Status: {status}\n------")

    return status


"""
GENERATE PAYLOADS
"""


def gen_payload(d, cmd):

    payload = {}
    #state = d.state()
    #status = d.status()

    #print("State:",state)
    #print("Status:",status)

    def getColor():
        r, g, b = cmd["color"].split(",")
        r = float(r)
        g = float(g)
        b = float(b)
        return r,g,b
    
    def pctToTypeVal(val):
        if d.bulb_type == "B":
            b = int(10 + (1000 - 10) * val / 100)
        else:
            b = int(25 + (255 - 25) * val / 100)

        return b

    def setColor(r,g,b):
        print("Setting RGB to:",r,g,b)
        hexvalue = tinytuya.BulbDevice._rgb_to_hexvalue(
            r, g, b, d.bulb_type
        )

        print("new hexval:",hexvalue)

        payload[d.DPS_INDEX_MODE[d.bulb_type]] = d.DPS_MODE_COLOUR
        payload[d.DPS_INDEX_COLOUR[d.bulb_type]] = hexvalue

    def setWhite(tempPct):
        
        print("Setting white to:",tempPct)

        temp = pctToTypeVal(tempPct)

        payload[d.DPS_INDEX_MODE[d.bulb_type]] = d.DPS_MODE_WHITE
        payload[d.DPS_INDEX_COLOURTEMP[d.bulb_type]] = temp

    if cmd["mode"] == "color" or cmd["mode"] == "both":
        if "brightness" in cmd:
            bri = 255 * (cmd["brightness"]/100)
            
            r,g,b = getColor()
            h,s,v = colorsys.rgb_to_hsv(r,g,b)
            r,g,b = colorsys.hsv_to_rgb(h,s,bri)
            setColor(r,g,b)
        else:
            r,g,b = getColor()
            setColor(r,g,b)
    else:
        print("mode not color:",cmd["mode"])

    if cmd["mode"] == "white" or cmd["mode"] == "both":
        setWhite(cmd["temp"])
        if "brightness" in cmd:
            b = pctToTypeVal(cmd["brightness"])
            payload[d.DPS_INDEX_BRIGHTNESS[d.bulb_type]] = b
    else:
        print("mode not white:",cmd["mode"])

    if "brightness" in cmd:
        if cmd["brightness"] == 0:
          payload[d.DPS_INDEX_ON[d.bulb_type]] = False
        else:
          payload[d.DPS_INDEX_ON[d.bulb_type]] = True
          """ b = pctToTypeVal(cmd["brightness"])
          payload[d.DPS_INDEX_BRIGHTNESS[d.bulb_type]] = b """

    if "dps" in cmd:
        for dp in cmd["dps"]:
            payload[str(dp["dp"])] = dp["value"]

    print("Generated payload:",payload)

    return payload

"""
KEEP ALIVE
"""
def send_keepalive():
    while keepalive:
        for id in deviceArray:
            print("Sending keepalive for:",id)
            status = deviceArray[id].status()
            print("Status:",status)
            print("---")
        time.sleep(keepalive_interval)

def run_server():
    api.run(host="0.0.0.0")

if __name__ == "__main__":
    #api.run(host="0.0.0.0")
    threading.Thread(target=run_server).start()
    threading.Thread(target=send_keepalive).start()
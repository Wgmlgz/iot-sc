import json

config_path = "/etc/iot-sc/config.json"

current_fw_title = "test"
current_fw_version = "0.02"

def load_config():
    with open(config_path, "r") as config_file:
        t = json.load(config_file)
        t["current_fw_title"] = current_fw_title
        t["current_fw_version"] = current_fw_version
        return t


def update_config(config):
    with open(config_path, "w") as config_file:
        config_file.write(json.dumps(config, indent=2))

from requests import get, post
from time import sleep
from zlib import crc32
from hashlib import sha256, sha384, sha512, md5
from math import ceil
from os import path
import os
import subprocess

FW_CHECKSUM_ATTR = "fw_checksum"
FW_CHECKSUM_ALG_ATTR = "fw_checksum_algorithm"
FW_SIZE_ATTR = "fw_size"
FW_TITLE_ATTR = "fw_title"
FW_VERSION_ATTR = "fw_version"

FW_STATE_ATTR = "fw_state"

REQUIRED_SHARED_KEYS = [
    FW_CHECKSUM_ATTR,
    FW_CHECKSUM_ALG_ATTR,
    FW_SIZE_ATTR,
    FW_TITLE_ATTR,
    FW_VERSION_ATTR,
]

from configuration import load_config, update_config

config = {}


def collect_required_data():
    device_config = load_config()
    config["thingsboard_url"] = device_config["thingsboard_url"]
    config["token"] = device_config["auth_token"]
    config["chunk_size"] = device_config["update_chunk_size"]
    config["current_fw_title"] = device_config["current_fw_title"]
    config["current_fw_version"] = device_config["current_fw_version"]
    return config


def send_telemetry(telemetry):
    print(f"Sending current info: {telemetry}")
    post(
        f"{config['thingsboard_url']}/api/v1/{config['token']}/telemetry",
        json=telemetry,
    )


def get_firmware_info():
    response = get(
        f"{config['thingsboard_url']}/api/v1/{config['token']}/attributes",
        params={"sharedKeys": REQUIRED_SHARED_KEYS},
    ).json()
    return response.get("shared", {})


def get_firmware(fw_info):
    chunk_count = (
        ceil(fw_info.get(FW_SIZE_ATTR, 0) / config["chunk_size"])
        if config["chunk_size"] > 0
        else 0
    )
    firmware_data = b""
    for chunk_number in range(chunk_count + 1):
        params = {
            "title": fw_info.get(FW_TITLE_ATTR),
            "version": fw_info.get(FW_VERSION_ATTR),
            "size": (
                config["chunk_size"]
                if config["chunk_size"] < fw_info.get(FW_SIZE_ATTR, 0)
                else fw_info.get(FW_SIZE_ATTR, 0)
            ),
            "chunk": chunk_number,
        }
        print(params)
        print(
            f'Getting chunk with number: {chunk_number + 1}. Chunk size is : {config["chunk_size"]} byte(s).'
        )
        print(f"{config['thingsboard_url']}/api/v1/{config['token']}/firmware", params)
        response = get(
            f"{config['thingsboard_url']}/api/v1/{config['token']}/firmware",
            params=params,
        )
        if response.status_code != 200:
            print("Received error:")
            response.raise_for_status()
            return
        firmware_data = firmware_data + response.content
    return firmware_data


def verify_checksum(firmware_data, checksum_alg, checksum):
    if firmware_data is None:
        print("Firmware wasn't received!")
        return False
    if checksum is None:
        print("Checksum was't provided!")
        return False
    checksum_of_received_firmware = None
    print(f"Checksum algorithm is: {checksum_alg}")
    if checksum_alg.lower() == "sha256":
        checksum_of_received_firmware = sha256(firmware_data).digest().hex()
    elif checksum_alg.lower() == "sha384":
        checksum_of_received_firmware = sha384(firmware_data).digest().hex()
    elif checksum_alg.lower() == "sha512":
        checksum_of_received_firmware = sha512(firmware_data).digest().hex()
    elif checksum_alg.lower() == "md5":
        checksum_of_received_firmware = md5(firmware_data).digest().hex()
    elif checksum_alg.lower() == "crc32":
        reversed_checksum = f"{crc32(firmware_data) & 0xffffffff:0>2X}"
        if len(reversed_checksum) % 2 != 0:
            reversed_checksum = "0" + reversed_checksum
        checksum_of_received_firmware = "".join(
            reversed(
                [
                    reversed_checksum[i : i + 2]
                    for i in range(0, len(reversed_checksum), 2)
                ]
            )
        ).lower()
    else:
        print("Client error. Unsupported checksum algorithm.")
    print(checksum_of_received_firmware)

    return checksum_of_received_firmware == checksum


def remove_directory(dir_path):
    if os.path.exists(dir_path):
        subprocess.run(["rm", "-rf", dir_path], check=True)
        print(f"Removed existing directory: {dir_path}")


def extract_firmware(archive_path, extract_to):
    os.makedirs(extract_to, exist_ok=True)
    subprocess.run(["tar", "-xzf", archive_path, "-C", extract_to], check=True)
    print(f"Extracted {archive_path} to {extract_to}")


def trigger_update_agent(command, agent_url):
    response = subprocess.run(
        ["curl", "-d", command, "-X", "POST", agent_url], capture_output=True, text=True
    )
    print("Update Agent Response:", response.stdout)


def apply_upgrade(version_from, version_to, firmware_archive_path):
    print(f"Updating from {version_from} to {version_to}:")

    # Define the paths and parameters
    extraction_directory = firmware_archive_path.replace(".tar.gz", "")
    update_agent_url = "http://172.17.0.1:1337/execute"
    update_script_command = (
        f"bash {extraction_directory}/apply_update.sh {firmware_archive_path}"
    )

    # Process the update
    remove_directory(extraction_directory)
    extract_firmware(firmware_archive_path, extraction_directory)
    trigger_update_agent(update_script_command, update_agent_url)
    
    raise Exception('Unreachable, update agent failed')


def check_updates():
    config = collect_required_data()
    current_firmware_info = {
        "current_fw_title": config.get("current_fw_title", None),
        "current_fw_version": config.get("current_fw_version", None),
    }
    try:
        send_telemetry(current_firmware_info)

        print(f"Getting firmware info from {config['thingsboard_url']}..")
        firmware_info = get_firmware_info()

        if (
            firmware_info.get(FW_VERSION_ATTR) is not None
            and firmware_info.get(FW_VERSION_ATTR)
            != current_firmware_info.get("current_" + FW_VERSION_ATTR)
        ) or (
            firmware_info.get(FW_TITLE_ATTR) is not None
            and firmware_info.get(FW_TITLE_ATTR)
            != current_firmware_info.get("current_" + FW_TITLE_ATTR)
        ):
            print("New firmware available!")

            current_firmware_info[FW_STATE_ATTR] = "DOWNLOADING"
            sleep(1)
            send_telemetry(current_firmware_info)

            firmware_data = get_firmware(firmware_info)

            current_firmware_info[FW_STATE_ATTR] = "DOWNLOADED"
            sleep(1)
            send_telemetry(current_firmware_info)

            verification_result = verify_checksum(
                firmware_data,
                firmware_info.get(FW_CHECKSUM_ALG_ATTR),
                firmware_info.get(FW_CHECKSUM_ATTR),
            )

            if verification_result:
                print("Checksum verified!")
                current_firmware_info[FW_STATE_ATTR] = "VERIFIED"
                sleep(1)
                send_telemetry(current_firmware_info)
            else:
                print("Checksum verification failed!")
                current_firmware_info[FW_STATE_ATTR] = "FAILED"
                sleep(1)
                send_telemetry(current_firmware_info)
                firmware_data = get_firmware(firmware_info)
                return False

            current_firmware_info[FW_STATE_ATTR] = "UPDATING"
            sleep(1)
            send_telemetry(current_firmware_info)

            file_path = path.join(
                "/opt",
                "iot-sc",
                firmware_info.get(FW_TITLE_ATTR)
                + "_"
                + firmware_info.get(FW_VERSION_ATTR)
                + ".tar.gz",
            )
            with open(
                file_path,
                "wb",
            ) as firmware_file:
                firmware_file.write(firmware_data)

            apply_upgrade(
                current_firmware_info["current_" + FW_VERSION_ATTR],
                firmware_info.get(FW_VERSION_ATTR),
                file_path,
            )
        else:
            config = load_config()
            if (
                config["current_fw_title"] != config.get("reported_fw_title", None)
                or config["current_fw_version"] != config.get("reported_fw_version", None)
            ):
                current_firmware_info[FW_STATE_ATTR] = "UPDATED"
                sleep(1)
                send_telemetry(current_firmware_info)
                config["reported_fw_title"] = config["current_fw_title"]
                config["reported_fw_version"] = config["current_fw_version"]
                update_config(config)
    except Exception as e:
        print("Error in update process", e)
        current_firmware_info[FW_STATE_ATTR] = "FAILED"
        sleep(1)
        send_telemetry(current_firmware_info)

import subprocess
import sys
import time
import requests
import platform
import time
import paho.mqtt.client as mqtt
from update import check_updates
from configuration import load_config

def send_telemetry(telemetry_data, auth_token, thingsboard_url):
    headers = {
        "Content-Type": "application/json",
    }
    telemetry_url = f"{thingsboard_url}/api/v1/{auth_token}/telemetry"
    telemetry_data["config"] = load_config()

    try:
        response = requests.post(telemetry_url, headers=headers, json=telemetry_data)
        print(telemetry_data)
        print(f"{response.status_code}")
        print(f"Telemetry sent successfully: {response.text}")
    except requests.RequestException as e:
        print(f"Error sending telemetry data to ThingsBoard: {e}")


def capture_video(camera_index=0, duration=2, output_file="output.mp4"):
    # Determine the OS
    os_type = platform.system()

    # Build command based on OS
    if os_type == "Windows":
        # Use 'video=<camera_name>' format for Windows
        input_device = f"video={camera_index}"
        command = [
            "ffmpeg",
            "-y",
            "-f", "dshow",
            "-i", input_device,
            "-t", str(duration),
            "-s", "1280x720",
            "-r", "15",
            output_file,
        ]
    elif os_type == "Linux":
        # Use '/dev/video<camera_index>' format for Linux
        input_device = f"/dev/video{camera_index}"
        command = [
            "ffmpeg",
            "-y",
            "-f", "v4l2",
            "-i", input_device,
            "-t", str(duration),
            "-s", "1280x720",
            "-r", "15",
            "-loglevel", "error",
            output_file,
        ]
    else:
        print("Unsupported operating system.")
        return False

    # Run command
    try:
        print(' '.join(command))
        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        print("Output:", process.stdout)
        print("Error:", process.stderr)

        print(f"Video saved as {output_file}")
        return True
    except Exception as e:
        print("An error occurred during video capture:", e)
        return False
    
def send_video_to_api(video_file, url, device_id, auth_token):
    headers = {"Device-ID": device_id}
    files = {"video": open(video_file, "rb")}
    try:
        response = requests.post(url + "/upload", headers=headers, files=files)
        print(f"Response from server: {response.text}")
        if response.status_code == 200:
            telemetry_data = response.json()
            return telemetry_data
        else:
            return {"status": 0, "message": "Server error"}
    except Exception as e:
        print(f"An error occurred when sending the video: {e}")
        return {"status": 0, "message": "Device error"}



def action():
    config = load_config()
    camera_name = config["camera_name"]
    api_url = config["api_url"]
    thingsboard_url = config["thingsboard_url"]
    thingsboard_host = config["thingsboard_host"]
    device_id = config["device_id"]
    auth_token = config["auth_token"]
    output_file = config["output_file"]
    enable_video = config["enable_video"]
    
    try:
        check_updates()
    except Exception as e:
        print('Error in update process', e)
    
    if enable_video:
        if capture_video(camera_name, output_file=output_file):
            telemetry_data = send_video_to_api(
                output_file, api_url, device_id, auth_token
            )
    else:
        telemetry_data = {"video_disabled": True}
        
    send_telemetry(telemetry_data, auth_token, thingsboard_url)

if __name__ == "__main__":
    print('start')
    try:
        while True:
            action()
            config = load_config()
            interval = config.get("interval", 60)  # Default to 300 seconds if not set
            time.sleep(interval)
    except Exception as e:
        print('Error', e.with_traceback())
        print('Cleanup done')

    print('Program ended')
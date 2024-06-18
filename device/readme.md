docker build -t device .
docker run --device /dev/video0:/dev/video0 --name device

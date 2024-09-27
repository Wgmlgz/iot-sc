# iot-sc

ssh configs
```
ssh root@192.168.15.146  # for boxprm-test
ssh root@192.168.15.170  # for boxprm-test1
ssh root@192.168.15.151  # for boxprm-test2
ssh root@192.168.15.156  # for boxprm-test3
```

## Installing

- create device in thingsboard 
- assing to asset
- assign profile `cameras`

as root:
``` sh
scp -r ~/iot-sc root@IP_ADDRESS_HERE:~/iot-sc
ssh root@IP_ADDRESS_HERE
cd iot-sc
bash ./install.sh # enter device id and access token when promps
```

## Creating update

``` sh
bash create_package.sh
```

## config 

```
nano /etc/iot-sc/config.json
```

## thingsboard-gateway

```
systemctl restart thingsboard-gateway
systemctl status thingsboard-gateway

journalctl -u thingsboard-gateway.service -b
```
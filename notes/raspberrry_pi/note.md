

# Set up raspberry pi

1. Networkの設定

/etc/wpa_supplicant/wpa_supplicant.conf

2. user変更

/run/sshwarn


## Cross-compile application 

### cross build tools
```
deb http://emdebian.org/tools/debian/ jessie main
curl http://emdebian.org/tools/debian/emdebian-toolchain-archive.key | sudo apt-key add -

sudo dpkg --add-architecture armhf
sudo apt-get update
sudo apt-get install crossbuild-essential-armhf
```


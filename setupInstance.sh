#!/bin/bash
#Tested on Ubuntu 18.04 on GCP

vncPassword=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/vncpass -H "Metadata-Flavor: Google")
username=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/linuxuser -H "Metadata-Flavor: Google")

dpkg --add-architecture i386
curl -O https://storage.googleapis.com/nvidia-drivers-us-public/GRID/GRID10.1/NVIDIA-Linux-x86_64-440.56-grid.run &

apt update
apt upgrade -y
apt install -y dialog pulseaudio libsdl2-image-2.0-0 xserver-xorg-core \
      x11-apps x11-utils mesa-utils xterm xfonts-base tigervnc-common \
      x11-xserver-utils x11vnc icewm steam-installer gcc make python pkg-config-aarch64-linux-gnu 
	
bash NVIDIA-Linux-x86_64-440.56-grid.run -a -q -N --ui=none
nvidia-xconfig --virtual=2560x1600

#TODO: fix this ugly hack for gamepad
chmod 777 /dev/uinput
	
#Download GloriousEgroll
runuser -l $username -c 'wget https://github.com/GloriousEggroll/proton-ge-custom/releases/download/5.4-GE-3/Proton-5.4-GE-3.tar.gz
'
runuser -l $username -c "mkdir /home/$username/.steam"
runuser -l $username -c "mkdir /home/$username/.steam/compatibilitytools.d/"
runuser -l $username -c "tar -C /home/$username/.steam/compatibilitytools.d/ -zxvf Proton-5.4-GE-3.tar.gz"

#Setup VNC password for user
runuser -l $username -c "echo -e '$vncPassword\n$vncPassword\nn' | vncpasswd"

#this is for dummy Xorg screen. Relevant xorg.conf and xserver-xorg-video-dummy needed
#nohup /usr/bin/Xorg -noreset +extension GLX +extension RANDR +extension RENDER -logfile ./10.log -config /root/xorg.conf :1&

nohup Xorg &

#No need to run x11vnc because websockify and novnc will
#nohup x11vnc -loop -forever -repeat -display :0 -rfbport 5901&

#TODO add these as a startup service
nohup runuser -l $username -c 'DISPLAY=:0 icewm-session'&
nohup runuser -l $username -c 'DISPLAY=:0 steam'&

#WEB VNC
#This is used for accessing desktop over web for typing in Steam credentials and troubleshooting
WEBSOCKIFY_VERSION=0.9.0
NOVNC_VERSION=1.1.0

curl -fsSL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz | tar -xzf - -C /opt
curl -fsSL https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.tar.gz | tar -xzf - -C /opt
mv /opt/noVNC-${NOVNC_VERSION} /opt/noVNC
mv /opt/websockify-${WEBSOCKIFY_VERSION} /opt/websockify
ln -s /opt/noVNC/vnc_lite.html /opt/noVNC/index.html
cd /opt/websockify && make
#make self signed certificate
runuser -l $username -c "openssl req -new -x509 -days 365 -nodes -subj '/C=TR/emailAddress=a/ST=a/L=a/O=a/OU=a/CN=a' -out /home/$username/self.pem -keyout /home/$username/self.pem"
nohup runuser -l $username -c '/opt/websockify/run 5901 --cert=./self.pem --ssl-only --web=/opt/noVNC --wrap-mode=ignore -- x11vnc  -usepw -display :0 -rfbport 5901 -loop -forever -repeat -noxdamage'&

#TODO add websockify-vnc as a service to run at startup, this is useful after a reboot

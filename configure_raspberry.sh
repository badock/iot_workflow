#!/usr/bin/env bash

set -eu
set -x

############################################################
# Dependencies management
############################################################
apt-get install -y unzip wget

############################################################
# CONFIGURE CONSUL
############################################################

# Download and install consul
if [ ! -f /usr/local/bin/consul ]; then
    if [ -f consul_0.8.0_linux_arm.zip ]; then
        rm consul_0.8.0_linux_arm.zip
    fi
    wget https://releases.hashicorp.com/consul/0.8.0/consul_0.8.0_linux_arm.zip
    unzip -u consul_0.8.0_linux_arm.zip
    mv consul /usr/local/bin/consul
fi

# Create a dedicated folder for consul
if [ ! -d /etc/consul.d ]; then
    mkdir /etc/consul.d
fi

# Ensure that the systemd's system folder exists
if [ ! -d /etc/systemd/system ]; then
    mkdir -p /etc/systemd/system
fi

# Configure Consul as a systemd service
cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description=consul agent
Wants=network.target

[Service]
EnvironmentFile=-/etc/sysconfig/consul
Environment=GOMAXPROCS=2
Restart=always
RestartSec=3
ExecStart=/usr/local/bin/consul agent -bind 0.0.0.0 -ui -dev
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

# Run the consul service at startup
sudo systemctl enable consul.service || true

############################################################
# CONFIGURE NODERED
############################################################

# Download and install NodeRED
if [ ! -f /usr/bin/node-red ]; then
    # NodeRED is packaged with Raspbian since "Raspbian Jessie"
    :
fi

# Configure NodeRED as a systemd service
cat << EOF > /etc/systemd/system/nodered.service
[Unit]
Description=Node-RED graphical event wiring tool.
Wants=network.target
Documentation=http://nodered.org/docs/hardware/raspberrypi.html

[Service]
Type=simple
# Run as normal pi user - feel free to change...
User=pi
Group=pi
WorkingDirectory=/home/pi
Nice=5
Environment="NODE_OPTIONS=--max-old-space-size=128"
# uncomment and edit next line if you need an http proxy
#Environment="HTTP_PROXY=my.httpproxy.server.address"
# uncomment the next line for a more verbose log output
#Environment="NODE_RED_OPTIONS=-v"
#ExecStart=/usr/bin/env node \$NODE_OPTIONS red.js \$NODE_RED_OPTIONS
ExecStart=/usr/bin/env node-red-pi \$NODE_OPTIONS \$NODE_RED_OPTIONS
# Use SIGINT to stop
KillSignal=SIGINT
# Auto restart on crash
Restart=on-failure
# Tag things in the log
SyslogIdentifier=Node-RED
#StandardOutput=syslog

[Install]
WantedBy=multi-user.target
EOF

# Run the NodeRED service at startup
sudo systemctl enable nodered.service || true

############################################################
# COMMON ACTIONS
############################################################

# Reload systemd's daemons
systemctl daemon-reload

# Disable wifi power management
if ! grep -Fxq "wireless-power off" /etc/network/interfaces; then
    echo "wireless-power off" >> /etc/network/interfaces
fi

exit 0

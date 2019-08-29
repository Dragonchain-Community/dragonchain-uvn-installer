#!/bin/bash

# Variables
DRAGONCHAIN_UVN_NODE_PORT=30000
LOG_FILE=/home/ubuntu/drgn.log

# Generate logfile
touch $LOG_FILE

#Patch our system current [stable]
sudo apt-get update >> $LOG_FILE 2>&1
sudo apt-get upgrade -y >> $LOG_FILE 2>&1

# Make vm.max_map change current and for next reboot
# https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html
SYSCTL_CONF_MOD="vm.max_map_count=262144"
echo $SYSCTL_CONF_MOD| sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -w vm.max_map=262144 >> $LOG_FILE 2>&1

# Install jq, openssl, xxd
sudo apt-get install -y jq openssl xxd >> $LOG_FILE 2>&1

# Install microk8s classic via snap package
sudo snap install microk8s --classic >> $LOG_FILE 2>&1

# Because we have microk8s, we need to alias kubectl
sudo snap alias microk8s.kubectl kubectl >> $LOG_FILE 2>&1

# Setup firewall rules
# This should be reviewed - confident we can restrict this further
sudo ufw default allow routed >> $LOG_FILE 2>&1
sudo ufw default allow outgoing >> $LOG_FILE 2>&1
sudo ufw allow $DRAGONCHAIN_UVN_NODE_PORT/tcp >> $LOG_FILE 2>&1
sudo ufw allow in on cbr0 >> $LOG_FILE 2>&1
sudo ufw allow out on cbr0 >> $LOG_FILE 2>&1

# Enable Microk8s modules
sudo microk8s.enable dns >> $LOG_FILE 2>&1
sudo microk8s.enable storage >> $LOG_FILE 2>&1
sudo microk8s.enable helm  >> $LOG_FILE 2>&1

# Install helm classic via snap package
sudo snap install helm --classic >> $LOG_FILE 2>&1

# Initialize helm
sudo helm init --history-max 200 >> $LOG_FILE 2>&1

# Install more Microk8s modules
sudo microk8s.enable registry >> $LOG_FILE 2>&1
sudo microk8s.enable ingress >> $LOG_FILE 2>&1
sudo microk8s.enable fluentd >> $LOG_FILE 2>&1
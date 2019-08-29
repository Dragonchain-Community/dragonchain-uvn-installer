#!/bin/bash

# Variables
DRAGONCHAIN_NODE_PORT=30000

#Patch our system current [stable]
sudo apt-get update
sudo apt-get upgrade -y

# Make vm.max_map change current and for next reboot
# https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html
SYSCTL_CONF_MOD="vm.max_map=262144"
sudo echo $SYSCTL_CONF_MOD >> /etc/sysctl.conf
sudo sysctl -w vm.max_map=262144

# Install jq, openssl, xxd
sudo apt-get install -y jq openssl xxd

# Install microk8s classic via snap package
sudo snap install microk8s --classic

# Because we have microk8s, we need to alias kubectl
sudo snap alias microk8s.kubectl kubectl

# Setup firewall rules
# This should be reviewed - confident we can restrict this further
sudo ufw default allow routed
sudo ufw default allow outgoing
sudo ufw allow $DRAGONCHAIN_NODE_PORT/tcp
sudo ufw allow in on cbr0
sudo ufw allow out on cbr0

# Enable Microk8s modules
sudo microk8s.enable dns
sudo microk8s.enable storage
sudo microk8s.enable helm  #duck ; is this necessary? enable before installing? wtf

# Install helm classic via snap package
sudo snap install helm --classic

# Initialize helm
sudo helm init --history-max 200

# Install more Microk8s modules
sudo microk8s.enable registry
sudo microk8s.enable ingress
sudo microk8s.enable fluentd


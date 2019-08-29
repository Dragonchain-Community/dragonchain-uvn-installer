#!/bin/bash

## Assumptions
## Run on Ubuntu 18.04 LTS from AWS (probably will work on others but may be missing )

# Variables
REQUIRED_COMMANDS="sudo ls grep chmod tee sed touch cd"
LOG_FILE=/home/ubuntu/drgn.log
SECURE_LOG_FILE=/home/ubuntu/secure.drgn.log

SYSCTL_CONF_MOD="vm.max_map_count=262144"

#Variables may be in .config or from user input
DRAGONCHAIN_UVN_NODE_PORT=30000 #duck need to source this from config file

##########################################################################
## Function errchk
## $1 should be $? from the command being checked
## $2 should be the command executed
## When passing $2, do not forget to escape any ""
errchk() {
    if [ "$1" -ne 0 ] ; then
        printf "\nERROR: RC=%s; CMD=%s\n" "$1" "$2"
        exit $1
    fi
    printf "\nPASS: %s\n" "$2"
}

##########################################################################
## Function cmd_exists
cmd_exists() {
    if command -v "$1" >/dev/null 2>&1
    then
        return 0
    else
        return 1
    fi
}

##########################################################################
## Function preflight_check
preflight_check() {
    #duck
    # Generate logfiles
    touch $LOG_FILE >/dev/null 2>&1
    errchk $? "touch $LOG_FILE"
    touch $SECURE_LOG_FILE >/dev/null 2>&1
    errchk $? "touch $SECURE_LOG_FILE >/dev/null 2>&1"

    # assume user executing is ubuntu with sudo privs
    mkdir /home/ubuntu/setup
    errchk $? "mkdir /home/ubuntu/setup"
    cd /home/ubuntu/setup
    errchk $? "cd /home/ubuntu/setup"

    # Check for existance of necessary commands
    for CMD in $REQUIRED_COMMANDS ; do
        if ! cmd_exists "$CMD" ; then
            printf "ERROR: Command '%s' was not found and is required. Cannot proceed further.\n"
            printf "Please install with apt-get install '%s'\n"
            exit 1
        fi
    done
}

##########################################################################
## Function patch_server_current
patch_server_current() {
    #Patch our system current [stable]
    sudo apt-get update >> $LOG_FILE 2>&1
    errchk $? "sudo apt-get update >> $LOG_FILE 2>&1"

    sudo apt-get upgrade -y >> $LOG_FILE 2>&1
    errchk $? "sudo apt-get upgrade -y >> $LOG_FILE 2>&1"
}

##########################################################################
## Function bootstrap_environment
bootstrap_environment(){
    #duck
    # Make vm.max_map change current and for next reboot
    # https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html
    echo $SYSCTL_CONF_MOD| sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -w vm.max_map=262144 >> $LOG_FILE 2>&1
    errchk $? "sudo sysctl -w vm.max_map=262144 >> $LOG_FILE 2>&1"

    # Install jq, openssl, xxd
    sudo apt-get install -y jq openssl xxd >> $LOG_FILE 2>&1
    errchk $? "sudo apt-get install -y jq openssl xxd >> $LOG_FILE 2>&1"

    # Install microk8s classic via snap package
    sudo snap install microk8s --classic >> $LOG_FILE 2>&1
    errchk $? "sudo snap install microk8s --classic >> $LOG_FILE 2>&1"

    # Because we have microk8s, we need to alias kubectl
    sudo snap alias microk8s.kubectl kubectl >> $LOG_FILE 2>&1
    errchk $? "sudo snap alias microk8s.kubectl kubectl >> $LOG_FILE 2>&1"

    # Setup firewall rules
    # This should be reviewed - confident we can restrict this further
    sudo ufw default allow routed >> $LOG_FILE 2>&1
    errchk $? "sudo ufw default allow routed >> $LOG_FILE 2>&1"

    sudo ufw default allow outgoing >> $LOG_FILE 2>&1
    errchk $? "sudo ufw default allow outgoing >> $LOG_FILE 2>&1"

    sudo ufw allow $DRAGONCHAIN_UVN_NODE_PORT/tcp >> $LOG_FILE 2>&1
    errchk $? "sudo ufw allow $DRAGONCHAIN_UVN_NODE_PORT/tcp >> $LOG_FILE 2>&1"

    sudo ufw allow in on cbr0 >> $LOG_FILE 2>&1
    errchk $? "sudo ufw allow in on cbr0 >> $LOG_FILE 2>&1"

    sudo ufw allow out on cbr0 >> $LOG_FILE 2>&1
    errchk $? "sudo ufw allow out on cbr0 >> $LOG_FILE 2>&1"

    # Enable Microk8s modules
    sudo microk8s.enable dns >> $LOG_FILE 2>&1
    errchk $? "sudo microk8s.enable dns >> $LOG_FILE 2>&1"

    sudo microk8s.enable storage >> $LOG_FILE 2>&1
    errchk $? "sudo microk8s.enable storage >> $LOG_FILE 2>&1"

    sudo microk8s.enable helm  >> $LOG_FILE 2>&1
    errchk $? "sudo microk8s.enable helm  >> $LOG_FILE 2>&1"

    # Install helm classic via snap package
    sudo snap install helm --classic >> $LOG_FILE 2>&1
    errchk $? "sudo snap install helm --classic >> $LOG_FILE 2>&1"

    # Initialize helm
    sudo helm init --history-max 200 >> $LOG_FILE 2>&1
    errchk $? "sudo helm init --history-max 200 >> $LOG_FILE 2>&1"

    # Install more Microk8s modules
    sudo microk8s.enable registry >> $LOG_FILE 2>&1
    errchk $? "sudo microk8s.enable registry >> $LOG_FILE 2>&1"

    sudo microk8s.enable ingress >> $LOG_FILE 2>&1
    errchk $? "sudo microk8s.enable ingress >> $LOG_FILE 2>&1"

    sudo microk8s.enable fluentd >> $LOG_FILE 2>&1
    errchk $? "sudo microk8s.enable fluentd >> $LOG_FILE 2>&1"
}

##########################################################################
## Function generate_chainsecrets
generate_chainsecrets(){
    #duck - rewrite this piece, no need to generate a file and execute
    # generate setup_chainsecrets.sh script to be executed
    # need \ before $"" and $() ; compare to template in 'code' to verify accuracy of cmds
    # https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_07_04
    # # This will be a problem if $DRAGONCHAIN_UVN_NODE_NAME has a space in it!!
    cat <<EOF >setup_chainsecrets.sh
    #!/bin/bash
    # First create the dragonchain namespace
    echo '{"kind":"Namespace","apiVersion":"v1","metadata":{"name":"dragonchain","labels":{"name":"dragonchain"}}}' | kubectl create -f -
    export LC_CTYPE=C  # Needed on MacOS when using tr with /dev/urandom
    BASE_64_PRIVATE_KEY=\$(openssl ecparam -genkey -name secp256k1 | openssl ec -outform DER | tail -c +8 | head -c 32 | xxd -p -c 32 | xxd -r -p | base64)
    HMAC_ID=\$(tr -dc 'A-Z' < /dev/urandom | fold -w 12 | head -n 1)
    HMAC_KEY=\$(tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 43 | head -n 1)
    echo "Root HMAC key details: ID: \$HMAC_ID | KEY: \$HMAC_KEY"
    SECRETS_AS_JSON="{\"private-key\":\"\$BASE_64_PRIVATE_KEY\",\"hmac-id\":\"\$HMAC_ID\",\"hmac-key\":\"\$HMAC_KEY\",\"registry-password\":\"\"}"
    kubectl create secret generic -n dragonchain "d-$DRAGONCHAIN_UVN_NODE_NAME-secrets" --from-literal=SecretString="\$SECRETS_AS_JSON"
    # Note INTERNAL_ID from the secret name should be replaced with the value of .global.environment.INTERNAL_ID from the helm chart values (opensource-config.yaml)
EOF

    # Make executable
    chmod u+x setup_chainsecrets.sh
    ./setup_chainsecrets.sh >> $SECURE_LOG_FILE 2>&1

    # harvest keys for later use
    #TODO

    # output from generated script above ; we need to capture ROOT HMAC KEY for later!
    ## ./setup_chainsecrets.sh
    ## The connection to the server localhost:8080 was refused - did you specify the right host or port?
    ## read EC key
    ## writing EC key
    ## Root HMAC key details: ID: XXFRZZOJWAAJ | KEY: AjEHkGntNVxvMTgFMiolSJXwKgkiUzg2lJ9dMCjIdUp
    ## The connection to the server localhost:8080 was refused - did you specify the right host or port?
}

##########################################################################
## Function download_dragonchain
download_dragonchain(){
    #duck what is pwd?
    cd /home/ubuntu/setup
    errchk $? "cd /home/ubuntu/setup"
    # Download latest Helm chart and values
    # https://dragonchain-core-docs.dragonchain.com/latest/deployment/links.html
    #duck this probably isn't always going to be the latest
    wget https://dragonchain-core-docs.dragonchain.com/latest/_downloads/d4c3d7cc2b271faa6e8e75167e6a54af/dragonchain-k8s-0.9.0.tgz
    wget https://dragonchain-core-docs.dragonchain.com/latest/_downloads/604d88c35bc090d29fe98a9e8e4b024e/opensource-config.yaml
}

##########################################################################
## Function customize_dragonchain_uvm_yaml
customize_dragonchain_uvm_yaml(){
    #duck
    # Modify opensource-config.yaml to our nodes specifications
    # 1. ArbitraryName with nodename for sanity sake
    # 2. REGISTRATION_TOKEN = "MATCHMAKING_TOKEN_FROM_CONSOLE"
    # 3. REPLACE INTERNAL_ID WITH CHAIN_ID FROM CONSOLE
    # 4. REPLACE DRAGONCHAIN_ENDPOINT with user address
    # 5. CHANGE LEVEL TO 2
    # 6. CHANGE 2 LINES FROM "storageClassName: standard" TO "storageClassName: microk8s-hostpath"
    # 7. CHANGE 1 LINE FROM "storageClass: standard" TO "storageClass: microk8s-hostpath"

    # 1. ArbitraryName with nodename for sanity sake
    sed -i "s/ArbitraryName/$DRAGONCHAIN_UVN_NODE_NAME/g" opensource-config.yaml
    errchk $? "sed #1"

    # 2. REGISTRATION_TOKEN = "MATCHMAKING_TOKEN_FROM_CONSOLE"
    sed -i "s/REGISTRATION\_TOKEN\:\ \"\"/REGISTRATION\_TOKEN\:\ \""$DRAGONCHAIN_UVN_REGISTRATION_TOKEN"\"/g" opensource-config.yaml
    errchk $? "sed #2"

    # 3. REPLACE INTERNAL_ID WITH CHAIN_ID FROM CONSOLE
    sed -i "s/INTERNAL\_ID\:\ \"\"/INTERNAL\_ID\:\ \""$DRAGONCHAIN_UVN_INTERNAL_ID"\"/g" opensource-config.yaml
    errchk $? "sed #3"

    # 4. REPLACE DRAGONCHAIN_ENDPOINT with user address
    # this scenario is difficult with sed because the variable will contain // and potentially more characters

    # 5. CHANGE LEVEL TO 2
    sed -i 's/LEVEL\:\ \"1/LEVEL\:\ \"2/g' opensource-config.yaml
    errchk $? "sed #5"

    # 6. CHANGE 2 LINES FROM "storageClassName: standard" TO "storageClassName: microk8s-hostpath"
    sed -i 's/storageClassName\:\ standard/storageClassName\:\ microk8s\-hostpath/g' opensource-config.yaml
    errchk $? "sed #6"

    # 7. CHANGE 1 LINE FROM "storageClass: standard" TO "storageClass: microk8s-hostpath"
    sed -i 's/storageClass\:\ standard/storageClass\:\ microk8s\-hostpath/g' opensource-config.yaml
    errchk $? "sed #7"
}


## Main()

#check for required commands, setup logging
preflight_check

#patch system current
patch_server_current

#install necessary software, set tunables
bootstrap_environment

# Check for argument for user to enter node details on command line or read unmanaged_verification_node.config
# Source our umanaged_verification_node.config
#chmod u+x unmanaged_verification_node.config
#. ./unmanaged_verification_node.config

# must gather node details from user or .config before generating chainsecrets
generate_chainsecrets
download_dragonchain
customize_dragonchain_uvm_yaml

# Deploy Helm Chart
sudo helm upgrade --install SOMETHING_HERE dragonchain-k8s-0.9.0.tgz --values opensource-config.yaml dragonchain

exit 0


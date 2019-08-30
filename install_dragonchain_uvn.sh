#!/bin/bash

## Assumptions
## Run on Ubuntu 18.04 LTS from AWS (probably will work on others but may be missing )

# Variables
DRAGONCHAIN_VERSION="3.5.0"
DRAGONCHAIN_HELM_CHART_URL="https://dragonchain-core-docs.dragonchain.com/latest/_downloads/d4c3d7cc2b271faa6e8e75167e6a54af/dragonchain-k8s-0.9.0.tgz"
DRAGONCHAIN_HELM_VALUES_URL="https://dragonchain-core-docs.dragonchain.com/latest/_downloads/604d88c35bc090d29fe98a9e8e4b024e/opensource-config.yaml"

REQUIRED_COMMANDS="sudo ls grep chmod tee sed touch cd timeout ufw"
#duck note: would just assume keep any files generated in a subfolder of the executing directory
LOG_FILE=./dragonchain-setup/drgn.log
SECURE_LOG_FILE=./dragonchain-setup/secure.drgn.log

#Variables may be in .config or from user input

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

    # assume user executing is ubuntu with sudo privs
    if [ -e ./dragonchain-setup ]; then
        rm -r ./dragonchain-setup >/dev/null 2>&1
        mkdir ./dragonchain-setup
        errchk $? "mkdir ./dragonchain-setup"
    else
        mkdir ./dragonchain-setup
        errchk $? "mkdir ./dragonchain-setup"
    fi

    # Test for sudo without password prompts. This is by no means exhaustive.
    # Sudo can be configured many different ways and extensive sudo testing is beyond the scope of this effort
    # There are may ways sudo could be configured in this simple example we expect:
    # ubuntu ALL=(ALL) NOPASSWD:ALL #where 'ubuntu' could be any user
    if timeout -s SIGKILL 2 sudo ls -l /tmp >/dev/null 2>&1 ; then
        printf "PASS: Sudo configuration in place\n"
    else
        printf "\nERROR: Sudo configuration may not be ideal for this setup. Exiting.\n"
        exit 1
    fi

    # Generate logfiles
    touch $LOG_FILE >/dev/null 2>&1
    errchk $? "touch $LOG_FILE >/dev/null 2>&1"
    touch $SECURE_LOG_FILE >/dev/null 2>&1
    errchk $? "touch $SECURE_LOG_FILE >/dev/null 2>&1"

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
## Function request_user_defined_values
request_user_defined_values() {
   # Collect user-configured fields
   # TODO: Sanitize all inputs

   echo -e "\e[33mEnter your Chain ID from the Dragonchain console:\e[0m"
   read DRAGONCHAIN_UVN_INTERNAL_ID
   echo

   echo -e "\e[33mEnter your Matchmaking Token from the Dragonchain console:\e[0m"
   read DRAGONCHAIN_UVN_REGISTRATION_TOKEN
   echo

   echo -e "\e[33mEnter a name for your Dragonchain node (lowercase letters, numbers, or dashes):\e[0m"
   read DRAGONCHAIN_UVN_NODE_NAME
   echo

   echo -e "\e[33mEnter the endpoint URL for your Dragonchain node WITHOUT the port:\e[0m"
   echo -e "\e[31mDON'T forget the http:// or https://\e[0m"
   echo -e "\e[2mExample with domain name: http://yourdomainname.com\e[0m"
   echo -e "\e[2mExample with IP address: http://12.34.56.78\e[0m"
   read DRAGONCHAIN_UVN_ENDPOINT_URL
   echo

   echo -e "\e[33mEnter the endpoint PORT for your Dragonchain node (must be between 30000 and 32767):\e[0m"
   read DRAGONCHAIN_UVN_NODE_PORT
   echo
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

    #duck note: might want to check the .conf file for this line to already exist before adding again

    echo "vm.max_map_count=262144"| sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -w vm.max_map_count=262144 >> $LOG_FILE 2>&1
    errchk $? "sudo sysctl -w vm.max_map_count=262144 >> $LOG_FILE 2>&1"

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

    #duck note: running it outright; TODO: write HMAC_ID and HMAC_KEY to secure log file

    echo '{"kind":"Namespace","apiVersion":"v1","metadata":{"name":"dragonchain","labels":{"name":"dragonchain"}}}' | kubectl create -f -
    export LC_CTYPE=C  # Needed on MacOS when using tr with /dev/urandom
    BASE_64_PRIVATE_KEY=$(openssl ecparam -genkey -name secp256k1 | openssl ec -outform DER | tail -c +8 | head -c 32 | xxd -p -c 32 | xxd -r -p | base64)
    HMAC_ID=$(tr -dc 'A-Z' < /dev/urandom | fold -w 12 | head -n 1)
    HMAC_KEY=$(tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 43 | head -n 1)
    SECRETS_AS_JSON="{\"private-key\":\"$BASE_64_PRIVATE_KEY\",\"hmac-id\":\"$HMAC_ID\",\"hmac-key\":\"$HMAC_KEY\",\"registry-password\":\"\"}"
    kubectl create secret generic -n dragonchain "d-INTERNAL_ID-secrets" --from-literal=SecretString="$SECRETS_AS_JSON"
    # Note INTERNAL_ID from the secret name should be replaced with the value of .global.environment.INTERNAL_ID from the helm chart values (opensource-config.yaml)

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
    #duck note: just assume keep downloads and script files in the same directory (wherever the user runs the script)

    # Download latest Helm chart and values
    # https://dragonchain-core-docs.dragonchain.com/latest/deployment/links.html
    #duck this probably isn't always going to be the latest
    #duck note: switched to variable values with hard versioning
    wget -P ./dragonchain-setup/ $DRAGONCHAIN_HELM_CHART_URL
    wget -P ./dragonchain-setup/ $DRAGONCHAIN_HELM_VALUES_URL
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
    sed -i "s/ArbitraryName/$DRAGONCHAIN_UVN_NODE_NAME/g" ./dragonchain-setup/opensource-config.yaml
    errchk $? "sed #1"

    # 2. REGISTRATION_TOKEN = "MATCHMAKING_TOKEN_FROM_CONSOLE"
    sed -i "s/REGISTRATION\_TOKEN\:\ \"\"/REGISTRATION\_TOKEN\:\ \""$DRAGONCHAIN_UVN_REGISTRATION_TOKEN"\"/g" ./dragonchain-setup/opensource-config.yaml
    errchk $? "sed #2"

    # 3. REPLACE INTERNAL_ID WITH CHAIN_ID FROM CONSOLE
    sed -i "s/INTERNAL\_ID\:\ \"\"/INTERNAL\_ID\:\ \""$DRAGONCHAIN_UVN_INTERNAL_ID"\"/g" ./dragonchain-setup/opensource-config.yaml
    errchk $? "sed #3"

    # 4. REPLACE DRAGONCHAIN_ENDPOINT with user address
    # modify sed to use # as separator
    # https://backreference.org/2010/02/20/using-different-delimiters-in-sed/ ; Thanks Bill
    sed -i "s#https://my-chain.api.company.org:443#$DRAGONCHAIN_UVN_ENDPOINT_URL:$DRAGONCHAIN_UVN_NODE_PORT#" ./dragonchain-setup/opensource-config.yaml
    errchk $? "sed #4"

    # 5. CHANGE LEVEL TO 2
    sed -i 's/LEVEL\:\ \"1/LEVEL\:\ \"2/g' ./dragonchain-setup/opensource-config.yaml
    errchk $? "sed #5"

    # 6. CHANGE 2 LINES FROM "storageClassName: standard" TO "storageClassName: microk8s-hostpath"
    sed -i 's/storageClassName\:\ standard/storageClassName\:\ microk8s\-hostpath/g' ./dragonchain-setup/opensource-config.yaml
    errchk $? "sed #6"

    # 7. CHANGE 1 LINE FROM "storageClass: standard" TO "storageClass: microk8s-hostpath"
    sed -i 's/storageClass\:\ standard/storageClass\:\ microk8s\-hostpath/g' ./dragonchain-setup/opensource-config.yaml
    errchk $? "sed #7"
}


## Main()

#check for required commands, setup logging
preflight_check

#gather user defined values
request_user_defined_values

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
sudo helm upgrade --install $DRAGONCHAIN_UVN_NODE_NAME ./dragonchain-setup/dragonchain-k8s-0.9.0.tgz --values ./dragonchain-setup/opensource-config.yaml dragonchain

exit 0


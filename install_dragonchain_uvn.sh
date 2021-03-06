#!/bin/bash
``
## Assumptions
## Run on Ubuntu 18.04 LTS from AWS (probably will work on others but may be missing)

# Variables
REQUIRED_COMMANDS="sudo ls grep chmod tee sed touch cd timeout ufw savelog wget curl"

#Variables may be in .config or from user input

##########################################################################
## Function errchk
## $1 should be $? from the command being checked
## $2 should be the command executed
## When passing $2, do not forget to escape any ""
errchk() {
    if [ "$1" -ne 0 ]; then
        printf "\nERROR: RC=%s; CMD=%s\n" "$1" "$2" >>$LOG_FILE
        printf "\nERROR: RC=%s; CMD=%s\n" "$1" "$2"
        exit "$1"
    fi
    printf "\nPASS: %s\n" "$2" >>$LOG_FILE
}

##########################################################################
## Function cmd_exists
cmd_exists() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

##########################################################################
## Function trim
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

##########################################################################
## Progress spinner
spinner() {
    local pid=$!
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

##########################################################################
## Function prompt_node_name
prompt_node_name() {
    echo -e "\n\e[94mEnter a Dragonchain UVN name:\e[0m"
    echo -e "\e[2mThe name must be unique if you intend to run multiple UVNs\e[0m"
    echo -e "\e[2mThe name can contain numbers, lowercase characters and '-' ONLY\e[0m"
    echo -e "\e[2mTo upgrade, repair or delete a specific UVN, type the name of that installation\e[0m"

    read -e DRAGONCHAIN_INSTALLER_DIR

    LOG_FILE=$DRAGONCHAIN_INSTALLER_DIR/dragonchain_uvn_installer.log
    SECURE_LOG_FILE=$DRAGONCHAIN_INSTALLER_DIR/dragonchain_uvn_installer.secure.log
}

##########################################################################
## Function preflight_check
preflight_check() {
    # Check for existance of necessary commands
    for CMD in $REQUIRED_COMMANDS; do
        if ! cmd_exists "$CMD"; then
            printf "ERROR: Command '%s' was not found and is required. Cannot proceed further.\n" "$CMD"
            printf "Please install with apt-get install '%s'\n" "$CMD"
            exit 1
        fi
    done

    # Create the installer directory
    if [ ! -e $DRAGONCHAIN_INSTALLER_DIR ]; then
        mkdir -p $DRAGONCHAIN_INSTALLER_DIR
        errchk $? "mkdir -p $DRAGONCHAIN_INSTALLER_DIR"
    fi

    # Generate logfiles & rotate as appropriate
    if [ ! -e $LOG_FILE ]; then
        touch $LOG_FILE >/dev/null 2>&1
        errchk $? "touch $LOG_FILE >/dev/null 2>&1"
    else
        savelog -t -c 5 -l -p -n -q $LOG_FILE
    fi
    if [ ! -e $SECURE_LOG_FILE ]; then
        touch $SECURE_LOG_FILE >/dev/null 2>&1
        errchk $? "touch $SECURE_LOG_FILE >/dev/null 2>&1"
    else
        savelog -t -c 5 -l -p -n -q $SECURE_LOG_FILE
    fi

    # Test for sudo without password prompts. This is by no means exhaustive.
    # Sudo can be configured many different ways and extensive sudo testing is beyond the scope of this effort
    # There are may ways sudo could be configured in this simple example we expect:
    # ubuntu ALL=(ALL) NOPASSWD:ALL #where 'ubuntu' could be any user
    if timeout -s SIGKILL 2 sudo ls -l /tmp >/dev/null 2>&1; then
        printf "PASS: Sudo configuration in place\n" >>$LOG_FILE
    else
        printf "\nERROR: Sudo configuration may not be ideal for this setup. Exiting.\n" >>$LOG_FILE
        exit 1
    fi

    # assume user executing is ubuntu with sudo privs
    if [ -e $DRAGONCHAIN_INSTALLER_DIR/dragonchain-setup ]; then
        rm -r $DRAGONCHAIN_INSTALLER_DIR/dragonchain-setup >/dev/null 2>&1
        mkdir $DRAGONCHAIN_INSTALLER_DIR/dragonchain-setup
        errchk $? "mkdir $DRAGONCHAIN_INSTALLER_DIR/dragonchain-setup"
    else
        mkdir $DRAGONCHAIN_INSTALLER_DIR/dragonchain-setup
        errchk $? "mkdir $DRAGONCHAIN_INSTALLER_DIR/dragonchain-setup"
    fi
}

##########################################################################
## Function set_config_values
function set_config_values() {
    if [ -f $DRAGONCHAIN_INSTALLER_DIR/.config ]; then
        # Execute config file
        . $DRAGONCHAIN_INSTALLER_DIR/.config

        echo -e "\n\e[93mSaved Dragonchain UVN configuration values found:\e[0m"
        echo "Namespace = $DRAGONCHAIN_INSTALLER_DIR"
        echo "Name = $DRAGONCHAIN_UVN_NODE_NAME"
        echo "Chain ID = $DRAGONCHAIN_UVN_INTERNAL_ID"
        echo "Matchmaking Token = $DRAGONCHAIN_UVN_REGISTRATION_TOKEN"
        echo "Endpoint URL = $DRAGONCHAIN_UVN_ENDPOINT_URL"
        echo "Endpoint Port = $DRAGONCHAIN_UVN_NODE_PORT"
        echo "Node Level = $DRAGONCHAIN_UVN_NODE_LEVEL"
        echo

        # Prompt user about whether to use saved values
        #duck Maybe just add a flag to bypass this for automated installation?
        local ANSWER=""
        while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]; do
            echo -e "\e[93mUse saved UVN configuration? [yes or no]\e[0m"
            read ANSWER
            echo
        done

        if [[ "$ANSWER" == "n" || "$ANSWER" == "no" ]]; then
            # User wants fresh values
            request_user_defined_values
        fi
    else
        # No saved config, request values
        request_user_defined_values
    fi
}

##########################################################################
## Function request_user_defined_values
request_user_defined_values() {

    # Reset all values in case they were set in config check
    DRAGONCHAIN_UVN_INTERNAL_ID=""
    DRAGONCHAIN_UVN_REGISTRATION_TOKEN=""
    DRAGONCHAIN_UVN_NODE_NAME=""
    DRAGONCHAIN_UVN_ENDPOINT_URL=""
    DRAGONCHAIN_UVN_NODE_PORT=""
    DRAGONCHAIN_UVN_NODE_LEVEL=""

    # Collect user-configured fields
    # TODO: Sanitize all inputs

    echo -e "\n\e[94mEnter your Chain ID from the Dragonchain console:\e[0m"
    read DRAGONCHAIN_UVN_INTERNAL_ID
    DRAGONCHAIN_UVN_INTERNAL_ID=$(echo $DRAGONCHAIN_UVN_INTERNAL_ID | tr -d '\r')
    echo

    echo -e "\e[94mEnter your Matchmaking Token from the Dragonchain console:\e[0m"
    read DRAGONCHAIN_UVN_REGISTRATION_TOKEN
    DRAGONCHAIN_UVN_REGISTRATION_TOKEN=$(echo $DRAGONCHAIN_UVN_REGISTRATION_TOKEN | tr -d '\r')
    echo

    # Create a new node name
    DRAGONCHAIN_UVN_NODE_NAME=$(date +"%s")
    DRAGONCHAIN_UVN_NODE_NAME="dc-$DRAGONCHAIN_UVN_NODE_NAME"

    while [[ ! $DRAGONCHAIN_UVN_ENDPOINT_URL =~ ^(https?)://[A-Za-z0-9.-]+$ ]]; do
        if [[ ! -z "$DRAGONCHAIN_UVN_ENDPOINT_URL" ]]; then
            echo -e "\e[91mInvalid endpoint URL entered!\e[0m"
        fi

        echo -e "\e[94mEnter the endpoint URL for your Dragonchain UVN WITHOUT the port:\e[0m"
        echo -e "\e[93mStart with http:// (or https:// if you know you've configured SSL)\e[0m"
        echo -e "\e[2mExample with domain name: http://yourdomainname.com\e[0m"
        echo -e "\e[2mExample with IP address: http://12.34.56.78\e[0m"
        read DRAGONCHAIN_UVN_ENDPOINT_URL
        DRAGONCHAIN_UVN_ENDPOINT_URL=$(echo $DRAGONCHAIN_UVN_ENDPOINT_URL | tr -d '\r')
        echo
    done

    while [[ ! "$DRAGONCHAIN_UVN_NODE_PORT" =~ ^[0-9]+$ ]] || ((DRAGONCHAIN_UVN_NODE_PORT < 30000 || DRAGONCHAIN_UVN_NODE_PORT > 32767)); do
        if [[ ! -z "$DRAGONCHAIN_UVN_NODE_PORT" ]]; then
            echo -e "\e[91mInvalid port number entered!\e[0m"
        fi

        echo -e "\e[94mEnter the endpoint PORT for your Dragonchain UVN (must be between 30000-32767):\e[0m"
        read DRAGONCHAIN_UVN_NODE_PORT
        DRAGONCHAIN_UVN_NODE_PORT=$(echo $DRAGONCHAIN_UVN_NODE_PORT | tr -d '\r')
        echo
    done

    while [[ ! "$DRAGONCHAIN_UVN_NODE_LEVEL" =~ ^[0-9]+$ ]] || ((DRAGONCHAIN_UVN_NODE_LEVEL < 2 || DRAGONCHAIN_UVN_NODE_LEVEL > 4)); do
        if [[ ! -z "$DRAGONCHAIN_UVN_NODE_LEVEL" ]]; then
            echo -e "\e[91mInvalid node level entered!\e[0m"
        fi

        echo -e "\e[94mEnter the node level for your Dragonchain UVN (must be 2, 3 or 4):\e[0m"
        read DRAGONCHAIN_UVN_NODE_LEVEL
        DRAGONCHAIN_UVN_NODE_LEVEL=$(echo $DRAGONCHAIN_UVN_NODE_LEVEL | tr -d '\r')
    done

    #duck Moved node port firewall rule here in order to run bootstrap before this parameter is created
    sleep 2
    sudo ufw allow $DRAGONCHAIN_UVN_NODE_PORT/tcp >>$LOG_FILE 2>&1
    errchk $? "sudo ufw allow $DRAGONCHAIN_UVN_NODE_PORT/tcp >> $LOG_FILE 2>&1"
    sleep 2

    # Write a fresh config file with user-defined values
    rm -f $DRAGONCHAIN_INSTALLER_DIR/.config
    touch $DRAGONCHAIN_INSTALLER_DIR/.config

    echo "DRAGONCHAIN_UVN_INTERNAL_ID=$DRAGONCHAIN_UVN_INTERNAL_ID" >>$DRAGONCHAIN_INSTALLER_DIR/.config
    echo "DRAGONCHAIN_UVN_REGISTRATION_TOKEN=$DRAGONCHAIN_UVN_REGISTRATION_TOKEN" >>$DRAGONCHAIN_INSTALLER_DIR/.config
    echo "DRAGONCHAIN_UVN_NODE_NAME=$DRAGONCHAIN_UVN_NODE_NAME" >>$DRAGONCHAIN_INSTALLER_DIR/.config
    echo "DRAGONCHAIN_UVN_ENDPOINT_URL=$DRAGONCHAIN_UVN_ENDPOINT_URL" >>$DRAGONCHAIN_INSTALLER_DIR/.config
    echo "DRAGONCHAIN_UVN_NODE_PORT=$DRAGONCHAIN_UVN_NODE_PORT" >>$DRAGONCHAIN_INSTALLER_DIR/.config
    echo "DRAGONCHAIN_UVN_NODE_LEVEL=$DRAGONCHAIN_UVN_NODE_LEVEL" >>$DRAGONCHAIN_INSTALLER_DIR/.config

}

##########################################################################
## Function patch_server_current
patch_server_current() {

    LOG_FILE=./dragonchain_uvn_installer_bootstrap.log

    #Patch our system current [stable]
    sudo apt-get update >>$LOG_FILE 2>&1
    errchk $? "sudo apt-get update >> $LOG_FILE 2>&1"

	offer_apt_upgrade

    offer_microk8s_channel_latest

}

##########################################################################
## Function bootstrap_environment
bootstrap_environment() {
    #duck
    # Make vm.max_map change current and for next reboot
    # https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html

    #duck note: might want to check the .conf file for this line to already exist before adding again

    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf >/dev/null
    sudo sysctl -w vm.max_map_count=262144 >>$LOG_FILE 2>&1 & spinner
    errchk $? "sudo sysctl -w vm.max_map_count=262144 >> $LOG_FILE 2>&1"

    # Install jq, openssl, xxd
    sudo apt-get install -y ufw curl jq openssl xxd snapd >>$LOG_FILE 2>&1 & spinner
    errchk $? "sudo apt-get install -y ufw curl jq openssl xxd snapd >> $LOG_FILE 2>&1"

    # Install microk8s classic via snap package
    # TODO - Revert to stable when refresh-certs is merged
    sudo snap install microk8s --classic --channel=1.20/stable >>$LOG_FILE 2>&1 & spinner
    errchk $? "sudo snap install microk8s --classic --channel=1.20/stable >> $LOG_FILE 2>&1"

    # Because we have microk8s, we need to alias kubectl
    sudo snap alias microk8s.kubectl kubectl >>$LOG_FILE 2>&1 & spinner
    errchk $? "sudo snap alias microk8s.kubectl kubectl >> $LOG_FILE 2>&1"

    # Setup firewall rules
    # This should be reviewed - confident we can restrict this further
    #duck To stop ufw set errors 'Could not load logging rules', disable then enable logging once set

    echo

    FIREWALL_RULES=$(sudo ufw status verbose | grep -c -Fwf <(printf "%s\n" active 'allow (routed)' 22 cni0))

    if [ $FIREWALL_RULES -lt 8 ]; then

        printf "\nConfiguring default firewall rules..."

        sleep 20 & spinner
        sudo ufw --force enable >>$LOG_FILE 2>&1 & spinner
        errchk $? "sudo ufw --force enable >> $LOG_FILE 2>&1"
        sleep 10 & spinner

        sleep 2 & spinner
        sudo ufw logging off >>$LOG_FILE 2>&1 & spinner
        errchk $? "sudo ufw logging off >> $LOG_FILE 2>&1"
        sleep 5 & spinner

        sleep 2 & spinner
        sudo ufw allow 22/tcp >>$LOG_FILE 2>&1 & spinner
        errchk $? "sudo ufw allow 22/tcp >> $LOG_FILE 2>&1"
        sleep 5 & spinner

        sleep 2 & spinner
        sudo ufw default allow routed >>$LOG_FILE 2>&1 & spinner
        errchk $? "sudo ufw default allow routed >> $LOG_FILE 2>&1"
        sleep 15 & spinner

        sleep 2 & spinner
        sudo ufw default allow outgoing >>$LOG_FILE 2>&1 & spinner
        errchk $? "sudo ufw default allow outgoing >> $LOG_FILE 2>&1"
        sleep 15 & spinner

        sleep 2 & spinner
        sudo ufw allow in on cni0 >>$LOG_FILE 2>&1 && sudo ufw allow out on cni0 >>$LOG_FILE 2>&1 & spinner
        errchk $? "sudo ufw allow in on cni0 && sudo ufw allow out on cni0 >> $LOG_FILE 2>&1"
        sleep 5 & spinner

        sleep 2 & spinner
        sudo ufw logging on >>$LOG_FILE 2>&1 & spinner
        errchk $? "sudo ufw logging on >> $LOG_FILE 2>&1"
        sleep 5 & spinner

    else

        printf "\nDefault firewall rules already configured. Continuing..."

    fi

    # Wait for system to stabilize and avoid race conditions

    sleep 10 & spinner

    echo

    initialize_microk8s

}

##########################################################################
## Function initialize_microk8s
initialize_microk8s() {

    MICROK8S_INITIALIZED=$(sudo kubectl get namespaces | grep -c -e container-registry -e kube-system)

    if [ $MICROK8S_INITIALIZED -lt 2 ]; then

        printf "\nInitializing microk8s..."

        # Enable Microk8s modules
        # unable to errchk this command because microk8s.enable helm command will RC=2 b/c nothing for helm to do
        sudo microk8s.enable dns storage helm3 >>$LOG_FILE 2>&1 & spinner

        # Alias helm3
        sudo snap alias microk8s.helm3 helm >>$LOG_FILE 2>&1 & spinner
        errchk $? "sudo snap alias microk8s.helm3 helm >> $LOG_FILE 2>&1"

        # Wait for system to stabilize and avoid race conditions
        sleep 10 & spinner

        # Install more Microk8s modules
        sudo microk8s.enable registry >>$LOG_FILE 2>&1 & spinner
        errchk $? "sudo microk8s.enable registry >> $LOG_FILE 2>&1"

        echo

    else

        printf "\nmicrok8s initialized...\n"

    fi

}

##########################################################################
## Function check_existing_install
check_existing_install() {
    NAMESPACE_EXISTS=$(sudo kubectl get namespaces | grep -c -E "(^|\s)$DRAGONCHAIN_INSTALLER_DIR(\s|$)")

    if [ $NAMESPACE_EXISTS -ge 1 ]; then
        echo -e "\n\e[93mAn install of Dragonchain UVN '$DRAGONCHAIN_INSTALLER_DIR' (failed or complete) was found:\e[0m"

        local ANSWER=""
        while [[ "$ANSWER" != "d" && "$ANSWER" != "delete" && "$ANSWER" != "u" && "$ANSWER" != "upgrade" ]]; do
            echo -e "\e[2mIf you would like to Upgrade UVN '$DRAGONCHAIN_INSTALLER_DIR', press \e[93m[u]\e[0m"
            echo -e "\n\e[2mIf you would like to Delete a failed UVN '$DRAGONCHAIN_INSTALLER_DIR', press \e[93m[d]\e[0m"
            echo -e "\e[2m\e[91mIf you delete, UVN '$DRAGONCHAIN_INSTALLER_DIR' will be removed and its configuration deleted.\nThis action will NOT affect any other running UVNs.\e[0m"
            read ANSWER
            echo
        done

        if [[ "$ANSWER" == "d" || "$ANSWER" == "delete" ]]; then

            # User wants to delete namespace
            printf "Deleting Dragonchain UVN '$DRAGONCHAIN_INSTALLER_DIR'..."
            sudo kubectl delete namespaces $DRAGONCHAIN_INSTALLER_DIR >>$LOG_FILE 2>&1 & spinner
            errchk $? "sudo kubectl delete namespaces"

            printf "\n\nDeleting saved configuration for Dragonchain UVN '$DRAGONCHAIN_INSTALLER_DIR'..."
            sudo rm $DRAGONCHAIN_INSTALLER_DIR -R >>$LOG_FILE 2>&1 & spinner

            sleep 5 & spinner

            printf "\n\nDeleting firewall configuration for Dragonchain UVN '$DRAGONCHAIN_INSTALLER_DIR'..."
            sudo sudo ufw delete allow $DRAGONCHAIN_UVN_NODE_PORT/tcp >/dev/null 2>&1 & spinner

            echo -e "\n\n\e[93mDragonchain UVN '$DRAGONCHAIN_INSTALLER_DIR' has been terminated and its configuration\ndata has been deleted.\e[0m"
            echo -e "\e[2mPlease rerun the installer to reconfigure this UVN.\e[0m"

            exit 0

        fi

        # User wants to attempt upgrade
        printf "\nUpgrading Dragonchain UVN '$DRAGONCHAIN_INSTALLER_DIR'...\n"

        install_dragonchain

        check_kube_status

        set_dragonchain_public_id

        check_matchmaking_status_upgrade

        exit 0

    fi

}

##########################################################################
## Function generate_chainsecrets
generate_chainsecrets() {
    #duck note: running it outright; TODO: write HMAC_ID and HMAC_KEY to secure log file

    echo '{"kind":"Namespace","apiVersion":"v1","metadata":{"name":"'"$DRAGONCHAIN_INSTALLER_DIR"'","labels":{"name":"'"$DRAGONCHAIN_INSTALLER_DIR"'"}}}' | sudo kubectl create -f - >>$LOG_FILE
    export LC_CTYPE=C # Needed on MacOS when using tr with /dev/urandom
    BASE_64_PRIVATE_KEY=$(openssl ecparam -genkey -name secp256k1 | openssl ec -outform DER 2>/dev/null | tail -c +8 | head -c 32 | xxd -p -c 32 | xxd -r -p | base64)
    HMAC_ID=$(tr -dc 'A-Z' </dev/urandom | fold -w 12 | head -n 1)
    HMAC_KEY=$(tr -dc 'A-Za-z0-9' </dev/urandom | fold -w 43 | head -n 1)
    SECRETS_AS_JSON="{\"private-key\":\"$BASE_64_PRIVATE_KEY\",\"hmac-id\":\"$HMAC_ID\",\"hmac-key\":\"$HMAC_KEY\",\"registry-password\":\"\"}"
    sudo kubectl create secret generic -n $DRAGONCHAIN_INSTALLER_DIR "d-$DRAGONCHAIN_UVN_INTERNAL_ID-secrets" --from-literal=SecretString="$SECRETS_AS_JSON" >>$LOG_FILE
    # Note INTERNAL_ID from the secret name should be replaced with the value of .global.environment.INTERNAL_ID from the helm chart values (opensource-config.yaml)

    # output from generated script above ; we need to capture ROOT HMAC KEY for later!
}

##########################################################################
## Function install_dragonchain
install_dragonchain() {

    sudo helm repo add dragonchain https://dragonchain-charts.s3.amazonaws.com >>$LOG_FILE 2>&1
    errchk $? "sudo helm repo add dragonchain https://dragonchain-charts.s3.amazonaws.com >> $LOG_FILE 2>&1"

    sudo helm repo update >>$LOG_FILE 2>&1
    errchk $? "sudo helm repo update >> $LOG_FILE 2>&1"

    RASPBERRY_PI=$(sudo lshw 2>/dev/null | grep -c "Raspberry")

    if [ $RASPBERRY_PI -eq 1 ]; then

        # Running Raspberry Pi
        # Deploy Helm Chart
        #
        # Set CPU limits

        printf "\nInstalling Dragonchain UVN '$DRAGONCHAIN_INSTALLER_DIR' for Raspberry Pi...\n"

        sudo helm upgrade --install $DRAGONCHAIN_UVN_NODE_NAME --namespace $DRAGONCHAIN_INSTALLER_DIR dragonchain/dragonchain-k8s \
        --set global.environment.DRAGONCHAIN_NAME="$DRAGONCHAIN_UVN_NODE_NAME" \
        --set global.environment.REGISTRATION_TOKEN="$DRAGONCHAIN_UVN_REGISTRATION_TOKEN" \
        --set global.environment.INTERNAL_ID="$DRAGONCHAIN_UVN_INTERNAL_ID" \
        --set global.environment.DRAGONCHAIN_ENDPOINT="$DRAGONCHAIN_UVN_ENDPOINT_URL:$DRAGONCHAIN_UVN_NODE_PORT" \
        --set-string global.environment.LEVEL=$DRAGONCHAIN_UVN_NODE_LEVEL \
        --set service.port=$DRAGONCHAIN_UVN_NODE_PORT \
        --set dragonchain.storage.spec.storageClassName="microk8s-hostpath" \
        --set redis.storage.spec.storageClassName="microk8s-hostpath" \
        --set redisearch.storage.spec.storageClassName="microk8s-hostpath" \
        --set cacheredis.resources.limits.cpu=1,persistentredis.resources.limits.cpu=1,webserver.resources.limits.cpu=2,transactionProcessor.resources.limits.cpu=1 >>$LOG_FILE 2>&1

        errchk $? "Dragonchain install command >> $LOG_FILE 2>&1"

    else

        # Not Running Raspberry Pi
        # Deploy Helm Chart
        #

        printf "\nInstalling Dragonchain UVN '$DRAGONCHAIN_INSTALLER_DIR'...\n"

        sudo helm upgrade --install $DRAGONCHAIN_UVN_NODE_NAME --namespace $DRAGONCHAIN_INSTALLER_DIR dragonchain/dragonchain-k8s \
        --set global.environment.DRAGONCHAIN_NAME="$DRAGONCHAIN_UVN_NODE_NAME" \
        --set global.environment.REGISTRATION_TOKEN="$DRAGONCHAIN_UVN_REGISTRATION_TOKEN" \
        --set global.environment.INTERNAL_ID="$DRAGONCHAIN_UVN_INTERNAL_ID" \
        --set global.environment.DRAGONCHAIN_ENDPOINT="$DRAGONCHAIN_UVN_ENDPOINT_URL:$DRAGONCHAIN_UVN_NODE_PORT" \
        --set-string global.environment.LEVEL=$DRAGONCHAIN_UVN_NODE_LEVEL \
        --set service.port=$DRAGONCHAIN_UVN_NODE_PORT \
        --set dragonchain.storage.spec.storageClassName="microk8s-hostpath" \
        --set redis.storage.spec.storageClassName="microk8s-hostpath" \
        --set redisearch.storage.spec.storageClassName="microk8s-hostpath" >>$LOG_FILE 2>&1

        errchk $? "Dragonchain install command >> $LOG_FILE 2>&1"

    fi

}

##########################################################################
## Function check_kube_status
check_kube_status() {
    DRAGONCHAIN_UVN_INSTALLED=0

    #Pull the current kube status and check until all pods are "1/1" and "running"
    local STATUS_CHECK_COUNT=1
    while :; do
        local STATUS=$(sudo kubectl get pods -n $DRAGONCHAIN_INSTALLER_DIR)

        READYCOUNT=$(echo "$STATUS" | grep -c "1/1")
        RUNNINGCOUNT=$(echo "$STATUS" | grep -c "Running")

        echo "[$STATUS_CHECK_COUNT] Ready: $READYCOUNT Running: $RUNNINGCOUNT"

        if [ $READYCOUNT -eq 4 ] && [ $RUNNINGCOUNT -eq 4 ]; then
            DRAGONCHAIN_UVN_INSTALLED=1
            break
        fi

        if [ $STATUS_CHECK_COUNT -gt 30 ]; then #Don't loop forever (30 loops should be about 15 minutes, the longest it SHOULD take for kube to finish its business)
            break
        fi

        let STATUS_CHECK_COUNT=$STATUS_CHECK_COUNT+1

        sleep 30
    done

    if [ $DRAGONCHAIN_UVN_INSTALLED -eq 0 ]; then #Unsuccessful install: direct user to ask for help and exit
        echo -e "\e[31mPOST-INSTALL STATUS CHECKS FAILED. PLEASE ASK ON THE DRAGONCHAIN TELEGRAM FOR TECHNICAL SUPPORT.\e[0m"
        #duck Need to add to error log here as well...
        exit
    fi

    echo -e "\e[93mSTATUS CHECKS GOOD. DRAGONCHAIN IS RUNNING. CONTACTING MATCHMAKING API...\e[0m"
    #duck Maybe add logging here, too?
}

##########################################################################
## Function set_dragonchain_public_id
set_dragonchain_public_id() {
    #Parse the full name of the webserver pod
    DRAGONCHAIN_WEBSERVER_POD_NAME=$(sudo kubectl get pod -n $DRAGONCHAIN_INSTALLER_DIR -l app.kubernetes.io/component=webserver | tail -1 | awk '{print $1}')
    errchk $? "Pod name extraction"

    DRAGONCHAIN_UVN_PUBLIC_ID=$(sudo kubectl exec -n $DRAGONCHAIN_INSTALLER_DIR $DRAGONCHAIN_WEBSERVER_POD_NAME -- python3 -c "from dragonchain.lib.keys import get_public_id; print(get_public_id())")
    errchk $? "Public ID lookup"

    #duck Let's log this in the secrets file with hmac stuff
    echo "Your Chain's Public ID is: $DRAGONCHAIN_UVN_PUBLIC_ID"
}

##########################################################################
## Function check_matchmaking_status
check_matchmaking_status() {
    local MATCHMAKING_API_CHECK=$(curl -s https://matchmaking.api.dragonchain.com/registration/verify/$DRAGONCHAIN_UVN_PUBLIC_ID)

    local SUCCESS_CHECK=$(echo "$MATCHMAKING_API_CHECK" | grep -c "configuration is valid and chain is reachable")

    if [ $SUCCESS_CHECK -eq 1 ]; then
        #SUCCESS!
        echo "Your HMAC (aka Access) Key Details are as follows (please save for future use):"
        echo "ID: $HMAC_ID"
        echo "Key: $HMAC_KEY"

        echo -e "\e[92mYOUR DRAGONCHAIN UVN '$DRAGONCHAIN_INSTALLER_DIR' IS ONLINE AND REGISTERED WITH THE MATCHMAKING API! HAPPY NODING!\e[0m"
        echo -e "\e[2mTo watch the status of this UVN, type 'sudo watch kubectl get pods -n $DRAGONCHAIN_INSTALLER_DIR'\e[0m"
        echo -e "\e[2mTo watch all UVNs, type 'sudo watch kubectl get pods --all-namespaces'\e[0m"

        #duck Prevent offering upgrade until latest kubernetes/helm issues are resolved
        #offer_apt_upgrade

        #offer to install another node or exit

        local ANSWER=""
        while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]; do
            echo -e "\n\e[93mWould you like to install another Dragonchain UVN? [yes or no]\e[0m"
            read ANSWER
            echo
        done

        if [[ "$ANSWER" == "y" || "$ANSWER" == "yes" ]]; then

            ## Prompt for Dragonchain node name
            prompt_node_name

            #check for required commands, setup logging
            preflight_check

            #load config values or gather from user
            set_config_values

            # check for previous installation (failed or successful) and offer reset if found
            printf "\nChecking for previous Dragonchain UVN installation...\n"
            check_existing_install

            # must gather node details from user or .config before generating chainsecrets
            printf "\nGenerating chain secrets...\n"
            generate_chainsecrets

            install_dragonchain

            check_kube_status

            set_dragonchain_public_id

            check_matchmaking_status

            exit 0

        fi

    else
        #Boo!
        echo -e "\e[31mYOUR DRAGONCHAIN UVN '$DRAGONCHAIN_INSTALLER_DIR' IS ONLINE BUT THE MATCHMAKING API RETURNED AN ERROR. PLEASE SEE BELOW AND REQUEST HELP IN DRAGONCHAIN TELEGRAM\e[0m"
        echo "$MATCHMAKING_API_CHECK"
    fi
}

##########################################################################
## Function offer_apt_upgrade
offer_apt_upgrade() {

	UPGRADABLE=$(sudo apt list --upgradable 2>/dev/null | grep -c -e base-files -e core -e lib -e security -e python)

    if [ $UPGRADABLE -ge 1 ]; then

		echo -e "\n\e[93mThere are important updates available for this operating system.\e[0m"
        echo -e "\e[2mIt is HIGHLY recommended that you install now to keep things running smoothly.\e[0m"

		local ANSWER=""
		while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]; do
			echo -e "\n\e[93mWould you like to update now? [yes or no]\e[0m"
			read ANSWER
			echo
		done

		if [[ "$ANSWER" == "y" || "$ANSWER" == "yes" ]]; then
			# User wants to upgrade

            printf "Updating operating system..."

			sudo apt-get upgrade -y >>$LOG_FILE 2>&1 & spinner
			errchk $? "sudo apt-get upgrade -y >> /dev/null"

            MANUALAPT=$(sudo apt list --upgradable 2>/dev/null | grep -c -e base-files -e security)

            if [ "$MANUALAPT" -ge 1 ]; then

			    sudo apt-get install -y base-files >>$LOG_FILE 2>&1 & spinner
			    errchk $? "sudo apt-get install -y base-files"

			    sudo apt-get install -y linux-generic >>$LOG_FILE 2>&1 & spinner
			    errchk $? "sudo apt-get install -y linux-generic"

			    sudo apt-get install -y sosreport >>$LOG_FILE 2>&1 & spinner
			    errchk $? "sudo apt-get install -y sosreport"

             fi

            echo

			# Reboot required?
			REBOOT=$(cat /var/run/reboot-required 2>/dev/null | grep -c required)

			if [ $REBOOT -ge 1 ]; then
			echo -e "\n\e[93mThe operating system needs to restart to complete the update.\e[0m"
            echo -e "\e[2mIf you have Dragonchain UVNs already configured, fear not, they will automatically restart when we return!\e[0m"

			local ANSWER=""
			while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]; do
				echo -e "\n\e[93mReboot now? [yes or no]\e[0m"
				read ANSWER
				echo
				done

				if [[ "$ANSWER" == "y" || "$ANSWER" == "yes" ]]; then

                # User wants to reboot
				echo -e "OK, going down for a reboot now..."
				sudo reboot
				errchk $? "sudo reboot"
				sleep 5

			fi

		    else

		    printf "\nUpdates complete, no reboot required. Continuing...\n"

            echo

		fi

    fi

	else

	printf "\nOperating system up-to-date. Continuing...\n"

    echo

	fi

}


##########################################################################
## Function offer_microk8s_channel_latest
##
## This installer will by default snap to the the specified channel, but we need to offer it to folks in the wild snapped to older versions
offer_microk8s_channel_latest() {

    MICROK8S_VERSION=$(sudo snap info microk8s | grep -c 'installed.*1.1')

    if [ $MICROK8S_VERSION -eq 1 ]; then

        echo -e "\e[93mYou are running on an older microk8s snap channel.\e[0m"
        echo -e "\e[2mUpgrading to the latest channel is not required, however this\e[0m"
        echo -e "\e[2mmay be necessary in future if your Dragonchain UVNs become unhealthy.\e[0m"
		echo -e "\n\e[93mPlease note that upgrading to the latest channel will \n\e[91mSTOP YOUR UVNs FROM RUNNING\e[0m \n\e[93mtemporarily whilst the latest channel is installed.\e[0m"
		local ANSWER=""
		while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]; do
			echo -e "\n\e[93mWould you like to upgrade now? [yes or no]\e[0m"
			read ANSWER
			echo
		done

		if [[ "$ANSWER" == "y" || "$ANSWER" == "yes" ]]; then
			# User wants to snap to specified channel

            printf "Updating microk8s..."

			sudo snap refresh microk8s --channel=1.20/stable >>$LOG_FILE & spinner
			errchk $? "sudo snap refresh microk8s --channel=1.20/stable"

            echo

			# Reboot required?
			REBOOT=$(cat /var/run/reboot-required 2>/dev/null | grep -c required)

			if [ $REBOOT -ge 1 ]; then
			echo -e "\n\e[93mThe operating system needs to restart to complete the upgrade.\e[0m"
            echo -e "\e[2mIf you have Dragonchain UVNs already configured, fear not, they will automatically restart when we return!\e[0m"

			local ANSWER=""
			while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]; do
				echo -e "\n\e[93mReboot now? [yes or no]\e[0m"
				read ANSWER
				echo
				done

				if [[ "$ANSWER" == "y" || "$ANSWER" == "yes" ]]; then
					# User wants to reboot
					echo -e "OK, going down for a reboot now..."
					sudo reboot
					errchk $? "sudo reboot"
					sleep 5

			fi

		else

		printf "\nUpdates complete, no reboot required. Continuing...\n"

        echo

		fi

    fi

    fi

}

##########################################################################
## Function check_matchmaking_status_upgrade
check_matchmaking_status_upgrade() {
    local MATCHMAKING_API_CHECK=$(curl -s https://matchmaking.api.dragonchain.com/registration/verify/$DRAGONCHAIN_UVN_PUBLIC_ID)

    local SUCCESS_CHECK=$(echo "$MATCHMAKING_API_CHECK" | grep -c "configuration is valid and chain is reachable")

    if [ $SUCCESS_CHECK -eq 1 ]; then
        #SUCCESS!
        echo -e "\e[92mYOUR DRAGONCHAIN UVN '$DRAGONCHAIN_INSTALLER_DIR' IS NOW UPGRADED AND REGISTERED WITH THE MATCHMAKING API! HAPPY NODING!\e[0m"

    else
        #Boo!
        echo -e "\e[31mYOUR DRAGONCHAIN UVN '$DRAGONCHAIN_INSTALLER_DIR' IS ONLINE BUT THE MATCHMAKING API RETURNED AN ERROR. PLEASE SEE BELOW AND REQUEST HELP IN DRAGONCHAIN TELEGRAM\e[0m"
        echo "$MATCHMAKING_API_CHECK"
    fi
}

##########################################################################
## Function offer_nodes_upgrade - also new install or delete everything!
offer_nodes_upgrade() {

    LOG_FILE=$DRAGONCHAIN_INSTALLER_DIR/dragonchain_uvn_installer.log
    SECURE_LOG_FILE=$DRAGONCHAIN_INSTALLER_DIR/dragonchain_uvn_installer.secure.log

    sudo helm repo add dragonchain https://dragonchain-charts.s3.amazonaws.com >>$LOG_FILE 2>&1
    errchk $? "sudo helm repo add dragonchain https://dragonchain-charts.s3.amazonaws.com >> $LOG_FILE 2>&1"

    sudo helm repo update >>$LOG_FILE 2>&1
    errchk $? "sudo helm repo update >> $LOG_FILE 2>&1"

    DC_PODS_EXIST=$(sudo kubectl get pods --all-namespaces | grep -c "dc-")

    if [ $DC_PODS_EXIST -ge 1 ]; then
        local ANSWER=""
        while [[ "$ANSWER" != "i" && "$ANSWER" != "install" && "$ANSWER" != "u" && "$ANSWER" != "upgrade" && "$ANSWER" != "d" && "$ANSWER" != "dragon" ]]; do
            echo -e "\n\e[93mPre-existing Dragonchain UVNs have been detected:\e[0m"
            echo -e "\e[2mIf you would like to Install a new UVN (including upgrading, repairing or\ndeleting specific UVNs), press \e[93m[i]\e[0m"
            echo -e "\n\e[2mIf you would like to Upgrade ALL detected UVNs to the latest version, press \e[93m[u]\e[0m"
            echo -e "\n\e[2m\e[91mIf you want to reign Dragonfire on all UVNs and scorch the earth, press \e[93m[d]\e[0m"
            echo -e "\e[2mThis will terminate ALL your UVNs, delete ALL configurations and remove microk8s\e[0m"
            read ANSWER
            echo
        done

        if [[ "$ANSWER" == "u" || "$ANSWER" == "upgrade" ]]; then
            echo -e "Upgrading all existing Dragonchain UVNs..."

            while read -r DRAGONCHAIN_UVN_NODE_NAME DRAGONCHAIN_INSTALLER_DIR; do
                . $DRAGONCHAIN_INSTALLER_DIR/.config

                echo -e "\n\e[93mUpgrading Dragonchain UVN:\e[0m"
                echo "Namespace = $DRAGONCHAIN_INSTALLER_DIR"
                echo "Name = $DRAGONCHAIN_UVN_NODE_NAME"
                echo "Chain ID = $DRAGONCHAIN_UVN_INTERNAL_ID"
                echo "Matchmaking Token = $DRAGONCHAIN_UVN_REGISTRATION_TOKEN"
                echo "Endpoint URL = $DRAGONCHAIN_UVN_ENDPOINT_URL"
                echo "Endpoint Port = $DRAGONCHAIN_UVN_NODE_PORT"
                echo "Node Level = $DRAGONCHAIN_UVN_NODE_LEVEL"
                echo

                sudo helm upgrade --install $DRAGONCHAIN_UVN_NODE_NAME --namespace $DRAGONCHAIN_INSTALLER_DIR dragonchain/dragonchain-k8s

                check_kube_status

                set_dragonchain_public_id

                check_matchmaking_status_upgrade

            done < <(helm list --all-namespaces -o json | jq -c '.[] | "\(.name) \(.namespace)"' | tr -d \")

            exit 0

        fi

        if [[ "$ANSWER" == "d" || "$ANSWER" == "dragon" ]]; then

                echo -e "\e[91mReigning Dragonfire over ALL!!!\e[0m"
                sleep 5

                printf "\nRoasting all UVNs and microk8s..."
                sudo snap remove microk8s >>$LOG_FILE 2>&1 & spinner

                printf "\n\nScorching all UVN firewall rules..."
                sudo ufw status numbered | grep '3[0-9]*/tcp' | awk -F] '{print $1}' | sed 's/\[\s*//' | tac | xargs -n 1 bash -c 'yes|sudo ufw delete $0' >>$LOG_FILE 2>&1 & spinner
                sleep 5 & spinner

                printf "\n\nSetting saved UVN configurations aflame..."
                sudo rm -rf ./*/ & spinner
                sleep 5 & spinner

            echo -e "\n\n\e[93mAll Dragonchain UVNs have been terminated.\nAll configurations have been deleted and microk8s has been removed.\e[0m"
            echo -e "\e[2mRerun the installer to start afresh.\e[0m"

            exit 0

        fi
    fi

}

## Main()

#welcome!!
echo -e "\n\n\e[94mWelcome to the Dragonchain Unmanaged Verification Node (UVN) Community Installer\e[0m"

#patch system current
printf "\nUpdating (patching) host OS current...\n"
patch_server_current

#install necessary software, set tunables
printf "Installing required software and setting Dragonchain UVN configuration..."
bootstrap_environment

## Offer to upgrade all nodes
printf "\nChecking for Pre-existing Dragonchain UVNs...\n"
offer_nodes_upgrade

## Prompt for Dragonchain node name
prompt_node_name

#check for required commands, setup logging
preflight_check

#load config values or gather from user
set_config_values

# check for previous installation (failed or successful) and offer reset if found
printf "\nChecking for a previous Dragonchain UVN '$DRAGONCHAIN_INSTALLER_DIR'...\n"
check_existing_install

# must gather node details from user or .config before generating chainsecrets
printf "\nGenerating chain secrets...\n"
generate_chainsecrets

install_dragonchain

check_kube_status

set_dragonchain_public_id

check_matchmaking_status

exit 0

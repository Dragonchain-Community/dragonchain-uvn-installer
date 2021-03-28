#!/bin/bash

## Assumptions
## Run on Ubuntu 18.04 LTS from AWS (probably will work on others but may be missing )

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
## Function prompt_node_name
prompt_node_name() {
    echo -e "\n\e[94mEnter a Dragonchain node name:\e[0m"
    echo -e "\e[2mThe name must be unique if you intend to run multiple nodes\e[0m"
    echo -e "\e[2mThe name can contain numbers, lowercase characters and '-' ONLY\e[0m"
    echo -e "\e[2mTo upgrade, repair or delete a specific installation, type the node name of that installation\e[0m"

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
        printf "\nERROR: Sudo configuration may not be ideal for this setup. Exiting.\n"
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

        echo -e "\n\e[93mSaved configuration values found:\e[0m"
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
            echo -e "\e[93mUse saved configuration? [yes or no]\e[0m"
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

        echo -e "\e[94mEnter the endpoint URL for your Dragonchain node WITHOUT the port:\e[0m"
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

        echo -e "\e[94mEnter the endpoint PORT for your Dragonchain node (must be between 30000 and 32767):\e[0m"
        read DRAGONCHAIN_UVN_NODE_PORT
        DRAGONCHAIN_UVN_NODE_PORT=$(echo $DRAGONCHAIN_UVN_NODE_PORT | tr -d '\r')
        echo
    done

    while [[ ! "$DRAGONCHAIN_UVN_NODE_LEVEL" =~ ^[0-9]+$ ]] || ((DRAGONCHAIN_UVN_NODE_LEVEL < 2 || DRAGONCHAIN_UVN_NODE_LEVEL > 4)); do
        if [[ ! -z "$DRAGONCHAIN_UVN_NODE_LEVEL" ]]; then
            echo -e "\e[91mInvalid node level entered!\e[0m"
        fi

        echo -e "\e[94mEnter the node level for your Dragonchain node (must be between 2 and 4):\e[0m"
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

    #    sudo apt-get upgrade -y >> $LOG_FILE 2>&1
    #    errchk $? "sudo apt-get upgrade -y >> $LOG_FILE 2>&1"
}

##########################################################################
## Function bootstrap_environment
bootstrap_environment() {
    #duck
    # Make vm.max_map change current and for next reboot
    # https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html

    #duck note: might want to check the .conf file for this line to already exist before adding again

    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf >/dev/null
    sudo sysctl -w vm.max_map_count=262144 >>$LOG_FILE 2>&1
    errchk $? "sudo sysctl -w vm.max_map_count=262144 >> $LOG_FILE 2>&1"

    # Install jq, openssl, xxd
    sudo apt-get install -y ufw curl jq openssl xxd snapd >>$LOG_FILE 2>&1
    errchk $? "sudo apt-get install -y ufw curl jq openssl xxd snapd >> $LOG_FILE 2>&1"

    # Install microk8s classic via snap package
    # TODO - Revert to stable when refresh-certs is merged
    sudo snap install microk8s --channel=1.18/stable --classic >>$LOG_FILE 2>&1
    errchk $? "sudo snap install microk8s --channel=1.18/stable --classic >> $LOG_FILE 2>&1"

    # Because we have microk8s, we need to alias kubectl
    sudo snap alias microk8s.kubectl kubectl >>$LOG_FILE 2>&1
    errchk $? "sudo snap alias microk8s.kubectl kubectl >> $LOG_FILE 2>&1"

    # Setup firewall rules
    # This should be reviewed - confident we can restrict this further
    #duck To stop ufw set errors 'Could not load logging rules', disable then enable logging once set

    FIREWALL_RULES=$(sudo ufw status verbose | grep -c -e active -e "allow (outgoing)" -e "allow (routed)" -e 22 -e cni0)

    if [ $FIREWALL_RULES -lt 8 ]; then

        printf "\nConfiguring default firewall rules...\n"

        sleep 10
        sudo ufw --force enable >>$LOG_FILE 2>&1
        errchk $? "sudo ufw --force enable >> $LOG_FILE 2>&1"
        sleep 10

        sleep 2
        sudo ufw logging off >>$LOG_FILE 2>&1
        errchk $? "sudo ufw logging off >> $LOG_FILE 2>&1"
        sleep 5

        sleep 2
        sudo ufw allow 22/tcp >>$LOG_FILE 2>&1
        errchk $? "sudo ufw allow 22/tcp >> $LOG_FILE 2>&1"
        sleep 5

        sleep 2
        sudo ufw default allow routed >>$LOG_FILE 2>&1
        errchk $? "sudo ufw default allow routed >> $LOG_FILE 2>&1"
        sleep 15

        sleep 2
        sudo ufw default allow outgoing >>$LOG_FILE 2>&1
        errchk $? "sudo ufw default allow outgoing >> $LOG_FILE 2>&1"
        sleep 15

        sleep 2
        sudo ufw allow in on cni0 >>$LOG_FILE 2>&1 && sudo ufw allow out on cni0 >>$LOG_FILE 2>&1
        errchk $? "sudo ufw allow in on cni0 && sudo ufw allow out on cni0 >> $LOG_FILE 2>&1"
        sleep 5

        sleep 2
        sudo ufw logging off >>$LOG_FILE 2>&1
        errchk $? "sudo ufw logging on >> $LOG_FILE 2>&1"
        sleep 5

    else

        printf "\nDefault firewall rules already configured. Continuing...\n"

    fi

    # Wait for system to stabilize and avoid race conditions

    sleep 10

    initialize_microk8s

}

##########################################################################
## Function initialize_microk8s
initialize_microk8s() {

    printf "\nInitializing microk8s...\n"

    # Enable Microk8s modules
    # unable to errchk this command because microk8s.enable helm command will RC=2 b/c nothing for helm to do
    sudo microk8s.enable dns storage helm3 >>$LOG_FILE 2>&1

    # Alias helm3
    sudo snap alias microk8s.helm3 helm >>$LOG_FILE 2>&1
    errchk $? "sudo snap alias microk8s.helm3 helm >> $LOG_FILE 2>&1"

    # Wait for system to stabilize and avoid race conditions
    sleep 10

    # Install more Microk8s modules
    sudo microk8s.enable registry >>$LOG_FILE 2>&1
    errchk $? "sudo microk8s.enable registry >> $LOG_FILE 2>&1"
}

##########################################################################
## Function check_existing_install
check_existing_install() {
    NAMESPACE_EXISTS=$(sudo kubectl get namespaces | grep -c $DRAGONCHAIN_INSTALLER_DIR)

    if [ $NAMESPACE_EXISTS -ge 1 ]; then
        echo -e "\e[93mA previous installation of Dragonchain node '$DRAGONCHAIN_INSTALLER_DIR' (failed or complete) was found.\e[0m"

        local ANSWER=""
        while [[ "$ANSWER" != "d" && "$ANSWER" != "delete" && "$ANSWER" != "u" && "$ANSWER" != "upgrade" ]]; do
            echo -e "\e[2mIf you would like to upgrade node '$DRAGONCHAIN_INSTALLER_DIR', press \e[93m[u]\e[0m"
            echo -e "\e[2mIf you would like to delete a failed or incorrect installation for node '$DRAGONCHAIN_INSTALLER_DIR', press \e[93m[d]\e[0m"
            echo -e "\e[91m(If you delete, all configuration for '$DRAGONCHAIN_INSTALLER_DIR' will be removed. Other running nodes will be unaffected)\e[0m"
            read ANSWER
            echo
        done

        if [[ "$ANSWER" == "d" || "$ANSWER" == "delete" ]]; then
            # User wants to delete namespace
            echo -e "Deleting node '$DRAGONCHAIN_INSTALLER_DIR' (may take several minutes)..."
            sudo kubectl delete namespaces $DRAGONCHAIN_INSTALLER_DIR >>$LOG_FILE 2>&1
            errchk $? "sudo kubectl delete namespaces"

            echo -e "\nDeleting saved configuration for '$DRAGONCHAIN_INSTALLER_DIR'..."
            sudo rm $DRAGONCHAIN_INSTALLER_DIR -R

            sleep 5

            echo -e "\nConfiguration data for '$DRAGONCHAIN_INSTALLER_DIR' has been deleted and the node has been terminated."
            echo -e "Please rerun the installer to reconfigure this node."

            exit 0
        fi

        # User wants to attempt upgrade
        printf "\nUpgrading UVN Dragonchain '$DRAGONCHAIN_INSTALLER_DIR'...\n"

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

    RASPBERRY_PI=$(sudo lshw | grep -c "Raspberry")

    if [ $RASPBERRY_PI -eq 1 ]; then

        # Running Raspberry Pi
        # Deploy Helm Chart
        #
        # Set CPU limits

        printf "\nInstalling UVN Dragonchain '$DRAGONCHAIN_INSTALLER_DIR' for Raspberry Pi...\n"

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

        printf "\nInstalling UVN Dragonchain '$DRAGONCHAIN_INSTALLER_DIR'...\n"

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

        echo -e "\e[92mYOUR DRAGONCHAIN NODE '$DRAGONCHAIN_INSTALLER_DIR' IS ONLINE AND REGISTERED WITH THE MATCHMAKING API! HAPPY NODING!\e[0m"
        echo -e "\e[2mTo watch the status of this node, type 'sudo watch kubectl get pods -n $DRAGONCHAIN_INSTALLER_DIR'\e[0m"
        echo -e "\e[2mTo watch the status of all nodes, type 'sudo watch kubectl get pods --all-namespaces'\e[0m"

        #duck Prevent offering upgrade until latest kubernetes/helm issues are resolved
        #offer_apt_upgrade

        #offer to install another node or exit

        local ANSWER=""
        while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]; do
            echo -e "\n\e[93mWould you like to install another Dragonchain node? [yes or no]\e[0m"
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
            printf "\nChecking for previous installation...\n"
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
        echo -e "\e[31mYOUR DRAGONCHAIN NODE '$DRAGONCHAIN_INSTALLER_DIR' IS ONLINE BUT THE MATCHMAKING API RETURNED AN ERROR. PLEASE SEE BELOW AND REQUEST HELP IN DRAGONCHAIN TELEGRAM\e[0m"
        echo "$MATCHMAKING_API_CHECK"
    fi
}

offer_apt_upgrade() {

    echo -e "\e[93mIt is HIGHLY recommended that you run 'sudo apt-get upgrade -y' at this time to update your operating system.\e[0m"

    local ANSWER=""
    while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]; do
        echo -e "Run the upgrade command now? [yes or no]"
        read ANSWER
        echo
    done

    if [[ "$ANSWER" == "y" || "$ANSWER" == "yes" ]]; then
        # User wants fresh values
        sudo apt-get upgrade -y
        errchk $? "sudo apt-get upgrade -y"
    fi
}

##########################################################################
## Function check_matchmaking_status_upgrade
check_matchmaking_status_upgrade() {
    local MATCHMAKING_API_CHECK=$(curl -s https://matchmaking.api.dragonchain.com/registration/verify/$DRAGONCHAIN_UVN_PUBLIC_ID)

    local SUCCESS_CHECK=$(echo "$MATCHMAKING_API_CHECK" | grep -c "configuration is valid and chain is reachable")

    if [ $SUCCESS_CHECK -eq 1 ]; then
        #SUCCESS!
        echo -e "\e[92mYOUR DRAGONCHAIN NODE '$DRAGONCHAIN_INSTALLER_DIR' IS NOW UPGRADED AND REGISTERED WITH THE MATCHMAKING API! HAPPY NODING!\e[0m"

        #duck Prevent offering upgrade until latest kubernetes/helm issues are resolved
        #offer_apt_upgrade

    else
        #Boo!
        echo -e "\e[31mYOUR DRAGONCHAIN NODE '$DRAGONCHAIN_INSTALLER_DIR' IS ONLINE BUT THE MATCHMAKING API RETURNED AN ERROR. PLEASE SEE BELOW AND REQUEST HELP IN DRAGONCHAIN TELEGRAM\e[0m"
        echo "$MATCHMAKING_API_CHECK"
    fi
}

offer_apt_upgrade() {

    echo -e "\e[93mIt is HIGHLY recommended that you run 'sudo apt-get upgrade -y' at this time to update your operating system.\e[0m"

    local ANSWER=""
    while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]; do
        echo -e "Run the upgrade command now? [yes or no]"
        read ANSWER
        echo
    done

    if [[ "$ANSWER" == "y" || "$ANSWER" == "yes" ]]; then
        # User wants fresh values
        sudo apt-get upgrade -y
        errchk $? "sudo apt-get upgrade -y"
    fi
}

##########################################################################
## Function offer_nodes_upgrade
offer_nodes_upgrade() {

    LOG_FILE=$DRAGONCHAIN_INSTALLER_DIR/dragonchain_uvn_installer.log
    SECURE_LOG_FILE=$DRAGONCHAIN_INSTALLER_DIR/dragonchain_uvn_installer.secure.log

    DC_PODS_EXIST=$(sudo kubectl get pods --all-namespaces | grep -c "dc-")

    if [ $DC_PODS_EXIST -ge 1 ]; then
        local ANSWER=""
        while [[ "$ANSWER" != "i" && "$ANSWER" != "install" && "$ANSWER" != "u" && "$ANSWER" != "upgrade" ]]; do
            echo -e "\n\e[93mPre-existing Dragonchain nodes have been detected.\e[0m"
            echo -e "\e[2mIf you would like to install a new node (including upgrading, repairing or deleting specific nodes), press \e[93m[i]\e[0m"
            echo -e "\e[2mIf you would like to upgrade ALL detected nodes to the latest version, press \e[93m[u]\e[0m"
            read ANSWER
            echo
        done

        if [[ "$ANSWER" == "u" || "$ANSWER" == "upgrade" ]]; then
            echo -e "Upgrading all existing nodes..."

            while read -r DRAGONCHAIN_UVN_NODE_NAME DRAGONCHAIN_INSTALLER_DIR; do
                . $DRAGONCHAIN_INSTALLER_DIR/.config

                echo -e "\n\e[93mUpgrading node:\e[0m"
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

    fi
}

## Main()

echo -e "\n\n\e[94mWelcome to the Dragonchain UVN Community Installer!\e[0m"

#patch system current
printf "\nUpdating (patching) host OS current...\n"
patch_server_current

#install necessary software, set tunables
printf "\nInstalling required software and setting Dragonchain UVN system configuration...\n"
bootstrap_environment

## Offer to upgrade all nodes
printf "\nChecking for Pre-existing Dragonchain nodes to upgrade...\n"
offer_nodes_upgrade

## Prompt for Dragonchain node name
prompt_node_name

#check for required commands, setup logging
preflight_check

#load config values or gather from user
set_config_values

# check for previous installation (failed or successful) and offer reset if found
printf "\nChecking for previous installation...\n"
check_existing_install

# must gather node details from user or .config before generating chainsecrets
printf "\nGenerating chain secrets...\n"
generate_chainsecrets

install_dragonchain

check_kube_status

set_dragonchain_public_id

check_matchmaking_status

exit 0

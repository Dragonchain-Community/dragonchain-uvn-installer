#!/bin/bash

## Assumptions
## Run on Ubuntu 18.04 LTS from AWS (probably will work on others but may be missing )

# Variables
REQUIRED_COMMANDS="sudo ls grep chmod tee sed touch cd timeout ufw savelog wget curl"
DRAGONCHAIN_INSTALLER_DIR=~/.dragonchain-installer
LOG_FILE=$DRAGONCHAIN_INSTALLER_DIR/dragonchain_uvn_upgrader.log
SECURE_LOG_FILE=$DRAGONCHAIN_INSTALLER_DIR/dragonchain_uvn_upgrader.secure.log

#Variables may be in .config or from user input

##########################################################################
## Function errchk
## $1 should be $? from the command being checked
## $2 should be the command executed
## When passing $2, do not forget to escape any ""
errchk() {
    if [ "$1" -ne 0 ] ; then
        printf "\nERROR: RC=%s; CMD=%s\n" "$1" "$2" >> $LOG_FILE
        printf "\nERROR: RC=%s; CMD=%s\n" "$1" "$2"
        exit "$1"
    fi
    printf "\nPASS: %s\n" "$2" >> $LOG_FILE
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
## Function preflight_check
preflight_check() {
    # Check for existance of necessary commands
    for CMD in $REQUIRED_COMMANDS ; do
        if ! cmd_exists "$CMD" ; then
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
    if timeout -s SIGKILL 2 sudo ls -l /tmp >/dev/null 2>&1 ; then
        printf "PASS: Sudo configuration in place\n" >> $LOG_FILE
    else
        printf "\nERROR: Sudo configuration may not be ideal for this setup. Exiting.\n" >> $LOG_FILE
        printf "\nERROR: Sudo configuration may not be ideal for this setup. Exiting.\n"
        exit 1
    fi

    # assume user executing is ubuntu with sudo privs
    if [ -e ./dragonchain-setup ]; then
        rm -r ./dragonchain-setup >/dev/null 2>&1
        mkdir ./dragonchain-setup
        errchk $? "mkdir ./dragonchain-setup"
    else
        mkdir ./dragonchain-setup
        errchk $? "mkdir ./dragonchain-setup"
    fi
}

##########################################################################
## Function set_config_values
function set_config_values() {
    if [ -f $DRAGONCHAIN_INSTALLER_DIR/.config ]
    then
        # Execute config file
        . $DRAGONCHAIN_INSTALLER_DIR/.config

        echo -e "\e[93mSaved configuration values found:\e[0m"
        echo "Chain ID = $DRAGONCHAIN_UVN_INTERNAL_ID"
        echo "Matchmaking Token = $DRAGONCHAIN_UVN_REGISTRATION_TOKEN"
        echo "Endpoint URL = $DRAGONCHAIN_UVN_ENDPOINT_URL"
        echo "Endpoint Port = $DRAGONCHAIN_UVN_NODE_PORT"
        echo "Node Level = $DRAGONCHAIN_UVN_NODE_LEVEL"
        echo

        # Prompt user about whether to use saved values
        #duck Maybe just add a flag to bypass this for automated installation?
        local ANSWER=""
        while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]
        do
            echo -e "\e[93mUse saved configuration? [yes or no]\e[0m"
            read ANSWER
            echo
        done

        if [ -z $DRAGONCHAIN_UVN_NODE_LEVEL ]
        then
            while [[ ! "$DRAGONCHAIN_UVN_NODE_LEVEL" =~ ^[0-9]+$ ]] || (( DRAGONCHAIN_UVN_NODE_LEVEL < 2 || DRAGONCHAIN_UVN_NODE_LEVEL > 4 ))
            do
                if [[ ! -z "$DRAGONCHAIN_UVN_NODE_LEVEL" ]]
                then
                    echo -e "\e[91mInvalid node level entered!\e[0m"
                fi

                echo -e "\e[94mEnter the node level for your Dragonchain node (must be between 2 and 4):\e[0m"
                read DRAGONCHAIN_UVN_NODE_LEVEL
                DRAGONCHAIN_UVN_NODE_LEVEL=$(echo $DRAGONCHAIN_UVN_NODE_LEVEL | tr -d '\r')
                echo
            done
        fi

        if [[ "$ANSWER" == "n" || "$ANSWER" == "no" ]]
        then
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

   echo -e "\e[94mEnter your Chain ID from the Dragonchain console:\e[0m"
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


   while [[ ! $DRAGONCHAIN_UVN_ENDPOINT_URL =~ ^(https?)://[A-Za-z0-9.-]+$ ]]
   do
      if [[ ! -z "$DRAGONCHAIN_UVN_ENDPOINT_URL" ]]
      then
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

   while [[ ! "$DRAGONCHAIN_UVN_NODE_PORT" =~ ^[0-9]+$ ]] || (( DRAGONCHAIN_UVN_NODE_PORT < 30000 || DRAGONCHAIN_UVN_NODE_PORT > 32767 ))
   do
      if [[ ! -z "$DRAGONCHAIN_UVN_NODE_PORT" ]]
      then
         echo -e "\e[91mInvalid port number entered!\e[0m"
      fi

      echo -e "\e[94mEnter the endpoint PORT for your Dragonchain node (must be between 30000 and 32767):\e[0m"
      read DRAGONCHAIN_UVN_NODE_PORT
      DRAGONCHAIN_UVN_NODE_PORT=$(echo $DRAGONCHAIN_UVN_NODE_PORT | tr -d '\r')
      echo
   done

   while [[ ! "$DRAGONCHAIN_UVN_NODE_LEVEL" =~ ^[0-9]+$ ]] || (( DRAGONCHAIN_UVN_NODE_LEVEL < 2 || DRAGONCHAIN_UVN_NODE_LEVEL > 4 ))
   do
      if [[ ! -z "$DRAGONCHAIN_UVN_NODE_LEVEL" ]]
      then
         echo -e "\e[91mInvalid node level entered!\e[0m"
      fi

      echo -e "\e[94mEnter the node level for your Dragonchain node (must be between 2 and 4):\e[0m"
      read DRAGONCHAIN_UVN_NODE_LEVEL
      DRAGONCHAIN_UVN_NODE_LEVEL=$(echo $DRAGONCHAIN_UVN_NODE_LEVEL | tr -d '\r')
      echo
   done

   # Write a fresh config file with user-defined values
   rm -f $DRAGONCHAIN_INSTALLER_DIR/.config
   touch $DRAGONCHAIN_INSTALLER_DIR/.config

   echo "DRAGONCHAIN_UVN_INTERNAL_ID=$DRAGONCHAIN_UVN_INTERNAL_ID" >> $DRAGONCHAIN_INSTALLER_DIR/.config
   echo "DRAGONCHAIN_UVN_REGISTRATION_TOKEN=$DRAGONCHAIN_UVN_REGISTRATION_TOKEN" >> $DRAGONCHAIN_INSTALLER_DIR/.config
   echo "DRAGONCHAIN_UVN_NODE_NAME=$DRAGONCHAIN_UVN_NODE_NAME" >> $DRAGONCHAIN_INSTALLER_DIR/.config
   echo "DRAGONCHAIN_UVN_ENDPOINT_URL=$DRAGONCHAIN_UVN_ENDPOINT_URL" >> $DRAGONCHAIN_INSTALLER_DIR/.config
   echo "DRAGONCHAIN_UVN_NODE_PORT=$DRAGONCHAIN_UVN_NODE_PORT" >> $DRAGONCHAIN_INSTALLER_DIR/.config
   echo "DRAGONCHAIN_UVN_NODE_LEVEL=$DRAGONCHAIN_UVN_NODE_LEVEL" >> $DRAGONCHAIN_INSTALLER_DIR/.config

}


##########################################################################
## Function patch_server_current
patch_server_current() {
    #Patch our system current [stable]
    sudo apt-get update >> $LOG_FILE 2>&1
    errchk $? "sudo apt-get update >> $LOG_FILE 2>&1"

#    sudo apt-get upgrade -y >> $LOG_FILE 2>&1
#    errchk $? "sudo apt-get upgrade -y >> $LOG_FILE 2>&1"
}

##########################################################################
## Function bootstrap_environment
bootstrap_environment(){
   
    # Install microk8s classic via snap package
    # TODO - Replace with stable after microk8s.refresh-certs is stabilized
    sudo snap refresh microk8s --channel=1.18/stable --classic >> $LOG_FILE 2>&1
    errchk $? "sudo snap refresh microk8s --channel=1.18/stable --classic >> $LOG_FILE 2>&1"

    # Refresh certificates just in case
    sudo microk8s.refresh-certs -i >> $LOG_FILE 2>&1
    errchk $? "sudo microk8s.refresh-certs -i >> $LOG_FILE 2>&1"

    # Wait for system to stabilize and avoid race conditions
    sleep 30

}


##########################################################################
## Function check_existing_install
check_existing_install(){
    NAMESPACE_EXISTS=$(sudo kubectl get namespaces | grep -c "dragonchain")

    if [ $NAMESPACE_EXISTS -ge 1 ]
    then
        echo -e "\e[93mA previous installation of Dragonchain (failed or complete) was found.\e[0m"

        local ANSWER=""
        while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]
        do
            echo -e "Reset your installation (\e[91mAll data will be deleted\e[0m)? [yes or no]"
            read ANSWER
            echo
        done

        if [[ "$ANSWER" == "y" || "$ANSWER" == "yes" ]]
        then
            # User wants fresh install
            echo "Reseting microk8s (may take several minutes)..."
            sudo microk8s.reset >> $LOG_FILE 2>&1
            errchk $? "sudo microk8s.reset"

            sleep 20

            initialize_microk8s
        fi
    fi

}

##########################################################################
## Function install_dragonchain
install_dragonchain() {

    sudo helm repo add dragonchain https://dragonchain-charts.s3.amazonaws.com >> $LOG_FILE 2>&1
    errchk $? "sudo helm repo add dragonchain https://dragonchain-charts.s3.amazonaws.com >> $LOG_FILE 2>&1"

    sudo helm repo update >> $LOG_FILE 2>&1
    errchk $? "sudo helm repo update >> $LOG_FILE 2>&1"

    # Deploy Helm Chart
    sudo helm upgrade --install $DRAGONCHAIN_UVN_NODE_NAME --namespace dragonchain dragonchain/dragonchain-k8s \
    --set global.environment.DRAGONCHAIN_NAME="$DRAGONCHAIN_UVN_NODE_NAME" \
    --set global.environment.REGISTRATION_TOKEN="$DRAGONCHAIN_UVN_REGISTRATION_TOKEN" \
    --set global.environment.INTERNAL_ID="$DRAGONCHAIN_UVN_INTERNAL_ID" \
    --set global.environment.DRAGONCHAIN_ENDPOINT="$DRAGONCHAIN_UVN_ENDPOINT_URL:$DRAGONCHAIN_UVN_NODE_PORT" \
    --set-string global.environment.LEVEL=$DRAGONCHAIN_UVN_NODE_LEVEL \
    --set service.port=$DRAGONCHAIN_UVN_NODE_PORT \
    --set dragonchain.storage.spec.storageClassName="microk8s-hostpath" \
    --set redis.storage.spec.storageClassName="microk8s-hostpath" \
    --set redisearch.storage.spec.storageClassName="microk8s-hostpath" >> $LOG_FILE 2>&1

    errchk $? "DC Upgrade Command"
}


##########################################################################
## Function check_kube_status
check_kube_status() {
    DRAGONCHAIN_UVN_INSTALLED=0

    #Pull the current kube status and check until all pods are "1/1" and "running"
    local STATUS_CHECK_COUNT=1
    while :
    do
        local STATUS=$(sudo kubectl get pods -n dragonchain)

        READYCOUNT=$(echo "$STATUS" | grep -c "1/1")
        RUNNINGCOUNT=$(echo "$STATUS" | grep -c "Running")

        echo "[$STATUS_CHECK_COUNT] Ready: $READYCOUNT Running: $RUNNINGCOUNT"

        if [ $READYCOUNT -eq 4 ] && [ $RUNNINGCOUNT -eq 4 ]
        then
             DRAGONCHAIN_UVN_INSTALLED=1
             break
        fi

        if [ $STATUS_CHECK_COUNT -gt 30 ] #Don't loop forever (30 loops should be about 15 minutes, the longest it SHOULD take for kube to finish its business)
        then
             break
        fi

        let STATUS_CHECK_COUNT=$STATUS_CHECK_COUNT+1

        sleep 30
    done

    if [ $DRAGONCHAIN_UVN_INSTALLED -eq 0 ] #Unsuccessful install: direct user to ask for help and exit
    then
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
    DRAGONCHAIN_WEBSERVER_POD_NAME=$(sudo kubectl get pod -n dragonchain -l app.kubernetes.io/component=webserver | tail -1 | awk '{print $1}')
    errchk $? "Pod name extraction"

    DRAGONCHAIN_UVN_PUBLIC_ID=$(sudo kubectl exec -n dragonchain $DRAGONCHAIN_WEBSERVER_POD_NAME -- python3 -c "from dragonchain.lib.keys import get_public_id; print(get_public_id())")
    errchk $? "Public ID lookup"

    #duck Let's log this in the secrets file with hmac stuff
    echo "Your Chain's Public ID is: $DRAGONCHAIN_UVN_PUBLIC_ID"
}

##########################################################################
## Function check_matchmaking_status
check_matchmaking_status() {
    local MATCHMAKING_API_CHECK=$(curl -s https://matchmaking.api.dragonchain.com/registration/verify/$DRAGONCHAIN_UVN_PUBLIC_ID)

    local SUCCESS_CHECK=$(echo "$MATCHMAKING_API_CHECK" | grep -c "configuration is valid and chain is reachable")

    if [ $SUCCESS_CHECK -eq 1 ]
    then
        #SUCCESS!
        echo -e "\e[92mYOUR DRAGONCHAIN NODE IS NOW UPGRADED AND REGISTERED WITH THE MATCHMAKING API! HAPPY NODING!\e[0m"
        
        #duck Prevent offering upgrade until latest kubernetes/helm issues are resolved
        #offer_apt_upgrade

    else
        #Boo!
        echo -e "\e[31mYOUR DRAGONCHAIN NODE IS ONLINE BUT THE MATCHMAKING API RETURNED AN ERROR. PLEASE SEE BELOW AND REQUEST HELP IN DRAGONCHAIN TELEGRAM\e[0m"
        echo "$MATCHMAKING_API_CHECK"
    fi
}

offer_apt_upgrade() {

    echo -e "\e[93mIt is HIGHLY recommended that you run 'sudo apt-get upgrade -y' at this time to update your operating system.\e[0m"

    local ANSWER=""
    while [[ "$ANSWER" != "y" && "$ANSWER" != "yes" && "$ANSWER" != "n" && "$ANSWER" != "no" ]]
    do
        echo -e "Run the upgrade command now? [yes or no]"
        read ANSWER
        echo
    done

    if [[ "$ANSWER" == "y" || "$ANSWER" == "yes" ]]
    then
        # User wants fresh values
        sudo apt-get upgrade -y
        errchk $? "sudo apt-get upgrade -y"
    fi
}

## Main()

#check for required commands, setup logging
printf "\n\nChecking host OS for necessary components...\n\n"
preflight_check

#load config values or gather from user
set_config_values

#patch system current
printf "\nUpdating (patching) host OS current...\n"
patch_server_current

#install necessary software, set tunables
printf "\nInstalling required software and setting Dragonchain UVN system configuration...\n"
bootstrap_environment

# duck Clean this up: check for successfully running DC and prevent continuing if NOT found
# check for previous installation (failed or successful) and offer reset if found
# printf "\nChecking for previous installation...\n"
# check_existing_install

printf "\nInstalling UVN Dragonchain...\n"
install_dragonchain

check_kube_status

set_dragonchain_public_id

check_matchmaking_status

exit 0

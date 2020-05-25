#!/bin/bash

DRAGONCHAIN_INSTALLER_DIR=~/.dragonchain-installer
LOG_FILE=$DRAGONCHAIN_INSTALLER_DIR/dragonchain_certificate_update.log

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

printf "\nUpdating microk8s and refreshing certificates...\n"

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

# Install microk8s classic via snap package
# TODO - Replace with stable after microk8s.refresh-certs is stabilized
sudo snap refresh microk8s --channel=1.18/beta --classic >> $LOG_FILE 2>&1
errchk $? "Microk8s update"

# Refresh certificates just in case
sudo microk8s.refresh-certs -i >> $LOG_FILE 2>&1
errchk $? "Certificate refresh"

printf "\n\e[92mIf you see no errors above, you should be up-to-date. Check in Telegram if you still have trouble!\e[0m\n"

exit 0

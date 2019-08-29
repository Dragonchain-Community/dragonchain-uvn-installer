#!/bin/bash

# Begin Main

# Expect to exist from bootstrap_server_software.sh
LOG_FILE=/home/ubuntu/drgn.log
# if exists blah later #duck
SECURE_LOG_FILE=/home/ubuntu/secure.drgn.log
touch $SECURE_LOG_FILE

# Source our umanaged_verification_node.config
chmod u+x unmanaged_verification_node.config
. ./unmanaged_verification_node.config

# assume user executing is ubuntu with sudo privs
mkdir /home/ubuntu/setup
cd /home/ubuntu/setup

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

# Download latest Helm chart and values
# https://dragonchain-core-docs.dragonchain.com/latest/deployment/links.html
#duck this probably isn't always going to be the latest
wget https://dragonchain-core-docs.dragonchain.com/latest/_downloads/d4c3d7cc2b271faa6e8e75167e6a54af/dragonchain-k8s-0.9.0.tgz
wget https://dragonchain-core-docs.dragonchain.com/latest/_downloads/604d88c35bc090d29fe98a9e8e4b024e/opensource-config.yaml

# Modify opensource-config.yaml to our nodes specifications

# 1. ArbitraryName with nodename for sanity sake
# 2. REGISTRATION_TOKEN = "MATCHMAKING_TOKEN_FROM_CONSOLE"
# 3. REPLACE INTERNAL_ID WITH CHAIN_ID FROM CONSOLE
# 4. REPLACE DRAGONCHAIN_ENDPOINT with user address
# 5. CHANGE LEVEL TO 2
# 6. CHANGE 2 LINES FROM "storageClassName: standard" TO "storageClassName: microk8s-hostpath"
# 7. CHANGE 1 LINE FROM "storageClass: standard" TO "storageClass: microk8s-hostpath"

# 1. ArbitraryName with nodename for sanity sake
## Before inline sed:
## grep ArbitraryName opensource-config.yaml
##     DRAGONCHAIN_NAME: "ArbitraryName" # This can be anything
## After inline sed:
## grep ArbitraryName opensource-config.yaml #returns no output
## grep taco opensource-config.yaml #returns expected where node name=drgn_taco_tuesday
##     DRAGONCHAIN_NAME: "drgn_taco_tuesday" # This can be anything
sed -i "s/ArbitraryName/$DRAGONCHAIN_UVN_NODE_NAME/g" opensource-config.yaml

# 2. REGISTRATION_TOKEN = "MATCHMAKING_TOKEN_FROM_CONSOLE"
## Before inline sed:
## grep REGISTRATION_TOKEN opensource-config.yaml
##     REGISTRATION_TOKEN: "" # Use token from Dragon Net Registration (or arbitrary string if no Dragon Net)
## After inline sed:
## grep REGISTRATION_TOKEN opensource-config.yaml
##     REGISTRATION_TOKEN: "8675309" # Use token from Dragon Net Registration (or arbitrary string if no Dragon Net)
sed -i "s/REGISTRATION\_TOKEN\:\ \"\"/REGISTRATION\_TOKEN\:\ \""$DRAGONCHAIN_UVN_REGISTRATION_TOKEN"\"/g" opensource-config.yaml

# 3. REPLACE INTERNAL_ID WITH CHAIN_ID FROM CONSOLE
## Before inline sed:
## grep INTERNAL_ID opensource-config.yaml
##     INTERNAL_ID: "" # Use id from Dragon Net registration (or arbitrary string if no Dragon Net)
## After inline sed:
## grep INTERNAL_ID opensource-config.yaml
##     INTERNAL_ID: "04071776" # Use id from Dragon Net registration (or arbitrary string if no Dragon Net)
sed -i "s/INTERNAL\_ID\:\ \"\"/INTERNAL\_ID\:\ \""$DRAGONCHAIN_UVN_INTERNAL_ID"\"/g" opensource-config.yaml

# 4. REPLACE DRAGONCHAIN_ENDPOINT with user address
## Before inline sed:
## grep DRAGONCHAIN_ENDPOINT opensource-config.yaml
##     DRAGONCHAIN_ENDPOINT: "https://my-chain.api.company.org:443" # publicly accessible endpoint for this chain. MUST be able to be hit from the internet
## After inline sed:
## grep DRAGONCHAIN_ENDPOINT opensource-config.yaml

# this scenario is difficult with sed because the variable will contain // and potentially more characters

# 5. CHANGE LEVEL TO 2
## Before inline sed:
## grep 'LEVEL: "1' opensource-config.yaml #returns:
##    LEVEL: "1" # Integer 1-5 as a string. Must match with Dragon Net registration if participating in Dragon Net
## After inline sed:
## grep 'LEVEL: "1' opensource-config.yaml #returns no output
## grep 'LEVEL: "2' opensource-config.yaml #returns expected
##    LEVEL: "2" # Integer 1-5 as a string. Must match with Dragon Net registration if participating in Dragon Net
sed -i 's/LEVEL\:\ \"1/LEVEL\:\ \"2/g' opensource-config.yaml

# 6. CHANGE 2 LINES FROM "storageClassName: standard" TO "storageClassName: microk8s-hostpath"
## Before inline sed:
## grep "storageClassName: standard" opensource-config.yaml
##       storageClassName: standard
##       storageClassName: standard
## After inline sed:
## grep "storageClassName: standard" opensource-config.yaml #returns no output
## grep "storageClassName: standard" opensource-config.yaml #returns expected
sed -i 's/storageClassName\:\ standard/storageClassName\:\ microk8s\-hostpath/g' opensource-config.yaml

# 7. CHANGE 1 LINE FROM "storageClass: standard" TO "storageClass: microk8s-hostpath"
## Before inline sed:
## grep "storageClass: standard" opensource-config.yaml #returns:
##       storageClass: standard
## After inline sed:
## grep "storageClass: standard" opensource-config.yaml #returns no output
## grep "storageClass: microk8s-hostpath" opensource-config.yaml #returns expected
##       storageClass: microk8s-hostpath
sed -i 's/storageClass\:\ standard/storageClass\:\ microk8s\-hostpath/g' opensource-config.yaml

# Deploy Helm Chart
sudo helm upgrade --install SOMETHING_HERE dragonchain-k8s-0.9.0.tgz --values opensource-config.yaml dragonchain
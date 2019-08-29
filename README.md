# drgn_nodes
# UVN = Unmanaged Verification Node
Usage:

wget unmanaged_verification_node.config ; edit this file with node specific information

# bootstrap AWS Ubuntu 18.04 LTS image with necessary software & create microk8s single node cluster
wget bootstrap_server_software.sh ; chmod u+x bootstrap_server_software.sh ; ./bootstrap_server_software.sh

# Create custom .yaml file and spin up DRGN L2 node!
wget create_drgn_node.sh ; chmod u+x create_drgn_node.sh ; ./create_drgn_node.sh

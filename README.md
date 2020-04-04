# dragonchain-uvn-installer 

This project enables "easy mode" setup and installation of a Dragonchain Level 2 Unmanaged Verification Node

### Limitations:

Currently, the following limitations are in place for this script to function:
- Must be run on a Ubuntu linux installation (standard or server version)
    - Recommended server specs for the current Dragonchain release (4.1.0): 1 CPUs, 2GB RAM
- Only supports unmanaged level 2 nodes at this time (level 3+ support will come soon)

### To INSTALL a New Dragonchain Unmanaged Node:

- Clone the repo or download the **install_dragonchain_uvn.sh** file

    ```rm -f ./install_dragonchain_uvn.sh && wget https://raw.githubusercontent.com/Dragonchain-Community/dragonchain-uvn-installer/release-v3.0/install_dragonchain_uvn.sh```


- Make the script executable:

    ```chmod u+x install_dragonchain_uvn.sh```

- Run the script with sudo:

    ```sudo ./install_dragonchain_uvn.sh```

### To UPGRADE a Running Dragonchain Unmanaged Node:

- Clone the repo or download the **upgrade_dragonchain_uvn.sh** file

    ```rm -f ./upgrade_dragonchain_uvn.sh && wget https://raw.githubusercontent.com/Dragonchain-Community/dragonchain-uvn-installer/release-v3.0/upgrade_dragonchain_uvn.sh```


- Make the script executable:

    ```chmod u+x upgrade_dragonchain_uvn.sh```

- Run the script with sudo:

    ```sudo ./upgrade_dragonchain_uvn.sh```

### Coming features:
- Support for pre-built config files for easy automatic deployment

*Dragonchain-Community and this project are not affiliated with Dragonchain, Inc. or the Dragonchain Foundation*

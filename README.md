# dragonchain-uvn-installer 

This project enables "easy mode" setup and installation of a Dragonchain Level 2 Unmanaged Verification Node

### Limitations:

Currently, the following limitations are in place for this script to function:
- Must be run on a Ubuntu linux installation (standard or server version)
    - Recommended server specs for the current Dragonchain release (3.5.0): 2 CPUs, 8GB RAM
- Only supports unmanaged level 2 nodes at this time (level 3+ support will come soon)

### Usage:

- Clone the repo or download the [install_dragonchain_uvn.sh](https://dragonchain-community.github.io/dragonchain-uvn-installer/install_dragonchain_uvn.sh) file
```wget https://dragonchain-community.github.io/dragonchain-uvn-installer/install_dragonchain_uvn.sh```

- Make the script executable:
```chmod u+x install_dragonchain_uvn.sh```

- Run the script with sudo:
```sudo ./install_dragonchain_uvn.sh```

### Coming features:
- Support for pre-built config files for easy automatic deployment
- Sanity checks for user input to prevent downstream problems

*Dragonchain-Community and this project are not affiliated with Dragonchain, Inc. or the Dragonchain Foundation*

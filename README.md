# dragonchain-uvn-installer 

This project enables "easy mode" setup and installation of multiple Dragonchain Level 2 , 3 and 4 Unmanaged Verification Nodes

### Limitations:

Currently, the following limitations are in place for this script to function:
- Must be run on a Ubuntu linux installation (standard or server version)
    - Recommended server specs for the current Dragonchain release: 1 CPUs, 2GB RAM (more CPU and RAM may be required for additional nodes)
	- Raspberry Pi 2GB, 4GB and 8GB supported. The installer will detect the Raspberry Pi hardware and install with the required CPU limits

### NOTE: IF YOUR NODE GOES UNHEALTHY ALL OF A SUDDEN, FOLLOW THE NEXT INSTRUCTIONS:

An issue with microk8s (not Dragonchain or our software) has been discovered that can cause nodes (especially those installed after approximately April 1st 2020) to go into "unhealthy" status because they aren't able to process blocks.

If you run into this problem, SSH into your node and run the following command:

```wget https://raw.githubusercontent.com/Dragonchain-Community/dragonchain-uvn-installer/hotfix-certificates/update_certificates.sh && chmod u+x update_certificates.sh && sudo ./update_certificates.sh```
    
If, after running, you don't see all "1/1" and "Running" for the status of your pods, please try running the following command to check the status continuously:

```sudo watch kubectl get pods --all-namespaces```

Terminate the watch with CTRL + C


If you still don't see all "1/1" and "Running," check in Telegram for support.


### To INSTALL New Dragonchain Unmanaged Node/s:

- Clone the repo or download the **install_dragonchain_uvn.sh** file

    ```rm -f ./install_dragonchain_uvn.sh && wget https://raw.githubusercontent.com/Dragonchain-Community/dragonchain-uvn-installer/release-v5.0/install_dragonchain_uvn.sh```


- Make the script executable:

    ```chmod u+x install_dragonchain_uvn.sh```

- Run the script with sudo:

    ```sudo ./install_dragonchain_uvn.sh```
	
- Additional nodes can be installed by choosing option [yes] when prompted at the end of the initial node installation.


### To UPGRADE Running Dragonchain Unmanaged Node/s:

- Run the same script with sudo:

    ```sudo ./install_dragonchain_uvn.sh```

- When the installer loads, it should detect pre-existing Dragonchain nodes. Choose option [u] to upgrade all installed Dragonchains.


- To check the chart version number your Dragonchain nodes are running:

	```sudo helm list --all-namespaces```


### Coming features:

- Support for pre-built config files for easy automatic deployment

*Dragonchain-Community and this project are not affiliated with Dragonchain, Inc. or the Dragonchain Foundation*

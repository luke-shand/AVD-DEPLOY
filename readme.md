# AVD-DEPLOY
Azure Virtual Desktop Deployment and Update Automation via Azure DevOps

This code was designed to be used to deploy and update Azure Virtual Desktop environments.

The automation allows for 

-	Create brand new Greenfield AVD environment. New Host Pool, Application Group, Session Hosts.
-	Update an existing Host Pool to use new Session Hosts from an updated image.
-	Scale out an existing Host Pool to add additional Session Hosts.

This repository contains a number of PowerShell Scripts. That are used inside Azure DevOps pipelines.

In the **WVDDeploy** folder you will find the following scripts.

**PreBuild.ps1**

This script is used as part of the main deployment and performs a checking to determine what Shared Image Gallery Version Name to use for deployment, and the Session Host VM numbering.
It also contains logic to create a **Version** tag that will be placed onto the Virtual Machine to mark each Session Host with the deployed Version Name.

**Cleanup.ps1**

This script is used to run a post update cleanup. This is run if the main Deployment task is triggered as a update. If so the cleanup script will run to do the following:
- Send Message to all logged in users (old Session Host)
- Log off users (old Session Host)
- Tag VMs with **Remove** equal to **True**

**DestroySessionHosts.ps1**

This script can be used by a standalone Pipeline to obtain a list of Session Host VMs that **Remove** tag is equal to **True** and if so will do the following:
- Remove Session Host VM from Host Pool
- Remove Session Host VM
- Remove all VM Dependencies (NIC, OS Disk etc)

In the **WVDUpdate** folder is a single PowerShell script and a Packer.JSON file.

**PreBuild.ps1**

This script is used to automatically obtain the current latest Shared Image Gallery Version Name for the required Definition. 
It also then generates the new version number based on:

_**MajorVersion.MinorVersion.PatchVersion*_

MajorVersion = Main version
MinorVersion = Patch month (i.e. 08 for August)
PatchVersion = Sub patch level (if patched multiple times in a month)

The VMName will then be generate as below:

**VMPrefix-MinorVersion-PatchVersion-VM number**

e.g: **PROD-08-0-0**

Of course this can be changed as required.

**Packer.json**

This JSON file contains the base Packer configuration to perform the following:
- Deploy VM from existing Shared Image Gallery Definition
- Run Windows Updates on the deployed VM
- Sysprep the VM
- Capture VM into new Shared Image Gallery Definition Version.
 
View my blog post at 

<link to come>

for full information on how this was created.

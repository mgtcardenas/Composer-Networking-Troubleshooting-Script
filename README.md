# Composer Networking Troubleshooting Script

## Overview

### Objective
Rule out firewall rules as an issue for creating a Composer environment.

### Intended Audience
 - Google Cloud Platform customers
 - Cloud Composer users in general

### General Procedure
This script will...
 
 1.  Report the status of the environment's GKE cluster creation until it succeeds or fails (if a GKE cluster creation operation not older than 10 minutes can be found)
 2.  Run the necessary connectivity tests to verify the connectivity mentioned in https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules
     1.  If a test fails, it will print the details so you can know why that connectivity is not currently possible

All tests will be done with a sample VM in your environment's GKE cluster as a source (provided your GKE cluster can create successfully).


### Visibility
The connectivity tests can be found in http://console.cloud.google.com/net-intelligence/connectivity/tests/ as they are being executed.
Users are encouraged to check the code by themselves in https://github.com/mgtcardenas/Composer-Networking-Troubleshooting-Script.

For more information on...
 - Composer requirements for Firewall rules, see https://cloud.google.com/composer/docs/composer-2/configure-private-ip
 - Connectivity tests, see https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/how-to/running-connectivity-tests
 - Connectivity test permissions, see https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/concepts/access-control

### Requirements
- Cloud SDK (to run `gcloud` commands)
- A running Composer environment creation attempt (otherwise, VMs are deleted and connectivity tests can't be performed)
- `Network Management Admin (roles/networkmanagement.admin)` (required to create and run connectivity tests)
  - In case the environment is Shared VPC, this role must be granted both in...
     - The service project (where Composer env. will get created)
     - The network host project (where the env. VPC network is hosted)
  
      Otherwise, the role is only necessary in the service project.
- GNU `coreutils` (if you wish to have a timeout and not run from `cloud Shell`)

## How To Use 
1. Download the latest version of this repo (either through `git clone` or by downloading it as a zip)
1. Begin the Composer environemnt creation
1. Run `composerNetValidation.sh` within 10 minutes of initiating the Composer environment creation operation. It is **recommended that you run the script from within `Cloud Shell`**.
   - (if necessary) make the script executable by running:
     ```
     chmod +x composerNetValidation.sh
     ```
   - (if not done already) log into the GCP project
      ```
      gcloud init
      ```
      
      **Note**: This project should be the service project (i.e. where the Composer environment will be created).
      Not to be confused with the network host project (i.e. the project that hosts the environment's VPC network).
   - Execute the bash script by running
      ```
      bash composerNetValidation.sh
      ```
      or
      ```
      ./composerValidation.sh
      ```
      If you want the script to timeout (after 25 minutes), execute the following command instead
      ```
      bash runWithTimeout.sh
      ```
      Doing this will require the `timeout` command part of the `coreutils` package.
  `Cloud Shell` has this command available.

1. Follow instruction and enter the details as prompted


### Requested Information
At some point, the script will ask the following:
 - Whether you want the connectivity tests to persist after running the script (`Yes` or `No`)
   - You could find the tests in http://console.cloud.google.com/net-intelligence/connectivity/tests/
 - Evironment's location (e.g. `us-central1`)
 - Select the Composer environment to troubleshoot from a list
 - The type of connectivity to Google APIs and Services you have configured:
   - `restricted.googleapis.com` (https://cloud.google.com/composer/docs/composer-2/configure-vpc-sc#connectivity-restricted) 
     - `199.36.153.4`, `199.36.153.5`, `199.36.153.6`, `199.36.153.7`
   - `private.googleapis.com` (https://cloud.google.com/composer/docs/composer-2/configure-private-ip#connectivity-domains)
     - `199.36.153.8`, `199.36.153.9`, `199.36.153.10`, `199.36.153.11`
   - Pubilc Google APIs
     - For example, `172.217.4.187`. You can use `dig` command to discover public-facing IPs of services like `storage.googleapis.com`.
 - (Optional) An example Pod IP (in case you don't want to wait until the script is able to find a pod IP in `Cloud Logging`).

### Caveats
 - There's a small chance that the connectivity tests could persist unexpectedly if there's a problem deleting them or if the script is terminated (CTRL + C) before issuing the delete request. If you are concerned about this leftover tests, please double check that no unwanted tests remain in http://console.cloud.google.com/net-intelligence/connectivity/tests/
 - It is theoratically possible that some quota limit is reached because of running this script (since `gcloud` commands are used to poll for GKE cluster's creation operation). The script will try to use an exponential-backoff strategy to avoid this. But please consider that it is still the user's responsibility to guard against quota being depleted.
 - As the cluster VMs are newly created, there's a chance that some tests will fail because the VM was not yet ready. When this happens, rerunning the test often succeeds (proving there was no issue in the networking setup).
 - **Only Composer 2** (both with Private Service Connect or VPC Peerings) is currently supported. Composer 1 environments may be supported in the near future.
 - You should always try to run the latest version of the script. There are constant improvements being added. Please try running the script from this other repo: https://github.com/NathaliCo/Composer-Get-Validation-Script. The script there downloads the latest version of the script everytime.
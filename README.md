# Composer Networking Troubleshooting Script

### Supports
* Networking validation for Cloud Composer.

### Prerequisites:
* Cloud SDK
* A Composer environment creation attempt

### How to use: 
* Download the latest version of this repo
* Make the script executable by running,
  ```
  chmod +x composerNetValidation.sh
  ```
* Log into the GCP project
  ```
  gcloud init
  ```
  This project should be the service project (i.e. where the Composer environment will be created).
  Not to be confused with the network host project (i.e. the project that hosts the environment's VPC network).
* Execute the bash script by running
  ```
  ./composerValidation.sh
  ```
  or
  ```
  bash composerNetValidation.sh
  ```
  If you want the script to timeout (after 25 minutes), execute the following command instead
  ```
  bash runWithTimeout.sh
  ```
  Doing this will require the `timeout` command part of the `coreutils` package.
  `Cloud Shell` has this command available.

Follow instruction and enter the details as prompted.
* Attempt to create the Composer environment

The script will let you know what is networking aspect is preventing the environment from getting created.
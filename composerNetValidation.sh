#/bin/bash

source ./steps.sh

#color theme
red=$'\e[31m'
green=$'\e[32m'
yellow=$'\e[33m'
blue=$'\e[34m'
nc=$'\e[0m'
bold=$(tput bold)
normal=$(tput sgr0)

project_id=$(gcloud config list core/project --format='value(core.project)')

echo "${yellow}This troubleshooting script will run a series of ${bold}connectivity tests${normal}${yellow}"
echo "to ${bold}rule out Firewall rules${normal}${yellow} as an issue for creating your Composer environment."
echo
echo "All tests will be done with a sample VM in your environment's GKE cluster as a source"
echo "(provided your GKE cluster can create successfully)."
echo "The connectivity tests can be found in http://console.cloud.google.com/net-intelligence/connectivity/tests/ as they are being executed."
echo "You can always check the code yourself in https://github.com/mgtcardenas/Composer-Networking-Troubleshooting-Script"
echo
echo "A user must have ${bold}'Network Management Admin (roles/networkmanagement.admin)'${normal}${yellow} role to create and run connectivity tests."
echo "If you don't have this role granted, either..."
echo " a) Impersonate a service account that does have this permission"
echo " b) Stop running this script and get the permission from your project administrator"
echo
echo "${bold}IMPORTANT${normal}${yellow}: In case the environment is Shared VPC, this role must be granted both in..."
echo " - The service project (where Composer env. will get created)"
echo " - The network host project (where the env. VPC network is hosted)"
echo "Otherwise, the role is only necessary in the service project."
echo
echo "For more information on..."
echo " - Composer requirements for Firewall rules, see https://cloud.google.com/composer/docs/composer-2/configure-private-ip"
echo " - Connectivity tests, see https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/how-to/running-connectivity-tests"
echo " - Connectivity test permissions, see https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/concepts/access-control"
echo
echo "You should run this script right after starting to create your environment."
echo "You'll only need to provide your environment's location (e.g. 'us-central1') and select your environment from a list."
echo "The script should be run in the service project (the project that will host the Composer environment)."
echo "The current targeted project is ${bold}$project_id${normal}${yellow}."
echo "${bold}If this is NOT the service project, please stop and run the script in the correct project${normal}${yellow}."
echo

echo -n "${bold}DO YOU WISH TO CONTINUE? (Enter for default 'Yes') [Yes/No]${normal}${yellow}: "
IFS= read -r go_on
go_on=${go_on:-"Yes"}
echo

if [ "$go_on" != "Yes" ]; then
    exit 0
fi

echo -n "${bold}DO YOU WANT THE CONNECTIVITY TESTS TO PERSIST AFTER RUNNING THE SCRIPT (Enter for default 'No')? [Yes/No]${normal}${yellow}: "
IFS= read -r persist_tests
persist_tests=${persist_tests:-"No"}
echo "${nc}${normal}"

#### Obtaining necessary values ####
echo -n "${bold}Env. Location (Enter for default 'us-central1')${normal}: "
IFS= read -r location
location=${location:-"us-central1"}
echo

echo "${bold}Select composer instance to troubleshoot...${normal}"
select env_name in $(gcloud composer environments list --locations=$location --format='value(name)'); do
    if [ -z "$env_name" ]; then
        echo "${bold}Invalid selection${normal}"
    else
        echo "${bold}You have selected composer instance${normal}: $env_name"
        break
    fi
done

network=$(gcloud composer environments describe "$env_name" \
    --location="$location" \
    --format="value(config.nodeConfig.network)")
network=${network:-"projects/$project_id/global/networks/default"}
echo

# Get a pair of VMs to perform the connectivity test
# TODO: consider using `gcloud container operations list` to determine if and when the GKE cluster has been successfully created
while [ true ]; do
    # The following command returns a string of VM self links, but not an array
    # Self link is the closest thing to what we want (Instance ID); self link is in the form "https://www.googleapis.com/compute/v1/projects/<project>/zones/<zone>/instances/<instance-name>"
    self_links=$(gcloud compute instances list \
        --format='[no-heading](selfLink)' \
        --filter="labels.goog-composer-environment='$env_name'")
    if [ -z "$self_links" ]; then
        echo "No VMs to perform the tests yet..."
    else
        echo "At least one VM has been found..."
        echo
        sleep 3
        break
    fi
    sleep 3
done

vms=($self_links) # casts the string into an array of strings

if [ -z "$vms" ]; then
    echo "I couldn't find VMs with labels containing env. name"
    break
elif [ ${#vms[@]} -gt 1 ]; then # we have enough VMs to do the test
    echo "Found the following VMs..."
    echo
    printf '%s\n' "${vms[@]}"
    echo

    echo "Performing the tests..."
    # Strip "https://www.googleapis.com/compute/v1/projects/" from ${vms[0]}
    source_vm_id=$(echo "${vms[0]}" | awk '{print substr($0,39)}') # consider doing '{print substr($0,39);exit}'
    # Strip "https://www.googleapis.com/compute/v1/projects/" from ${vms[1]}
    destination_vm_id=$(echo "${vms[1]}" | awk '{print substr($0,39)}') # consider doing '{print substr($0,39);exit}'

    # TODO: We don't actually need to pass the parameters, we can just use the variable names :O
    test_node_to_node

    # Get GKE cluster name
    gke_cluster_name=$(gcloud container clusters list \
        --format="[no-heading](name)" \
        --filter="resourceLabels.goog-composer-environment='$env_name'")

    # Craft the GKE instance ID
    gke_instance_id="projects/$project_id/locations/$location/clusters/$gke_cluster_name"

    test_node_to_gke_control_plane

    test_node_to_pod

    test_node_to_google_services

    conn_type=$(gcloud composer environments describe $env_name \
        --location=$location \
        --format="table[no-heading](config.privateEnvironmentConfig.networkingConfig.connectionType)")

    if [ "$conn_type" == "VPC_PEERING" ]; then
        test_node_to_peering_range 
    else
        test_node_to_psc
    fi

    # TODO: Give a summary at the end of the number of tests that succeeded
fi

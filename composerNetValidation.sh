#/bin/bash

project_id=$(gcloud config list core/project --format='value(core.project)')

#### Obtaining necessary values ####
#### Get these values through gcloud command
echo -n "${bold}Composer Env. Name (Enter for default "my-shared-vpc-env")${normal}: "
IFS= read -r env_name
env_name=${env_name:-"my-shared-vpc-env"}
echo

echo -n "${bold}Env. Network ID (Enter for default VPC from my-other-project)${normal}: "
IFS= read -r network
network=${network:-"projects/my-other-project-737981/global/networks/default"}
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
        echo "VMs found!"
        sleep 3
        break
    fi
    sleep 3
done

# The following command casts the string into an array
vms=($self_links)

if [ -z "$vms" ]; then
    echo "I couldn't find VMs with labels containing env. name"
    break
elif [ ${#vms[@]} -gt 1 ]; then # we have enough VMs to do the test
    # Strip "https://www.googleapis.com/compute/v1/projects/" from ${vms[0]}
    source_vm_id=$(echo "${vms[0]}" | awk '{print substr($0,39)}') # consider doing '{print substr($0,39);exit}'
    # Strip "https://www.googleapis.com/compute/v1/projects/" from ${vms[1]}
    destination_vm_id=$(echo "${vms[1]}" | awk '{print substr($0,39)}') # consider doing '{print substr($0,39);exit}'

    # Perform the connectivity test
    # IMPORTANT: If you mix the VMs together, this won't work out due to the zones; we absolutely need the right zones
    # TODO: Append the name of the env. to the connectivity tests
    gcloud beta network-management connectivity-tests create $env_name-node-to-node \
        --destination-instance="$destination_vm_id" \
        --destination-network="$network" \
        --destination-port="80" \
        --protocol="TCP" \
        --source-instance="$source_vm_id" \
        --source-network="$network" \
        --project="$project_id"
fi

# Interpret the results of the connectivity test
sleep 5 # Give it time
node_to_node_result=$(gcloud beta network-management connectivity-tests describe $env_name-node-to-node \
    --format='table[no-heading](reachabilityDetails.result)')

if [ $node_to_node_result == "REACHABLE" ]; then
    echo "No issues in Node to Node Connectivity"
else
    echo "Issues in Node to Node Connectivity"
    echo "Does your environment meet the following requirement?"
    echo "https://cloud.google.com/composer/docs/composer-2/configure-private-ip#:~:text=Environment%27s%20cluster%20Nodes,all"
fi

# Delete the connectivity test
sleep 5
gcloud network-management connectivity-tests delete $env_name-node-to-node \
    --async \
    -q
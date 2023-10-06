#/bin/bash

source ./steps.sh

project_id=$(gcloud config list core/project --format='value(core.project)')

#### Obtaining necessary values ####
#### TODO: Get these values through gcloud command
echo -n "Composer Env. Name (Enter for default "my-shared-vpc-env"): "
IFS= read -r env_name
env_name=${env_name:-"my-shared-vpc-env"}
echo

echo -n "Env. Network ID (Enter for default VPC from my-other-project): "
IFS= read -r network
network=${network:-"projects/my-other-project-737981/global/networks/default"}
echo

echo -n "Env. Location (Enter for default "us-central1": "
IFS= read -r location
location=${location:-"us-central1"}
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

vms=($self_links) # casts the string into an array of strings

if [ -z "$vms" ]; then
    echo "I couldn't find VMs with labels containing env. name"
    break
elif [ ${#vms[@]} -gt 1 ]; then # we have enough VMs to do the test
    # Strip "https://www.googleapis.com/compute/v1/projects/" from ${vms[0]}
    source_vm_id=$(echo "${vms[0]}" | awk '{print substr($0,39)}') # consider doing '{print substr($0,39);exit}'
    # Strip "https://www.googleapis.com/compute/v1/projects/" from ${vms[1]}
    destination_vm_id=$(echo "${vms[1]}" | awk '{print substr($0,39)}') # consider doing '{print substr($0,39);exit}'

    # TODO: We don't actually need to pass the parameters, we can just use the variable names :O
    test_node_to_node "$env_name" "$destination_vm_id" "$network" "$source_vm_id" "$project_id"

    # Get GKE cluster name
    gke_cluster_name=$(gcloud container clusters list \
        --format="[no-heading](name)" \
        --filter="resourceLabels.goog-composer-environment='$env_name'")

    # Craft the GKE instance ID
    gke_instance_id="projects/$project_id/locations/$location/clusters/$gke_cluster_name"

    test_node_to_gke_control_plane "$env_name" "$gke_instance_id" "$source_vm_id" "$network" "$project_id"

    test_node_to_pod "$env_name" "$network" "$gke_cluster_name" "$project_id" "$source_vm_id"

    test_node_to_google_services "$env_name" "$source_vm_id" "$network" "$project_id"
fi
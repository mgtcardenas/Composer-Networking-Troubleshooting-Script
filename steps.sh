test_node_to_node() {
    # Perform the connectivity test
    gcloud beta network-management connectivity-tests create $1-node-to-node \
        --destination-instance="$2" \
        --destination-network="$3" \
        --destination-port="80" \
        --protocol="TCP" \
        --source-instance="$4" \
        --source-network="$3" \
        --project="$5"

    # Interpret the results of the connectivity test
    sleep 5 # Give it time
    result=$(gcloud beta network-management connectivity-tests describe $1-node-to-node \
        --format='table[no-heading](reachabilityDetails.result)')

    if [ $result == "REACHABLE" ]; then
        echo
        echo "No issues in Node to Node Connectivity"
        echo
    else
        echo
        echo "Issues in Node to Node Connectivity"
        echo "Does your environment meet the following requirement?"
        echo "https://cloud.google.com/composer/docs/composer-2/configure-private-ip#:~:text=Environment%27s%20cluster%20Nodes,all"
        echo
    fi

    # Delete the connectivity test
    sleep 5
    gcloud network-management connectivity-tests delete $1-node-to-node \
        --async \
        -q
} # end test_node_to_node

test_node_to_gke_control_plane() {
    # Perform the connectivity test
    gcloud beta network-management connectivity-tests create $1-node-to-gke-control-plane \
        --destination-gke-master-cluster="$2" \
        --destination-port=443 \
        --protocol=TCP \
        --source-instance="$3" \
        --source-network="$4" \
        --project="$5"

    # Interpret the results of the connectivity test
    sleep 5 # Give it time
    result=$(gcloud beta network-management connectivity-tests describe $1-node-to-gke-control-plane \
        --format='table[no-heading](reachabilityDetails.result)')

    if [ $result == "REACHABLE" ]; then
        echo
        echo "No issues in Node to GKE Control Plane Connectivity"
        echo
    else
        echo
        echo "Issues in Node to GKE Controrl Plane Connectivity"
        echo "Does your environment meet the following requirement?"
        echo "https://cloud.google.com/composer/docs/composer-2/configure-private-ip#:~:text=Environment%27s%20cluster%20Control,all"
        echo
    fi

    # Delete the connectivity test
    sleep 5
    gcloud network-management connectivity-tests delete $1-node-to-gke-control-plane \
        --async \
        -q
} # end test_node_to_gke_control_plane

test_node_to_pod() {
    # Get the pod IP
    query='resource.labels.cluster_name="'$3'" jsonPayload.message=~".*conn-id:.*composer.*airflow-worker" resource.labels.container_name="gke-metadata-server"'

    result=$(gcloud logging read "$query" \
        --limit=1 \
        --format="value(jsonPayload.message)")

    tmp_result=($result)                                           # something like... [conn-id:692e22c0b2112e12 ip:10.55.0.4 pod:composer-2-4-4-airflow-2-5...
    pod_ip=$(echo "${tmp_result[1]}" | awk '{print substr($0,4)}') # consider doing '{print substr($0,39);exit}'
    pod_ip=$(echo "$pod_ip" | xargs)                               # remove possible trailing space just in case

    # Perform the test
    gcloud beta network-management connectivity-tests create $1-node-to-pod \
        --destination-ip-address="$pod_ip" \
        --destination-network="$2" \
        --destination-port=80 \
        --destination-project="$4" \
        --protocol=TCP \
        --source-instance="$5" \
        --source-network="$2" \
        --project="$4"

    # Interpret the results of the connectivity test
    sleep 5 # Give it time
    result=$(gcloud beta network-management connectivity-tests describe $1-node-to-pod \
        --format='table[no-heading](reachabilityDetails.result)')

    if [ $result == "REACHABLE" ]; then
        echo
        echo "No issues in Node to Pod Connectivity"
        echo
    else
        echo "Issues in Node to Pod Connectivity"
        echo "Does your environment meet the following requirement?"
        echo "https://cloud.google.com/composer/docs/composer-2/configure-private-ip#:~:text=Environment%27s%20cluster%20Pods,all"
        echo
    fi

    # Delete the connectivity test
    sleep 5
    gcloud network-management connectivity-tests delete $1-node-to-pod \
        --async \
        -q

} # end test_node_to_pod

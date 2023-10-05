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
    gcloud network-management connectivity-tests delete $1-node-to-node \
        --async \
        -q
} # end test_node_to_node
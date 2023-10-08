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

    interpret_test "$1-node-to-node" "Node to Node"

    delete_test "$1-node-to-node"
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

    interpret_test "$1-node-to-gke-control-plane" "Node to GKE Control Plane"

    delete_test "$1-node-to-gke-control-plane"
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

    interpret_test "$1-node-to-pod" "Node to Pod"

    delete_test "$1-node-to-pod"
} # end test_node_to_pod

test_node_to_google_services() {

    zone_name=$(gcloud dns managed-zones list \
        --format="[no-heading](name)" \
        --filter="dnsName:composer.cloud.google.com.")

    result=$(gcloud dns record-sets list \
        --zone="$zone_name" \
        --format="[no-heading](rrdatas)")

    arr=($result)

    ip=$(echo "${arr[0]}" | awk '{ print substr( $0, 3, length($0)-4 ) }')

    if [ "$ip" = "199.36.153.4" ]; then
        echo "You are trying to use 'restricted.googleapis.com'"
    elif [ "$ip" = "199.36.153.8"]; then
        echo "You are trying to use 'private.googleapis.com'"
    else
        echo "You are trying to contact public-serving IPs"
        ip="172.217.4.187"
    fi

    gcloud beta network-management connectivity-tests create $1-node-to-goog-services \
        --destination-ip-address="$ip" \
        --destination-port=443 \
        --protocol=TCP \
        --source-instance="$2" \
        --source-network="$3" \
        --project="$4"

    interpret_test "$1-node-to-goog-services" "Node to Google Services"

    delete_test "$1-node-to-goog-services"
} # end test_node_to_google_services

test_node_to_psc() {
    psc_name=$(gcloud compute forwarding-rules list \
        --format="[no-heading](name)" \
        --filter="labels.goog-composer-environment='$1'")

    psc_id="projects/$2/regions/$3/forwardingRules/$psc_name"

    gcloud beta network-management connectivity-tests create $1-node-to-psc \
        --destination-forwarding-rule="$psc_id" \
        --destination-port=3306 \
        --protocol=TCP \
        --source-instance="$4" \
        --source-network="$5" \
        --project="$2"

    interpret_test "$1-node-to-psc" "Node to PSC Endpoint"

    delete_test "$1-node-to-psc"
} # end test_node_to_psc

interpret_test() {
    sleep 5 # Give it time

    result=$(gcloud beta network-management connectivity-tests describe "$1" \
        --format='table[no-heading](reachabilityDetails.result)')

    if [ $result == "REACHABLE" ]; then
        echo
        echo "No issues in $2 Connectivity"
        echo
    else
        echo "Issues in $2 Connectivity"
        echo "Does your environment meet the following requirement?"

        case $2 in
        "Node to Node")
            echo "https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=Environment%27s%20cluster%20Nodes,all"
            ;;

        "Node to GKE Control Plane")
            echo "https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=Environment%27s%20cluster%20Control,all"
            ;;

        "Node to Pod")
            echo "https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=Environment%27s%20cluster%20Pods,all"
            ;;

        "Node to Google Services")
            echo "https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=53-,Google%20APIs%20and%20services,443,-Environment%27s%20cluster%20Nodes"
            ;;

        "Node to PSC Endpoint")
            echo "https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=(If%20your%20environment%20uses%20Private,3306%2C%203307"
            ;;
        esac
        echo
    fi
} # interpret_test

delete_test() {
    sleep 5 # Give it time
    gcloud network-management connectivity-tests delete "$1" \
        --async \
        -q
} # delete_test

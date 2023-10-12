test_node_to_node() {
    # TODO: Display the primary range and say from where to where we are doing the test
    echo
    echo "${bold}Performing Node to Node test...${normal}"
    echo "See the following for reference: "
    echo " - https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=Environment%27s%20cluster%20Nodes,all"
    echo
    echo "${bold}Test Name${normal}:            $env_name-node-to-node"
    echo "${bold}Destination Instance${normal}: $destination_vm_id"
    echo "${bold}Destination Port${normal}:     443"
    echo "${bold}Protocol${normal}:             TCP"
    echo "${bold}Source Intance${normal}:       $source_vm_id"
    echo

    # Perform the connectivity test
    # TODO: Test for a random number for the port; though be cautios that there are some ports that are blocked always
    # TODO: Also test for a random port in UDP
    gcloud beta network-management connectivity-tests create $env_name-node-to-node \
        --destination-instance="$destination_vm_id" \
        --destination-port="443" \
        --protocol="TCP" \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-node" "Node to Node"

    delete_test "$env_name-node-to-node"
} # end test_node_to_node

test_node_to_gke_control_plane() {
    echo
    echo "${bold}Performing Node to GKE Control Plane test...${normal}"
    echo "See the following for reference: "
    echo " - https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=Environment%27s%20cluster%20Control,all"
    echo
    echo "${bold}Test Name${normal}:                        $env_name-node-to-gke-control-plane"
    echo "${bold}Destination GKE Master Cluster${normal}:   $gke_instance_id"
    echo "${bold}Destination Port${normal}:                 443"
    echo "${bold}Protocol${normal}:                         TCP"
    echo "${bold}Source Instance${normal}:                  $source_vm_id"
    echo

    # Perform the connectivity test
    gcloud beta network-management connectivity-tests create $env_name-node-to-gke-control-plane \
        --destination-gke-master-cluster="$gke_instance_id" \
        --destination-port="443" \
        --protocol="TCP" \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-gke-control-plane" "Node to GKE Control Plane"

    delete_test "$env_name-node-to-gke-control-plane"
} # end test_node_to_gke_control_plane

test_node_to_pod() {
    echo
    echo "${bold}Performing Node to Pod test...${normal}"
    echo "See the following for reference: "
    echo " - https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=Environment%27s%20cluster%20Pods,all"
    echo

    # Get the pod IP
    query='resource.labels.cluster_name="'$gke_cluster_name'" jsonPayload.message=~".*conn-id:.*composer.*airflow-worker" resource.labels.container_name="gke-metadata-server"'

    result=$(gcloud logging read "$query" \
        --limit=1 \
        --format="value(jsonPayload.message)")

    tmp_result=($result)                                           # something like... [conn-id:692e22c0b2112e12 ip:10.55.0.4 pod:composer-2-4-4-airflow-2-5...
    pod_ip=$(echo "${tmp_result[1]}" | awk '{print substr($0,4)}') # consider doing '{print substr($0,39);exit}'
    pod_ip=$(echo "$pod_ip" | xargs)                               # remove possible trailing space just in case

    # TODO: Display the pods secondary range (from composer list operation)
    # Say we are usng <EXAMPLE_IP> as part of this test

    echo "${bold}Test Name${normal}:                $env_name-node-to-pod"
    echo "${bold}Destination IP Address${normal}:   $pod_ip"
    echo "${bold}Destination Port${normal}:         80"
    echo "${bold}Protocol${normal}:                 TCP"
    echo "${bold}Destination Project${normal}:      $project_id"
    echo "${bold}Source Instance${normal}:          $source_vm_id"
    echo

    # Perform the test
    gcloud beta network-management connectivity-tests create $env_name-node-to-pod \
        --destination-ip-address="$pod_ip" \
        --destination-port=80 \
        --destination-project="$project_id" \
        --protocol=TCP \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-pod" "Node to Pod"

    delete_test "$env_name-node-to-pod"
} # end test_node_to_pod

test_node_to_google_services() {
    echo
    echo "${bold}Performing Node to Google Services test...${normal}"
    echo "See the following for reference: "
    echo " - https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=53-,Google%20APIs%20and%20services,443,-Environment%27s%20cluster%20Nodes"
    echo

    # TODO: Will you be contacting restricted private or none of those?
    # Last part to verify is the DNS check
    # We could try to create a GKE cluster that creates a workload that downloads resources from artifact registry

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

    echo "${bold}Test Name${normal}:                $env_name-node-to-goog-services"
    echo "${bold}Destination IP Address${normal}:   $ip"
    echo "${bold}Destination Port${normal}:         443"
    echo "${bold}Protocol${normal}:                 TCP"
    echo "${bold}Source Instance${normal}:          $source_vm_id"
    echo

    gcloud beta network-management connectivity-tests create $env_name-node-to-goog-services \
        --destination-ip-address="$ip" \
        --destination-port=443 \
        --protocol=TCP \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-goog-services" "Node to Google Services"

    delete_test "$env_name-node-to-goog-services"
} # end test_node_to_google_services

test_node_to_psc() {
    echo
    echo "${bold}Performing Node to PSC Endpoint test...${normal}"
    echo "See the following for reference: "
    echo " - https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=(If%20your%20environment%20uses%20Private,3306%2C%203307"
    echo

    psc_name=$(gcloud compute forwarding-rules list \
        --format="[no-heading](name)" \
        --filter="labels.goog-composer-environment='$env_name'")

    psc_id="projects/$project_id/regions/$location/forwardingRules/$psc_name"

    echo "${bold}Test Name${normal}:                                        $env_name-node-to-psc"
    echo "${bold}Destination Forwarding Rule (aka. PSC Endpoint)${normal}:  $psc_id"
    echo "${bold}Destination Port${normal}:                                 3306"
    echo "${bold}Protocol${normal}:                                         TCP"
    echo "${bold}Source Instance${normal}:                                  $source_vm_id"
    echo

    gcloud beta network-management connectivity-tests create $env_name-node-to-psc \
        --destination-forwarding-rule="$psc_id" \
        --destination-port=3306 \
        --protocol=TCP \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-psc" "Node to PSC Endpoint"

    delete_test "$env_name-node-to-psc"

    # TODO: We should test for the 3307 port as well
} # end test_node_to_psc

test_node_to_peering_range() {
    echo
    echo "${bold}Performing Node to Peering Range test...${normal}"
    echo "See the following for reference: "
    echo " - https://cloud.google.com/composer/docs/composer-2/configure-private-ip#private-ip-firewall-rules:~:text=(If%20your%20environment%20uses%20VPC,3306%2C%203307"
    echo

    peering_range=$(gcloud composer environments describe $env_name \
        --location=$location \
        --format="table[no-heading](config.privateEnvironmentConfig.cloudComposerNetworkIpv4ReservedRange)")

    ip=$(echo "$peering_range" | awk '{split($0,a,"/"); print a[1]}') # split by /

    first_octet=$(echo "$ip" | awk '{split($0,a,"."); print a[1]}')
    second_octet=$(echo "$ip" | awk '{split($0,a,"."); print a[2]}')
    third_octet=$(echo "$ip" | awk '{split($0,a,"."); print a[3]}')
    last_octet=$(echo "$ip" | awk '{split($0,a,"."); print a[4]}') # split by .
    let "last_octet++"
    ip="$first_octet.$second_octet.$third_octet.$last_octet" # join back together

    echo "${bold}Test Name${normal}:                $env_name-node-to-peering-range"
    echo "${bold}Destination IP Address${normal}:   $ip"
    echo "${bold}Destination Port${normal}:         3306"
    echo "${bold}Protocol${normal}:                 TCP"
    echo "${bold}Source Instance${normal}:          $source_vm_id"
    echo

    # Perform the test
    gcloud beta network-management connectivity-tests create $env_name-node-to-peering-range \
        --destination-ip-address="$ip" \
        --destination-port=3306 \
        --protocol=TCP \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-peering-range" "Node to Peering Range"

    delete_test "$env_name-node-to-peering-range"

} # test_node_to_peering_range

interpret_test() {
    # TODO: Maybe give an option to test all the pods/all the node

    sleep 5 # Give it time

    result=$(gcloud beta network-management connectivity-tests describe "$1" \
        --format='table[no-heading](reachabilityDetails.result)')

    if [ $result == "REACHABLE" ]; then
        echo
        echo "${bold}${green}No issues in $2 Connectivity${normal}"
        echo
    else
        echo "${bold}${red}Issues in $2 Connectivity${normal}"
        # TODO: Print the details of a test if it failed
        echo
    fi
} # interpret_test

delete_test() {
    if [ "$persist_tests" == "No" ]; then
        sleep 5 # Give it time
        gcloud network-management connectivity-tests delete "$1" \
            --async \
            -q
    fi
} # delete_test

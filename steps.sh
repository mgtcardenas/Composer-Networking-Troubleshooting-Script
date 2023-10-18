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

    echo
    echo "${bold}Enter an example Pod IP e.g. 10.11.129.7 (Empty response will have the script search Cloud Logging for it)${normal}. "
    echo "You can find the pod IP under 'Environment details > Resources > GKE cluster > Workloads > airflow-worker-<hash> > YAML tab > pod IP (at the bottom)'."
    echo -n "Pod IP: "
    IFS= read -r pod_ip
    pod_ip=${pod_ip:-""}

    if [ -z "$pod_ip" ]; then
        # Get the pod IP from Cloud Logging
        query='resource.labels.cluster_name="'$gke_cluster_name'" jsonPayload.message=~".*conn-id:.*composer.*airflow-worker" resource.labels.container_name="gke-metadata-server"'

        while [ true ]; do
            result=$(gcloud logging read "$query" \
                --limit=1 \
                --format="value(jsonPayload.message)")

            if [ -z "$result" ]; then
                echo "Attempting to find pod IP..."
            else
                echo "Pod IP found!"
                echo
                break
            fi
            sleep 5
        done
        tmp_result=($result)                                           # something like... [conn-id:692e22c0b2112e12 ip:10.55.0.4 pod:composer-2-4-4-airflow-2-5...
        pod_ip=$(echo "${tmp_result[1]}" | awk '{print substr($0,4)}') # consider doing '{print substr($0,39);exit}'
        pod_ip=$(echo "$pod_ip" | xargs)                               # remove possible trailing space just in case
    fi

    # TODO: Display the pods secondary range (from composer list operation)

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

    case $contacted_service in
    "RESTRICTED")
        ip="199.36.153.4"
        ;;
    "PRIVATE")
        ip="199.36.153.8"
        ;;
    "PUBLIC_OR_NOT_SURE")
        ip="172.217.4.187"
        ;;
    esac

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

    echo "${bold}Test Name${normal}:                                        $env_name-node-to-psc-3306"
    echo "${bold}Destination Forwarding Rule (aka. PSC Endpoint)${normal}:  $psc_id"
    echo "${bold}Destination Port${normal}:                                 3306"
    echo "${bold}Protocol${normal}:                                         TCP"
    echo "${bold}Source Instance${normal}:                                  $source_vm_id"
    echo

    gcloud beta network-management connectivity-tests create $env_name-node-to-psc-3306 \
        --destination-forwarding-rule="$psc_id" \
        --destination-port=3306 \
        --protocol=TCP \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-psc-3306" "Node to PSC Endpoint (Port 3306)"

    delete_test "$env_name-node-to-psc-3306"

    echo
    echo "${bold}Test Name${normal}:                                        $env_name-node-to-psc-3307"
    echo "${bold}Destination Forwarding Rule (aka. PSC Endpoint)${normal}:  $psc_id"
    echo "${bold}Destination Port${normal}:                                 3307"
    echo "${bold}Protocol${normal}:                                         TCP"
    echo "${bold}Source Instance${normal}:                                  $source_vm_id"
    echo

    gcloud beta network-management connectivity-tests create $env_name-node-to-psc-3307 \
        --destination-forwarding-rule="$psc_id" \
        --destination-port=3307 \
        --protocol=TCP \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-psc-3307" "Node to PSC Endpoint (Port 3307)"

    delete_test "$env_name-node-to-psc-3307"
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

    echo "${bold}Test Name${normal}:                $env_name-node-to-peering-range-3306"
    echo "${bold}Destination IP Address${normal}:   $ip"
    echo "${bold}Destination Port${normal}:         3306"
    echo "${bold}Protocol${normal}:                 TCP"
    echo "${bold}Source Instance${normal}:          $source_vm_id"
    echo

    # Perform the test
    gcloud beta network-management connectivity-tests create $env_name-node-to-peering-range-3306 \
        --destination-ip-address="$ip" \
        --destination-port=3306 \
        --protocol=TCP \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-peering-range-3306" "Node to Peering Range (Port 3306)"

    delete_test "$env_name-node-to-peering-range-3306"

    echo
    echo "${bold}Test Name${normal}:                $env_name-node-to-peering-range-3307"
    echo "${bold}Destination IP Address${normal}:   $ip"
    echo "${bold}Destination Port${normal}:         3307"
    echo "${bold}Protocol${normal}:                 TCP"
    echo "${bold}Source Instance${normal}:          $source_vm_id"
    echo

    # Perform the test
    gcloud beta network-management connectivity-tests create $env_name-node-to-peering-range-3307 \
        --destination-ip-address="$ip" \
        --destination-port=3307 \
        --protocol=TCP \
        --source-instance="$source_vm_id"

    interpret_test "$env_name-node-to-peering-range-3307" "Node to Peering Range (Port 3307)"

    delete_test "$env_name-node-to-peering-range-3307"
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
        gcloud beta network-management connectivity-tests describe "$1" \
            --format="(reachabilityDetails)"
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

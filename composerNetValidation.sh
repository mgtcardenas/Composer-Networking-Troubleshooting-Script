#/bin/bash

startTime=$(date +"%Y-%m-%dT%H:%M:%S") # timesamp in the format of GKE `createTime`

echo "Searching for GKE cluster to be created after $startTime..."

while [ true ]; do    
    gkeClusterName=$(gcloud container clusters list --format='(name)' --filter="createTime>'$startTime'")
    if [ -z "$gkeClusterName" ]; then
        echo "No cluster yet..."
    else
        echo "Cluster found... $gkeClusterName"
        break
    fi
    sleep 3
done

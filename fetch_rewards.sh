#!/bin/bash
# Fetch Rewards "Simple Coding Exercise"
# 3/24/2020 - Lance Sandino <lance.sandino@gmail.com>
#
# Assumptions:
#	* 'yq' installed
# 	* 'Google Cloud' is the Cloud Provider
#	* 'google-cloud-sdk' installed
#	* 'Google Cloud Billing' is Enabled
#	* 'Deployment Manager and Compute Engine APIs' are Enabled
#       * 'project_ID' is new for this test
#

# check if dependencies are installed
if [ ! $(which yq) ] || [ ! $(which gcloud) ]; then
	echo "ERROR: you're missing a pre-req!"
	echo "\tmake sure you have 'yq' and 'gcloud' installed"
fi

# Name of Project_ID
PROJECT_ID=$(gcloud config list --format 'value(core.project)')
if [ -z $PROJECT_ID ]; then
	echo "ERROR: you need to set a default PROJECT_ID"
fi

# Check default zone and region
G_REGION=$(gcloud config list --format 'value(compute.region)')
G_ZONE=$(gcloud config list --format 'value(compute.zone)')

# Name of VM Instance
DEPLOY_NAME="fetch-rewards-project"

# set some vars here that we parse from the fetch-rewards email yaml
G_SSH_USER=$(yq r fetch_config.yaml 'server.users.[0].login')
G_SSH_KEY=$(yq r fetch_config.yaml server.users.[0].ssh_key| sed 's/@localhost//')
G_EXISTING_KEYS=$(gcloud compute project-info describe --project $PROJECT_ID|yq r - commonInstanceMetadata.items.*.value)
MACHINE_TYPE=$(yq r fetch_config.yaml server.instance_type)
MACHINE_TYPE_URL="https://www.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/$G_ZONE/machineTypes/$MACHINE_TYPE"
DISK1_NAME=$(yq r fetch_config.yaml 'server.volumes.[0].device')
DISK1_SIZE=$(yq r fetch_config.yaml 'server.volumes.[0].size_gb')
DISK2_NAME=$(yq r fetch_config.yaml 'server.volumes.[1].device')
DISK2_SIZE=$(yq r fetch_config.yaml 'server.volumes.[1].size_gb')
NETWORK_URL="https://www.googleapis.com/compute/v1/projects/$PROJECT_ID/global/networks/default"

# lets update 'vm.yaml' with values from the fetch-rewards email yaml
yq w orig.vm.yaml 'resources.[*].name' fetch-rewards > vm.yaml
yq w -i vm.yaml 'resources.[*].properties.zone' $G_ZONE
yq w -i vm.yaml 'resources.[*].properties.machineType' $MACHINE_TYPE_URL
yq w -i vm.yaml 'resources.[*].properties.disks[0].deviceName' $DISK1_NAME
yq w -i vm.yaml 'resources.[*].properties.disks[0].initializeParams.diskSizeGb' $DISK1_SIZE
yq w -i vm.yaml 'resources.[*].properties.disks[0].initializeParams.diskName' $DISK1_NAME
yq w -i vm.yaml 'resources.[*].properties.disks[1].deviceName' $DISK2_NAME
yq w -i vm.yaml 'resources.[*].properties.disks[1].initializeParams.diskSizeGb' $DISK2_SIZE
yq w -i vm.yaml 'resources.[*].properties.disks[1].initializeParams.diskName' $DISK2_NAME
yq w -i vm.yaml 'resources.[*].properties.networkInterfaces.[0].network' $NETWORK_URL

##echo "adding repo key to project"
##echo "${G_EXISTING_KEYS}\n${G_SSH_USER}:${G_SSH_KEY}" > new_ssh_keys.txt
##gcloud compute project-info add-metadata --metadata-from-file ssh-keys=new_ssh_keys.txt

# create deployment using 'vm.yaml'
gcloud deployment-manager deployments create $DEPLOY_NAME --config vm.yaml

# Our External IP for connecting to VM
EXT_INSTANCE_IP=$(gcloud compute instances list|grep fetch-rewards | awk '{print $(NF-1)}')

# run disk hack (need to format and initialize disk since we just created it.... real use-case we probs wouldn't have to, or do this a better way)
echo "\n\nwaiting for VM to finish initializing..."
sleep 30
ssh ${G_SSH_USER}@${EXT_INSTANCE_IP} < disk_hack.sh

# ask nicely if user wants to connect to play around in VM
read -p "Would you like to connect to your newly created VM? [yes/no]" prompt
case $prompt in
        [Yy]* ) ssh ${G_SSH_USER}@${EXT_INSTANCE_IP};;
        * ) echo "To connect at a later time, use the following command\n'ssh ${G_SSH_USER}@${EXT_INSTANCE_IP}'";;
esac

# let's clean up
echo "let's delete our deployment"
gcloud deployment-manager deployments delete $DEPLOY_NAME

# delete ssh file
rm -rf new_ssh_keys.txt

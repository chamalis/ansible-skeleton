#!/bin/bash

######### CHANGE THIS !!!! ########
export DEBIAN10_IP=192.168.122.188
##################################

if ! ansible-playbook ./ansible/deploy.yml -i ./ansible/env/prod/inventory.yml;
then
  >&2 echo "ERROR deploying docker images to the production servers" && exit 1
fi
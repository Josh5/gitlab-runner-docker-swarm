#!/usr/bin/env bash
###
# File: 20-configure-docker-networks.sh
# Project: init.d
# File Created: Monday, 21st October 2024 10:43:23 am
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 6:17:36 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

echo "--- Ensure DIND network exists ---"
existing_network=$(docker network ls --filter name="${dind_net_name:?}" --format "{{.Name}}" || echo "")
if [ "X${existing_network}" = "X" ]; then
    echo "  - Creating private network for DIND container..."
    docker network create -d bridge "${dind_net_name}"
else
    echo "  - Private network for DIND already exists!"
fi
echo

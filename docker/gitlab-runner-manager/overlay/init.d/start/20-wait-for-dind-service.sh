#!/usr/bin/env bash
###
# File: 20-wait-for-dind-service.sh
# Project: start
# File Created: Friday, 21st March 2025 4:23:45 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 6:22:19 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

echo "--- Waiting for DIND container ---"
for i in 1 2 3 4 5 6; do
    echo docker inspect --format='{{.State.Status}}' "${gitlab_runner_dind_name:?}"
    HEALTH_STATUS=$(docker inspect --format='{{.State.Status}}' "${gitlab_runner_dind_name:?}" 2>/dev/null) || echo "unknown"
    if [ "${HEALTH_STATUS:-}" = "running" ]; then
        echo "  - DIND container is running"
        break
    fi
    echo "  - DIND container is not healthy yet (Current status: '${HEALTH_STATUS:-}'). Waiting 5 seconds"
    sleep 5
done
if [ "${HEALTH_STATUS}" != "running" ]; then
    echo "  - DIND container did not start. Exit!."
    exit 1
fi
sleep 5 # Wait a few more seconds for the DIND container to finish starting
echo

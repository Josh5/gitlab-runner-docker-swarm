#!/usr/bin/env bash
###
# File: 20-runner-stop.sh
# Project: init.d
# File Created: Friday, 21st March 2025 4:19:37 pm
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 6:17:36 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

echo "--- Stopping DIND container ${dind_name:?} ---"
docker stop --time 120 ${dind_name:?} &>/dev/null || true
docker rm ${dind_name:?} &>/dev/null || true
echo

echo "--- Terminating container logs tail job ---"
log_pid=$(cat "/tmp/docker_log_tail.pid" || echo "")
# Terminate the background log tail job by PID, if it has been set
if [ "X${log_pid:-}" != "X" ]; then
    kill "${log_pid:?}" 2>/dev/null || true
fi

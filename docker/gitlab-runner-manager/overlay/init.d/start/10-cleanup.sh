#!/usr/bin/env bash
###
# File: 10-cleanup.sh
# Project: start
# File Created: Friday, 21st March 2025 4:22:20 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 6:17:37 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

if [ "${KEEP_ALIVE}" = "false" ]; then
    echo "--- Cleaning up old containers ---"
    docker stop ${gitlab_runner_name:?} &>/dev/null || true
    docker rm ${gitlab_runner_name:?} &>/dev/null || true
    sleep 1
    echo
fi

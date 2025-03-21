#!/usr/bin/env bash
###
# File: entrypoint.sh
# Project: overlay
# File Created: Friday, 18th October 2024 5:05:51 pm
# Author: Josh5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 7:04:13 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###
set -eu

################################################
# --- Export config
#
export docker_version=$(docker --version | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")
if [ "X${DOCKER_VERSION:-}" = "X" ]; then
    export docker_version=${DOCKER_VERSION:?}
fi
# TODO: Make this configurable
export dind_net_name="gitlab-runner-net"
export dind_name="gitlab-runner-dind"
export dind_cache_path="${DATA_PATH:?}/docker-cache"
export dind_run_path="${DATA_PATH:?}/docker-sock"

################################################
# --- Create TERM monitor
#
_term() {
    echo
    echo -e "\e[35m[ Stopping manager service ]\e[0m"
    if [ "${KEEP_ALIVE}" = "false" ]; then
        echo "  - The 'KEEP_ALIVE' env variable is set to ${KEEP_ALIVE:?}. Running all shutdown scripts"
        # Run all stop scripts
        for stop_script in /init.d/stop/*.sh; do
            if [ -f ${stop_script:?} ]; then
                echo
                echo -e "\e[33m[ ${stop_script:?}: executing... ]\e[0m"
                sed -i 's/\r$//' "${stop_script:?}"
                source "${stop_script:?}"
            fi
        done
        echo
    else
        echo "  - The 'KEEP_ALIVE' env variable is set to ${KEEP_ALIVE:?}. Stopping manager only."
    fi
    exit 0
}
trap _term SIGTERM SIGINT

################################################
# --- Run through startup init scripts
#
echo
echo -e "\e[35m[ Running startup scripts ]\e[0m"
for start_script in /init.d/start/*.sh; do
    if [ -f ${start_script:?} ]; then
        echo
        echo -e "\e[34m[ ${start_script:?}: executing... ]\e[0m"
        sed -i 's/\r$//' "${start_script:?}"
        source "${start_script:?}"
    fi
done

################################################
# --- Create compose stack monitor
#
_stack_monitor() {
    echo
    echo -e "\e[35m[ Waiting for child services to exit ]\e[0m"
    while true; do
        # Check if any service has exited
        echo "  - Check if DIND container has exited ---"
        if ! docker ps --filter "name=${dind_name:?}" | grep -q "${dind_name:?}"; then
            echo "      - DIND container has stopped. Exiting with status code 123 ---"
            exit 123
        fi
        # Sleep for a few seconds unless interrupted
        sleep 10 &
        wait $!
        echo
    done
}
sleep 10 &
wait $!
_stack_monitor

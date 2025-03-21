#!/usr/bin/env bash
###
# File: 70-start-dind.sh
# Project: start
# File Created: Friday, 21st March 2025 5:03:57 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 6:24:32 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

echo "--- Setting up run aliases ---"
mkdir -p \
    "${dind_cache_path:?}" \
    "${dind_run_path:?}"
DIND_RUN_CMD="docker run --privileged -d --rm --name ${dind_name:?} \
          --env DOCKER_HOST=tcp://${dind_name:?}:2375 \
          --env DOCKER_DRIVER=overlay2 \
          --env DOCKER_TLS_CERTDIR= \
          --volume ${dind_cache_path:?}:/var/lib/docker \
          --volume ${dind_run_path:?}:/var/run \
          --network ${dind_net_name:?} \
          --network-alias ${dind_name:?} \
          docker:${docker_version:?}-dind"
echo

echo "--- Writing config to env file ---"
echo "" >"${dind_cache_path:?}/new-dind-run-config.env"
echo "docker_version:?=${docker_version:?:?}" >>"${dind_cache_path:?}/new-dind-run-config.env"
echo "DIND_RUN_CMD=${DIND_RUN_CMD:?}" >>"${dind_cache_path:?}/new-dind-run-config.env"
cat "${dind_cache_path:?}/new-dind-run-config.env"
echo

echo "--- Checking if config has changed since last run ---"
if ! cmp -s "${dind_cache_path:?}/new-dind-run-config.env" "${dind_cache_path:?}/current-dind-run-config.env"; then
    echo "  - Env has changed. Stopping up old dind container due to possible config update"
    docker stop "${dind_name:?}" &>/dev/null || true
    docker rm "${dind_name:?}" &>/dev/null || true
    mv -fv "${dind_cache_path:?}/new-dind-run-config.env" "${dind_cache_path:?}/current-dind-run-config.env"
else
    echo "  - Env has not changed."
fi
echo

if ! docker ps --filter "name=${dind_name:?}" | grep -q "${dind_name:?}"; then
    echo "--- Fetching latest docker in docker image 'docker:${docker_version:?}-dind' ---"
    docker pull docker:${docker_version:?}-dind
    echo

    echo "--- Creating DIND container ---"
    rm -rf "${dind_run_path:?}"/*
    ${DIND_RUN_CMD:?}
else
    echo "--- DIND container already running ---"
fi
echo

echo "--- Tailing DIND container logs ---"
docker logs -f "${dind_name:?}" &
log_pid=$!
echo "${log_pid:?}" >/tmp/docker_log_tail.pid

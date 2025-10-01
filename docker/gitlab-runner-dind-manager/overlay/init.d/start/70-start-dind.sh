#!/usr/bin/env bash
###
# File: 70-start-dind.sh
# Project: start
# File Created: Friday, 21st March 2025 5:03:57 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Thursday, 2nd October 2025 12:18:44 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

echo "--- Setting up run aliases ---"
mkdir -p \
    "${dind_cache_path:?}" \
    "${dind_run_path:?}"

echo "--- Calculating DIND resource limits ---"
# CPU limits: 95% of total CPUs
echo "  - Calculating CPU quota..."
DIND_CPU_PERCENT=95
TOTAL_CPUS=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
CPU_PERIOD=100000
CPU_QUOTA=$(( CPU_PERIOD * TOTAL_CPUS * DIND_CPU_PERCENT / 100 ))
DIND_CPU_SHARES=512
echo "    - CPU Percent: ${DIND_CPU_PERCENT}%"
echo "    - Total CPUs: ${TOTAL_CPUS}"
echo "    - CPU Quota: ${CPU_QUOTA}/${CPU_PERIOD}"
echo "    - CPU Shares: ${DIND_CPU_SHARES}"

# Memory limit: total host memory minus 300 MiB
echo "  - Calculating memory limit..."
mem_total_bytes=$(docker info --format '{{.MemTotal}}' 2>/dev/null | tr -d '\r\n')
if [ -z "${mem_total_bytes}" ] || ! [ "${mem_total_bytes}" -gt 0 ] 2>/dev/null; then
    if [ -r /proc/meminfo ]; then
        mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
        if [ -n "${mem_kb}" ] && [ "${mem_kb}" -gt 0 ] 2>/dev/null; then
            mem_total_bytes=$(( mem_kb * 1024 ))
        fi
    fi
fi
BUFFER_BYTES=$((300 * 1024 * 1024)) # 300 MiB
if [ -z "${mem_total_bytes}" ] || ! [ "${mem_total_bytes}" -gt "${BUFFER_BYTES}" ] 2>/dev/null; then
    # Fallback if detection failed or total <= buffer: default to 1GiB
    DIND_MEMLIMIT=$((1024 * 1024 * 1024))
else
    DIND_MEMLIMIT=$(( mem_total_bytes - BUFFER_BYTES ))
fi
echo "    - Host Mem Total (bytes): ${mem_total_bytes:-unknown}"
echo "    - DIND Mem Limit (bytes): ${DIND_MEMLIMIT}"
echo "    - DIND Mem Limit (MiB): $(( DIND_MEMLIMIT / 1024 / 1024 ))"

DIND_RUN_CMD="docker run --privileged -d --rm --name ${dind_name:?} \
          --memory ${DIND_MEMLIMIT:?} \
          --cpu-shares ${DIND_CPU_SHARES:?} \
          --cpu-period ${CPU_PERIOD:?} \
          --cpu-quota ${CPU_QUOTA:?} \
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
echo "DIND_CPU_PERCENT=${DIND_CPU_PERCENT:?}" >>"${dind_cache_path:?}/new-dind-run-config.env"
echo "TOTAL_CPUS=${TOTAL_CPUS:?}" >>"${dind_cache_path:?}/new-dind-run-config.env"
echo "CPU_PERIOD=${CPU_PERIOD:?}" >>"${dind_cache_path:?}/new-dind-run-config.env"
echo "CPU_QUOTA=${CPU_QUOTA:?}" >>"${dind_cache_path:?}/new-dind-run-config.env"
echo "DIND_CPU_SHARES=${DIND_CPU_SHARES:?}" >>"${dind_cache_path:?}/new-dind-run-config.env"
echo "DIND_MEMLIMIT=${DIND_MEMLIMIT:?}" >>"${dind_cache_path:?}/new-dind-run-config.env"
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

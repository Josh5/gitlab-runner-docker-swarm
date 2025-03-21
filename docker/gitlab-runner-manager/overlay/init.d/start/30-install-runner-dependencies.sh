#!/usr/bin/env bash
###
# File: 30-install-runner-dependencies.sh
# Project: start
# File Created: Friday, 21st March 2025 4:26:20 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 7:04:17 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

echo "--- Installing docker v${docker_version} into gitlab container ---"
mkdir -p \
    "${DATA_PATH:?}/${RUNNER_NAME:?}/src" \
    "${DATA_PATH:?}/${RUNNER_NAME:?}/bin"
if [ ! -f "${DATA_PATH:?}/${RUNNER_NAME:?}/src/docker-${docker_version:?}.tgz" ]; then
    wget -q "https://download.docker.com/linux/static/stable/x86_64/docker-${docker_version:?}.tgz" \
        -O "${DATA_PATH:?}/${RUNNER_NAME}/src/docker-${docker_version:?}.tgz"
fi
tar --extract \
    --file "${DATA_PATH:?}/${RUNNER_NAME:?}/src/docker-${docker_version:?}.tgz" \
    --strip-components 1 \
    --directory "${DATA_PATH:?}/${RUNNER_NAME:?}/bin/" \
    --no-same-owner
"${DATA_PATH:?}/${RUNNER_NAME:?}/bin/docker" --version
echo

echo "--- Installing GitLab Runner cleanup script ---"
cp -afv "/defaults/gitlab-runner-cleanup.sh" "${DATA_PATH:?}/${RUNNER_NAME:?}/bin/gitlab-runner-cleanup.sh"
chmod 755 "${DATA_PATH:?}/${RUNNER_NAME:?}/bin/gitlab-runner-cleanup.sh"
cat "${DATA_PATH:?}/${RUNNER_NAME}/bin/gitlab-runner-cleanup.sh"
echo

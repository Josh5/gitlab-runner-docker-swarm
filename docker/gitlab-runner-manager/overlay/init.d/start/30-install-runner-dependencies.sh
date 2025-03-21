#!/usr/bin/env bash
###
# File: 30-install-runner-dependencies.sh
# Project: start
# File Created: Friday, 21st March 2025 4:26:20 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 6:36:46 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

echo "--- Installing docker v${docker_version} into gitlab container ---"
mkdir -p \
    "${CONFIG_PATH:?}/${RUNNER_NAME:?}/src" \
    "${CONFIG_PATH:?}/${RUNNER_NAME:?}/bin"
if [ ! -f "${CONFIG_PATH:?}/${RUNNER_NAME:?}/src/docker-${docker_version:?}.tgz" ]; then
    wget -q "https://download.docker.com/linux/static/stable/x86_64/docker-${docker_version:?}.tgz" \
        -O "${CONFIG_PATH:?}/${RUNNER_NAME}/src/docker-${docker_version:?}.tgz"
fi
tar --extract \
    --file "${CONFIG_PATH:?}/${RUNNER_NAME:?}/src/docker-${docker_version:?}.tgz" \
    --strip-components 1 \
    --directory "${CONFIG_PATH:?}/${RUNNER_NAME:?}/bin/" \
    --no-same-owner
"${CONFIG_PATH:?}/${RUNNER_NAME:?}/bin/docker" --version
echo

echo "--- Installing GitLab Runner cleanup script ---"
cp -afv "/defaults/gitlab-runner-cleanup.sh" "${CONFIG_PATH:?}/${RUNNER_NAME:?}/bin/gitlab-runner-cleanup.sh"
chmod 755 "${CONFIG_PATH:?}/${RUNNER_NAME:?}/bin/gitlab-runner-cleanup.sh"
cat "${CONFIG_PATH:?}/${RUNNER_NAME}/bin/gitlab-runner-cleanup.sh"
echo

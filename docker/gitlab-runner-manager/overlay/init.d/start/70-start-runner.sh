#!/usr/bin/env bash
###
# File: 70-start-runner.sh
# Project: start
# File Created: Friday, 21st March 2025 4:36:06 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Friday, 21st March 2025 7:04:24 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###

echo "--- Setting up run aliases ---"
D_COMMON_RUN_ARGS="--rm --privileged \
      --env DOCKER_HOST=tcp://${gitlab_runner_dind_name}:2375 \
      --volume=${DATA_PATH:?}/${RUNNER_NAME:?}/config:/etc/gitlab-runner \
      --volume=${DATA_PATH:?}/${RUNNER_NAME:?}/bin:/usr/local/bin \
      --volume=/var/run/docker.sock:/var/run/docker.sock \
      --network=${gitlab_runner_net_name} \
      gitlab/gitlab-runner:${GITLAB_RUNNER_VERSION:?}"
GL_REGISTER_CMD="docker run --rm --name ${gitlab_runner_name:?}-register \
        ${D_COMMON_RUN_ARGS} \
        register \
        --non-interactive \
        --url https://gitlab.com/ \
        --executor docker \
        --docker-image ${DOCKER_IMAGE} \
        --docker-privileged \
        --docker-dns ${DOCKER_DNS:-8.8.8.8} \
        --docker-services-limit -1 \
        --docker-pull-policy if-not-present \
        --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
        --token ${gitlab_registration_token_secret} \
        --description ${RUNNER_NAME:?}"
GL_LIST_CMD="docker run --rm --name ${gitlab_runner_name:?}-list \
        ${D_COMMON_RUN_ARGS} \
        list"
GL_RUN_CMD="docker run -d --rm --name ${gitlab_runner_name:?} \
        ${D_COMMON_RUN_ARGS} \
        run --user=gitlab-runner --working-directory=/home/gitlab-runner"
GL_CLEAN_CMD="docker run --rm --entrypoint="" --name ${gitlab_runner_name:?}-cleaner \
        --volume=${DATA_PATH:?}/docker-cache:/var/lib/docker \
        ${D_COMMON_RUN_ARGS} \
        /usr/local/bin/gitlab-runner-cleanup.sh"
echo

echo "--- Writing config to env file ---"
mkdir -p "${DATA_PATH:?}/${RUNNER_NAME:?}/config"
echo "" >"${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
echo "GITLAB_RUNNER_VERSION=${GITLAB_RUNNER_VERSION:?}" >>"${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
echo "docker_version=${docker_version:?}" >>"${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
echo "CONCURRENT=${CONCURRENT:?}" >>"${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
echo "D_COMMON_RUN_ARGS=${D_COMMON_RUN_ARGS:?}" >>"${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
echo "GL_REGISTER_CMD=${GL_REGISTER_CMD:?}" >>"${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
echo "GL_LIST_CMD=${GL_LIST_CMD:?}" >>"${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
echo "GL_RUN_CMD=${GL_RUN_CMD:?}" >>"${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
echo "GL_CLEAN_CMD=${GL_CLEAN_CMD:?}" >>"${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
cat "${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env"
echo

echo "--- Writing helper scripts to /usr/local/bin ---"
cat <<EOF >/usr/local/bin/gitlab-runner-cleanup.sh
#!/usr/bin/env bash
${GL_CLEAN_CMD:?}
EOF
chmod +x /usr/local/bin/gitlab-runner-cleanup.sh
echo

echo "--- Checking if config has changed since last run ---"
if ! cmp -s "${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env" "${DATA_PATH:?}/${RUNNER_NAME:?}/config/current-runner-config.env"; then
    echo "  - Env has changed. Stopping up old containers due to possible config update"
    while sleep 1; do
        if ! docker ps --filter "name=${gitlab_runner_name:?}" | grep -q "${gitlab_runner_name:?}"; then
            echo "    - Container ${gitlab_runner_name:?} is not running"
            break
        fi
        echo "    - Container ${gitlab_runner_name:?} is currently running. Sending signal to stop..."
        docker stop "${gitlab_runner_name:?}" &>/dev/null || true
        docker rm "${gitlab_runner_name:?}" &>/dev/null || true
    done
    mv -fv "${DATA_PATH:?}/${RUNNER_NAME:?}/config/new-runner-config.env" "${DATA_PATH:?}/${RUNNER_NAME:?}/config/current-runner-config.env"
else
    echo "  - Env has not changed."
fi
echo

if ! docker ps --filter "name=${gitlab_runner_name:?}" | grep -q "${gitlab_runner_name:?}"; then
    echo "--- Creating base config ---"
    mkdir -p "${DATA_PATH:?}/${RUNNER_NAME:?}/config"
    cat <<EOF >"${DATA_PATH:?}/${RUNNER_NAME:?}/config/config.toml"
concurrent = ${CONCURRENT}
check_interval = 0
shutdown_timeout = 0
[session_server]
    session_timeout = 1800
EOF
    cat "${DATA_PATH:?}/${RUNNER_NAME:?}/config/config.toml"
    chmod a+rw "${DATA_PATH:?}/${RUNNER_NAME:?}/config"
    echo

    echo "--- Fetching latest 'gitlab/gitlab-runner:${GITLAB_RUNNER_VERSION:?}' image ---"
    docker pull "gitlab/gitlab-runner:${GITLAB_RUNNER_VERSION:?}"
    echo

    echo "--- Registering runner ---"
    ${GL_REGISTER_CMD}
    echo

    echo "--- List runners ---"
    ${GL_LIST_CMD}
    echo

    echo "--- Running runner ---"
    ${GL_RUN_CMD}
    sleep 5
    echo
else
    echo "--- GitLab Runner container already running ---"

    echo "--- List runners ---"
    ${GL_LIST_CMD}
    echo
fi
echo

echo "--- Tailing GitLab Runner container logs ---"
docker logs -f "${gitlab_runner_name:?}" &
log_pid=$!
echo "${log_pid:?}" >/tmp/docker_log_tail.pid

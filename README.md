# GitLab Runners for Docker Swarm

Run GitLab CI jobs on Docker Swarm with Docker-in-Docker, job services, persistent image caching, and image cleanup. Manager services create the runner and its Docker daemon on each selected node.

For Portainer deployment and configuration, see the [published setup guide](https://github.com/Josh5/gitlab-runner-docker-swarm/blob/release/latest/README.md).

## Development setup

From the root of this project, run these commands:

1. Create the `.env` files

   ```
   echo "PROJECT_ROOT='${PWD:?}'" > .env
   ```

2. Save your GitLab runner authentication token in `gitlab-registration-token.secret` at the project root. The file is ignored by Git. The published setup guide explains how to obtain the token.

3. Run the dev compose stack

   ```
   sudo docker compose up --build -d
   ```

4. Monitor the logs

   ```
   sudo docker compose logs -f
   ```

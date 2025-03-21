# GitLab Runners for Docker Swarm

## Development setup

From the root of this project, run these commands:

1. Create the `.env` files

   ```
   echo "PROJECT_ROOT='${PWD:?}'" > .env
   ```

2. Create a file with the runner secret

   ```
   echo "GITLAB_RUNNER_REGISTRATION_TOKEN" > gitlab-registration-token.secret
   ```

3. Run the dev compose stack

   ```
   sudo docker compose up --build -d
   ```

4. Monitor the logs

   ```
   sudo docker compose logs -f
   ```

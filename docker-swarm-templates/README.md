# GitLab Runner Docker Swarm Setup

Deploy GitLab Runner through Portainer using the stack in [docker-compose.yml](./docker-compose.yml). The stack runs a runner manager and a Docker-in-Docker manager on each node matching the placement constraint. Jobs use the nested Docker daemon, with a persistent image cache on the node.

## Prepare the runner nodes

Use a Docker Swarm environment managed by Portainer. Each selected node needs Docker, access to GitLab.com and the image registries used by your jobs, and an existing writable directory for `DATA_PATH`, such as `/opt/gitlab-runner`. The template currently registers runners against `https://gitlab.com/`.

In Portainer, select each runner node and add the engine label `node-type` with the value `gitlab-runner` to match the example placement constraint. Alternatively, set `PLACEMENT_CONSTRAINT` to select the intended nodes by hostname or role. Both managers use the same constraint and run globally: one of each per matching node.

The managers access the host Docker socket and create privileged containers. Use nodes and runner scopes appropriate for the jobs you intend to execute. Keep `DATA_PATH` local to each node because it contains that node's Docker data.

## Obtain the GitLab runner token

Create a runner in GitLab.com and copy its **runner authentication token**, which starts with `glrt-`. The stack performs registration automatically; you do not need to run the registration command shown by GitLab yourself.

1. Choose the runner scope. For a group runner, open the group, select **Build > Runners**, and select **Create group runner**. This requires the group Owner role.
2. For a project runner instead, open **Settings > CI/CD**, expand **Runners**, and select **Create project runner**. This requires the project Maintainer role.
3. Set the job tags and access settings. Enable **Run untagged** if this runner should accept jobs without tags; otherwise ensure your jobs specify matching tags.
4. Create the runner, select Linux, and copy the token from the registration screen before leaving it. GitLab displays the authentication token only briefly.

See [GitLab's runner creation guide](https://docs.gitlab.com/ci/runners/runners_scope/). Use the authentication token for this stack, rather than a personal access token or a legacy runner registration token. The modern registration flow is documented in [Registering runners](https://docs.gitlab.com/runner/register/).

## Create the Portainer secret

In the target Swarm environment, open **Secrets > Add secret**. Set the name to `GITLAB_REGISTRATION_TOKEN_SECRET`, paste only the runner authentication token as its value, and create the secret before deploying the stack. See [Portainer's secret guide](https://docs.portainer.io/user/docker/secrets/add).

The name is retained for compatibility: despite containing `REGISTRATION_TOKEN`, this secret holds the runner authentication token. The template declares it as external and mounts it into the runner manager. Keep the token out of Git and the stack environment variable block.

## Add the stack in Portainer

1. Select your Swarm environment, open **Stacks**, and select **Add stack**.
2. Name the stack, for example `gitlab-runner`, and select **Repository** as the build method.
3. Enter these Git settings:
   - Repository URL: `<url>`
   - Repository reference: `refs/heads/<branch>`
   - Compose path: `docker-compose.yml`
4. In **Environment variables**, switch to **Advanced mode**, paste the block below, and adjust the placement, storage path, runner name, and concurrency for your nodes.
5. Enable GitOps updates with a polling interval such as `5m` if you want automatic updates. Choose manual updates if you need to schedule changes between jobs.
6. Deploy the stack.

```env
PLACEMENT_CONSTRAINT=engine.labels.node-type==gitlab-runner
DATA_PATH=/opt/gitlab-runner
GITLAB_RUNNER_VERSION=v19.4.1
RUNNER_NAME=swarm-gitlab-runner
RUNNER_CONCURRENCY=2
DOCKER_IMAGE=docker
DOCKER_PULL_POLICY=if-not-present
DOCKER_ALLOWED_PULL_POLICIES=always,if-not-present
KEEP_ALIVE=true
```

The Compose path above is relative to the published release branch's root. This guide and the template are published together; the build replaces `<url>` and `<branch>` with the release repository and branch values. For additional Git deployment options, see [Portainer's stack guide](https://docs.portainer.io/user/docker/stacks/add).

## Configuration options

| Variable                       | Default or requirement             | Purpose                                                                                                                                                                                                                   |
| ------------------------------ | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PLACEMENT_CONSTRAINT`         | Required                           | Selects nodes for both managers. The example uses the engine label `node-type=gitlab-runner`; `node.hostname==runner-1` is another option.                                                                                |
| `DATA_PATH`                    | Required                           | Absolute host path for persistent Docker cache, runner configuration, and helper binaries. Create it on every selected node before deploying.                                                                             |
| `GITLAB_RUNNER_VERSION`        | `v19.4.1`                          | Version tag of the upstream `gitlab/gitlab-runner` image launched by the manager. This does not select the manager image version.                                                                                         |
| `RUNNER_NAME`                  | Required                           | Runner description and directory name under `DATA_PATH`. Keep it stable to reuse the same configuration directory.                                                                                                        |
| `RUNNER_CONCURRENCY`           | `1` when omitted; example uses `2` | Maximum simultaneous jobs per node's runner process. With multiple selected nodes, total capacity increases accordingly. Use a positive integer.                                                                          |
| `DOCKER_IMAGE`                 | `docker`                           | Default job image when a pipeline does not specify one.                                                                                                                                                                   |
| `DOCKER_PULL_POLICY`           | `if-not-present`                   | Default image pull policy. Supported values are `always`, `if-not-present`, and `never`.                                                                                                                                  |
| `DOCKER_ALLOWED_PULL_POLICIES` | `always,if-not-present`            | Comma-separated policies jobs may request, without spaces. Must include `DOCKER_PULL_POLICY`.                                                                                                                             |
| `KEEP_ALIVE`                   | `true`                             | Skips forced cleanup of existing runner/DinD containers at manager startup. Configuration changes can still cause recreation, and normal manager shutdown stops its managed container. `false` forces cleanup at startup. |

The GitLab runner's scope, job tags, protected-job access, and acceptance of untagged jobs are configured in GitLab when creating or editing the runner.

## Image pull policies

The defaults reuse cached images for jobs that specify no policy, while allowing jobs to explicitly request fresh images with `pull_policy: always`:

```yaml
build:
  image:
    name: docker:cli
    pull_policy: always
  script:
    - docker version
```

Set `DOCKER_PULL_POLICY=always` if all jobs should check the registry by default. `if-not-present` uses a local image when available; `never` requires the image to already exist locally and must also be added to the allowlist if you enable it. See [GitLab's Docker executor pull-policy documentation](https://docs.gitlab.com/runner/executors/docker/#configure-how-runners-pull-images).

If a deployed runner rejects `pull_policy: always`, update its stack environment to include `always` in `DOCKER_ALLOWED_PULL_POLICIES` and redeploy with the updated manager image. Policy handling is baked into `ghcr.io/josh5/gitlab-runner-manager`; changing environment variables on an older image is insufficient.

For an immediate change before updating the manager, edit the existing `[runners.docker]` section in `${DATA_PATH}/${RUNNER_NAME}/config/config.toml` on each runner host:

```toml
pull_policy = "if-not-present"
allowed_pull_policies = ["always", "if-not-present"]
```

Keep the other settings and runner token intact. Runner reloads the file automatically, but the manager overwrites this manual change when regenerating the runner configuration. Use the stack settings for persistence. See [GitLab's configuration reload behavior](https://docs.gitlab.com/runner/configuration/advanced-configuration/).

## Verify and update the deployment

Check the `agent-manager` and `dind-manager` service logs in Portainer, confirm the runner is online in GitLab, then run a small pipeline with matching tags or an untagged job if you enabled that setting. For multiple selected nodes, verify that their runner managers connect successfully.

The project's Publish workflow builds manager images on `master` and publishes the Swarm templates and this guide to `release/latest`. When updating manager behavior, wait for the new image and template publication to finish, then use Portainer to redeploy the published stack with the new image.

Before updating, pause the runner in GitLab and wait for active jobs to finish. Changes to registration settings, including concurrency and pull policies, can cause the manager to recreate the runner and regenerate `config.toml`. Resume the runner after verifying the updated deployment.

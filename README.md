# [awbn/docker-gyb](https://github.com/awbn/docker-gyb)
A containerized version of [Got Your Back](https://github.com/jay0lee/got-your-back) to make it easy to back up your Gmail account. Can run standalone or as  full/incremental cron jobs (default).

[![Build and tests](https://img.shields.io/github/actions/workflow/status/awbn/docker-gyb/docker.yml?branch=main&logo=github&style=for-the-badge)](https://github.com/awbn/docker-gyb/actions/workflows/docker.yml) [![GYB Release](https://img.shields.io/github/actions/workflow/status/awbn/docker-gyb/gyb_release.yml?branch=main&label=Release&logo=docker&style=for-the-badge)](https://github.com/awbn/docker-gyb/actions/workflows/gyb_release.yml) [![awbn/gyb](https://img.shields.io/docker/pulls/awbn/gyb?style=for-the-badge&logo=docker)](https://hub.docker.com/r/awbn/gyb)

## Supported platforms
This is a multi-platform image which supports `linux/amd64` and `linux/arm64`. `linux/arm/v7` support is deprecated due to the upstream LSIO images deprecating armhf support.

## Tags
Tags correspond with [Got Your Back releases](https://github.com/jay0lee/got-your-back/releases). `:latest` refers to the latest published release and all releases since 1.40 are available as individual tags (e.g. `awbn/gyb:1.40` contains GYB v1.40).

Starting with 1.97 there's also a [rootless variant](#rootless-variant). Its tags add `-rootless` to the version (e.g. `awbn/gyb:1.97-rootless`), and `awbn/gyb:rootless` points to the latest release.

The latest release is rebuilt every week to pick up fixes to the base images, and its tags move to the new build. If you want to stay on one specific build, pin its digest. Every published image includes an SBOM and build provenance.

### Changes in 1.97
If you're upgrading from an earlier version, these are the changes to be aware of:
- **Health check**: the container now shows as unhealthy if its last scheduled job failed. See [Getting notified of failures](#getting-notified-of-failures).
- **`LOG_FILE`**: job output now goes to the file *and* the container's log (before, it only went to the file). The file is rotated before each job instead of only when the container starts, and a `logrotate.conf` next to it is no longer used.
- **One-off commands** (e.g. `docker run ... awbn/gyb /app/gyb --action restore`) no longer start the scheduled jobs, so you don't need `NOCRON` for them anymore. Setting it still works.
- **Failure emails** are sent with msmtp instead of ssmtp. The settings are the same, and the email now includes the last 200 lines of the job's output. Unlike ssmtp, msmtp checks the SMTP server's certificate, so if your server uses a self-signed certificate, set `SMTP_TLS_VERIFY=NO`.

## Usage
[GYB](https://github.com/jay0lee/got-your-back) requires some bootstrapping to create a new project before you can run. For complete bootstrapping steps, see the [GYB Wiki](https://github.com/jay0lee/got-your-back/wiki#running-gyb-for-the-first-time).

### First Run
```bash
docker run -it -e EMAIL=example@gmail.com -v ${PWD}/config:/config awbn/gyb /app/gyb --action create-project
```
...and follow the prompts. See [Bootstrapping Notes](#bootstrapping-notes) below for an abbreviated set of steps.

Once you've created the project and cached the credentials, you can run the container to start the background cron jobs. Make sure that you mount the same volume so that the credentials are re-used.

### First backup
The first full backup will (likely) take a long time. It's recommend to do this as a one-off run: 
```bash
docker run -it -e EMAIL=example@gmail.com -v ${PWD}/config:/config awbn/gyb /app/gyb --action backup
```

### Backups
By default you should start the container in detached mode and let it run incremental and full backups. See the docker-compose or CLI examples below.

#### Docker compose
```yaml
services:
  got-your-back:
    image: awbn/gyb
    container_name: got-your-back
    environment:
      - PUID=1000
      - PGID=1000
      - EMAIL=example@gmail.com
      - TZ=America/Los_Angeles
    volumes:
      - <path to data>:/config
    restart: unless-stopped
```

#### CLI
```bash
docker run -d \
  --name=got-your-back \
  -e PUID=1000 \
  -e PGID=1000 \
  -e EMAIL=example@gmail.com \
  -e TZ=America/Los_Angeles \
  -v <path to data>:/config \
  --restart unless-stopped \
  awbn/gyb
```

### Restoring from backup
See [GYB's wiki](https://github.com/jay0lee/got-your-back/wiki#performing-a-restore) for information on how to restore from a backup. Running the command in a container might look like:
```bash
docker run -it -e EMAIL=example@gmail.com -v ${PWD}/config:/config awbn/gyb /app/gyb --action restore
```

Note that you must have given the OAuth token 'write' permissions to your gmail account during bootstrapping for restore to work. If you didn't, you can delete the `<email>.cfg` file from the `/config` volume to force GYB to prompt for a new token.

## Advanced Usage
This container is based on [LinuxServer.io](https://linuxserver.io)'s Alpine base image. This means you can take advantage of all the LSIO goodness, including regular base image updates, user/group identification, loading environment variables from files (docker secrets), etc. See the [LSIO docs](https://docs.linuxserver.io) for more info.

### Getting notified of failures
The container's health check tells you whether your backups are working. After each scheduled job, its exit code is saved to `$CONFIG_DIR/.last-run`. If the last job failed, the container shows as **unhealthy**, and it goes back to healthy once a job succeeds. Until the first job has run, it shows as healthy. Commands you run by hand (e.g. `docker run ... /app/gyb`) don't affect it. Only one job can run at a time, so if a job hangs, the next one fails and you'll see it. Failed jobs also log a line starting with `ERROR:`.

The container can also send you an email when a job fails, with the last 200 lines of its output. To do so, you'll need to pass in the `MAIL_TO`, `MAIL_FROM`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER` and `SMTP_PASS` env variables, and optionally `SMTP_TLS` and `SMTP_TLS_VERIFY`. By default the email is sent over STARTTLS and the server's certificate is checked; if your server uses a self-signed certificate, set `SMTP_TLS_VERIFY=NO`. `SMTP_TLS=NO` turns TLS off, which means your password is sent unencrypted. If an email can't be sent, an error is logged.

### Logs
Job output goes to the container's log. If you set `LOG_FILE`, it's also written to that file, with a timestamp on each line. Once the file is over 512 KiB it's rotated before the next job, and the last five copies are kept, compressed. GYB updates its progress counters in place, so only the final count is logged.

### Customizing the jobs
By default the container has two jobs which are run on a regular schedule. The 'Full' job runs at 1am every Sunday (timezone depends on the container's TZ) and does a full backup. The incremental job runs at 1am Monday-Saturday and does a partial backup using GYB's [`--search` parameter](https://github.com/jay0lee/got-your-back/wiki#improving-backup-speed-incremental-daily-backups). You can customize the timing of these jobs and the GYB command which is run using environment variables. You can also define your own custom job as well.

To run the full job at a different schedule, set the `JOB_FULL_CRON` env variable to [valid cron syntax](https://crontab.guru). To run a different command for that job (e.g., to include only a particular label), set the `JOB_FULL_CMD` env variable to `/app/gyb <valid gyb command>`. See the [GYB Wiki](https://github.com/jay0lee/got-your-back/wiki) for more info on valid GYB commands.

In addition to the `JOB_FULL_` job, there are also the `JOB_INC_` and `JOB_EXTRA_` jobs. By default, the extra job is not used, but could be used to, e.g., back up a particular label more often. See the [Parameters](#parameters) section for more details.

Each job should be a single command. If you chain commands (e.g. `a && b`), only the first one is logged, counted by the health check and included in failure emails. To include all of them, wrap them in `sh -c '...'`.

### Using a Google Workspace Service Account
By default, the container is configured to call GYB using the the standard 3-legged OAuth authentication to set up the credentials for the account. GYB does support the use of Google Workspace service account credentials, which allows Google Workspace admins to use GYB on their users' accounts without requiring the users' passwords. It is recommended you follow the guide in the [GYB wiki](https://github.com/GAM-team/got-your-back/wiki#google-workspace-admins) for setting up the service account credentials, then include the oauth2service.json credentials file in the volume you mount to `/config` to make it accessible to GYB. Setting the env variable `USE_SERVICE_ACCOUNT=1` will append the `--service-account` flag to all GYB calls, enabling it for both the cron jobs and `docker run` calls. Using service account credentials enables using the Google Workspace-only GYB commands with the container.

## File permissions
By default the container creates all new files in `/config` with a umask of `077` (`rw` for the owner, no permissions for group/others). This is because sensitive files containing auth tokens, etc will get created. However, this can cause issues if you swap users or if you access the files outside of the container. If you want the files created to be more widely accessible, you can pass a different umask (e.g., `022`: `rw` for owner `r` for everyone else, or `100`: `rw` for everyone) via the `UMASK` environment variable. Make sure you understand how [umask works](https://en.wikipedia.org/wiki/Umask) before relying on this for security.

## Parameters

| Parameter | Default | Function |
| :----: | --- | --- |
| `-e EMAIL=example@gmail.com` | - | (Required) Email address to use with GYB |
| `-e TZ=America/Los_Angeles` | UTC | Timezone (affects cron schedule) |
| `-e NOCRON=1` | - | If set, don't run any scheduled jobs, but keep the container running. Not needed for one-off runs (e.g., GYB project creation or a restore): a command passed to the container already runs without the scheduled jobs |
| `-e NOSHORTURLS=1` | - | If set, block the GYB URL shortener |
| `-e CONFIG_DIR=/config` | `/config` | Directory for GYB config (ideally volume mounted). Is passed to GYB as `--config-folder` |
| `-e DEST_DIR=/config/data` | `/config/data` | Destination for backups (ideally volume mounted). Is passed to GYB as `--local-folder` |
| `-e UMASK=077` | 077 | umask for files created during a GYB run |
| `-e LOG_FILE=/config/gyb.log` | - | If provided, cron output is also written to this file (see [Logs](#logs)) |
| `-e MEM_LIMIT=1024M` | - | If provided, limit GYB's memory usage. Useful for large backups on memory constrained containers. Is passed to GYB as `--memory-limit`  |
| `-e DEBUG=1` | - | If provided, pass `--debug` to GYB  |
| `-e JOB_FULL_CMD` | `/app/gyb --action backup` | Command for the 'Full' job |
| `-e JOB_FULL_CRON` | 0 1 * * SUN | Cron syntax for when the 'Full' job runs |
| `-e JOB_INC_CMD` | `/app/gyb --action backup --search "newer_than:3d"` | Command for the 'Incremental' job |
| `-e JOB_INC_CRON` | 0 1 * * MON-SAT | Cron syntax for when the 'Incremental' job runs |
| `-e JOB_EXTRA_CMD` | - | Command for the 'Extra' job |
| `-e JOB_EXTRA_CRON` | - | Cron syntax for when the 'Extra' job runs |
| `-e MAIL_TO` | - | Optionally send mail to this address on cron job failure |
| `-e MAIL_FROM` | - | Optionally send mail from this address on cron job failure |
| `-e MAIL_SUBJECT` | Error running Got Your Back job | Subject for the optional failure notification mail |
| `-e SMTP_HOST` | - | SMTP Host for sending failure notification mails |
| `-e SMTP_PORT` | - | SMTP Port for sending failure notification mails |
| `-e SMTP_USER` | - | SMTP User for sending failure notification mails |
| `-e SMTP_PASS` | - | SMTP Password for sending failure notification mails |
| `-e SMTP_TLS` | YES | Use TLS (STARTTLS) when connecting to SMTP_HOST |
| `-e SMTP_TLS_VERIFY` | YES | Check SMTP_HOST's certificate. Set to `NO` if it's self-signed |
| `-e USE_SERVICE_ACCOUNT=1` | - | If set, tells GYB to use Google Workspace service account credentials. This enables additional GYB commands that can only be used against Google Workspace accounts. Is passed to GYB as `--service-account` |
| `-v /config` | - | All data is stored in this volume |

## Bootstrapping Notes
See the [GYB Wiki](https://github.com/jay0lee/got-your-back/wiki#running-gyb-for-the-first-time) for authoritative steps. These are some rough notes:

- Run `docker run -it -e EMAIL=example@gmail.com -v ${PWD}/config:/config awbn/gyb /app/gyb --action create-project` and open the URL provided in the console
- Give access to GAM and paste the token into console
- Open the URL provided
- Configure the OAuth consent screen:
  - 'External' (if you're not using a gmail account that's part of a workspace)
  - 'App Name': GYB Docker (or whatever you want)
  - 'Support Email' and 'Developer Contact': your contact email
  - 'Scopes': none
  - 'Test users': Email addresses of the users you want to backup
- In the Google cloud console, click 'Credentials' -> 'Create Credential' -> 'OAuth client ID':
  - 'Application Type': Desktop App
  - 'Name': GYB (or anything)
- Run `docker run -it -e EMAIL=example@gmail.com -v ${PWD}/config:/config awbn/gyb /app/gyb --action estimate --search "newer_than:7d"`
  - Select Scopes (Recommended: 1,6 for read-only backups; Gmail read-only and storage quota)
  - Visit provided URL and paste token into the console
    - Google may warn you that the app is not verified; this is the app that you created in the step above (to verify: click the name of the app and check that the email matches what you entered as the developer email above). You're giving yourself permissions to your own data
  - At this point the credentials should be fully saved and the service account authorized
    - Note: If you are using an 'external' app with a status of 'testing' the tokens expire every seven days and need to be manually refereshed. See [this issue](https://github.com/jay0lee/got-your-back/issues/282) and [Google's documentation](https://support.google.com/cloud/answer/10311615#zippy=%2Ctesting)

## Rootless variant
The `-rootless` images (built from `rootless.Dockerfile`) don't need root at all. There's no s6 init, no `PUID`/`PGID`, and nothing changes file ownership at startup: GYB simply runs as whichever user you start the container with. This makes it a good fit if you want to drop all capabilities and use a read-only root filesystem, or if your platform picks the user for you.

It works like the default image, with a few differences:
- **User**: the container runs as `1000:1000` unless you pick another with `--user` (or `user:` in Compose). That user must own `/config`. A new Docker volume is already owned by `1000:1000`; for a bind mount or a different user, `chown` the folder first. If the user can't write to `/config`, the container exits at startup and tells you why. `PUID` and `PGID` aren't used.
- **Scheduling**: jobs are run by [supercronic](https://github.com/aptible/supercronic) instead of crond, in the container's timezone (`TZ`). The health check, logs and failure emails work exactly as in the default image.
- **URL shortener**: `NOSHORTURLS` isn't supported, since the root filesystem may be read-only. Block the shortener from outside the container instead, with `--add-host gyb-shortn.jaylee.us:127.0.0.1` (or `extra_hosts` in Compose).
- **Writable paths**: only `/config` (plus `LOG_FILE`'s folder, if it's somewhere else) and `/tmp` need to be writable. If you use a read-only root filesystem, mount a tmpfs on `/tmp`.
- **LinuxServer.io extras**: Docker mods and `/custom-cont-init.d` aren't available.

All other settings in the [Parameters](#parameters) table work the same way, including `FILE__` variables.

```yaml
services:
  gyb:
    image: awbn/gyb:rootless
    user: 1026:100
    read_only: true
    tmpfs: [/tmp]
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    extra_hosts: ["gyb-shortn.jaylee.us:127.0.0.1"]
    environment:
      - TZ=America/Los_Angeles
      - EMAIL=example@gmail.com
    volumes:
      - ./config:/config
    restart: unless-stopped
```

To switch from the default image, keep your existing `/config` and give it to the new user once (`chown -R`).

## Build, test, and release docker image

### Build
Provide the GYB release and image tag:
```bash
# e.g. docker build --build-arg GYB_VERSION=v1.97 -t awbn/gyb:1.97 .
docker build --build-arg GYB_VERSION=<tag> -t <repo>:<version> .
docker build -f rootless.Dockerfile --build-arg GYB_VERSION=<tag> -t <repo>:<version>-rootless .
```

`buildx.sh` builds both images for all platforms, tagged `<repo>:<version>` and `<repo>:<version>-rootless`. Use `--only default` or `--only rootless` to build just one. Any extra arguments are passed to `docker buildx build`. Multi-platform images can't be loaded into your local Docker, so to test locally, build a single platform (e.g. `PLATFORMS=linux/amd64 ./buildx.sh v1.97 awbn/gyb --load`).
```bash
# e.g. ./buildx.sh v1.97 awbn/gyb --push
./buildx.sh [--only default|rootless] <tag> <repo> [buildx args...]
```

### Test
Uses [container-structure-test](https://github.com/GoogleContainerTools/container-structure-test). `test.sh` downloads a pinned version for your machine the first time it runs. Note that this does NOT extensively test GYB (other than ensuring the script can launch); it tests the container wrappers and functionality.

`test.sh` tests both images for a tag: `./test.sh awbn/gyb:1.97` tests `awbn/gyb:1.97` and `awbn/gyb:1.97-rootless` (for `latest`, the rootless image is `awbn/gyb:rootless`). Use `--only` to test just one. Each image runs its own tests (`test/tests.yml` or `test/tests-rootless.yml`) plus the shared ones (`test/tests-common.yml`), and `test/mail.sh` sends a failure email to a fake SMTP server. The rootless image is also run fully locked down by `test/hardened.sh` (read-only root, no capabilities, a user other than 1000) to check that a scheduled job still runs. CI uses the same script.

If you write a test, note that container-structure-test replaces `$NAME` in a test's arguments before the container sees them, so pass values in some other way (e.g. `printenv`).
```bash
# e.g. ./test.sh awbn/gyb:1.97
./test.sh [--only default|rootless] <repo>[:<tag>]
```

### Release
`release.sh` is a helper script for [re]publishing docker images against GYB releases using remote GitHub workflows. Useful if the code in the repo changes and you want to publish an updated docker image against a GYB release. Uses the [GitHub cli](https://cli.github.com/). Note: must have contributor access to [awbn/docker-gyb](https://github.com/awbn/docker-gyb).
```bash
# e.g. ./release.sh v1.42 v1.50
./release.sh <tag...>
```

New GYB releases are detected and published daily via the `gyb_check` github workflow.

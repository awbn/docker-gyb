# [awbn/docker-gyb](https://github.com/awbn/docker-gyb)
A containerized version of [Got Your Back](https://github.com/jay0lee/got-your-back) to make it easy to back up your Gmail account. Can run standalone or as  full/incremental cron jobs (default).

[![Build and tests](https://img.shields.io/github/actions/workflow/status/awbn/docker-gyb/docker.yml?branch=main&logo=github&style=for-the-badge)](https://github.com/awbn/docker-gyb/actions/workflows/docker.yml) [![GYB Release](https://img.shields.io/github/actions/workflow/status/awbn/docker-gyb/gyb_release.yml?branch=main&label=Release&logo=docker&style=for-the-badge)](https://github.com/awbn/docker-gyb/actions/workflows/gyb_release.yml) [![awbn/gyb](https://img.shields.io/docker/pulls/awbn/gyb?style=for-the-badge&logo=docker)](https://hub.docker.com/r/awbn/gyb)

## Supported platforms
This is a multi-platform image which supports `linux/amd64` and `linux/arm64`. `linux/arm/v7` support is deprecated due to the upstream LSIO images deprecating armhf support.

## Tags
Tags correspond with [Got Your Back releases](https://github.com/jay0lee/got-your-back/releases). `:latest` refers to the latest published release and all releases since 1.40 are available as individual tags (e.g. `awbn/gyb:1.40` contains GYB v1.40).

## Usage
[GYB](https://github.com/jay0lee/got-your-back) requires some bootstrapping to create a new project before you can run. For complete bootstrapping steps, see the [GYB Wiki](https://github.com/jay0lee/got-your-back/wiki#running-gyb-for-the-first-time).

### First Run
```bash
docker run -it -e EMAIL=example@gmail.com -e NOCRON=1 -v ${PWD}/config:/config awbn/gyb /app/gyb --action create-project
```
...and follow the prompts. See [Bootstrapping Notes](#bootstrapping-notes) below for an abbreviated set of steps.

Once you've created the project and cached the credentials, you can run the container to start the background cron jobs. Make sure that you mount the same volume so that the credentials are re-used.

### First backup
The first full backup will (likely) take a long time. It's recommend to do this as a one-off run: 
```bash
docker run -it -e EMAIL=example@gmail.com -e NOCRON=1 -v ${PWD}/config:/config awbn/gyb /app/gyb --action backup
```

### Backups
By default you should start the container in detached mode and let it run incremental and full backups. See the docker-compose or CLI examples below.

#### Docker compose
```yaml
version: "3"
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
docker run -it -e EMAIL=example@gmail.com -e NOCRON=1 -v ${PWD}/config:/config awbn/gyb /app/gyb --action restore
```

Note that you must have given the OAuth token 'write' permissions to your gmail account during bootstrapping for restore to work. If you didn't, you can delete the `<email>.cfg` file from the `/config` volume to force GYB to prompt for a new token.

## Advanced Usage
This container is based on [LinuxServer.io](https://linuxserver.io)'s Alpine base image. This means you can take advantage of all the LSIO goodness, including regular base image updates, user/group identification, loading environment variables from files (docker secrets), etc. See the [LSIO docs](https://docs.linuxserver.io) for more info.

### Getting notified of failures
This container can be configured to send you an email if your cron job(s) fail. To do so, you'll need to pass in the `MAIL_TO`, `MAIL_FROM`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, and, optionally, the `SMTP_TLS` env variables.

### Customizing the jobs
By default the container has two jobs which are run on a regular schedule. The 'Full' job runs at 1am every Sunday (timezone depends on the container's TZ) and does a full backup. The incremental job runs at 1am Monday-Saturday and does a partial backup using GYB's [`--search` parameter](https://github.com/jay0lee/got-your-back/wiki#improving-backup-speed-incremental-daily-backups). You can customize the timing of these jobs and the GYB command which is run using environment variables. You can also define your own custom job as well.

To run the full job at a different schedule, set the `JOB_FULL_CRON` env variable to [valid cron syntax](https://crontab.guru). To run a different command for that job (e.g., to include only a particular label), set the `JOB_FULL_CMD` env variable to `/app/gyb <valid gyb command>`. See the [GYB Wiki](https://github.com/jay0lee/got-your-back/wiki) for more info on valid GYB commands.

In addition to the `JOB_FULL_` job, there are also the `JOB_INC_` and `JOB_EXTRA_` jobs. By default, the extra job is not used, but could be used to, e.g., back up a particular label more often. See the [Parameters](#parameters) section for more details.

### Using a Google Workspace Service Account
By default, the container is configured to call GYB using the the standard 3-legged OAuth authentication to set up the credentials for the account. GYB does support the use of Google Workspace service account credentials, which allows Google Workspace admins to use GYB on their users' accounts without requiring the users' passwords. It is recommended you follow the guide in the [GYB wiki](https://github.com/GAM-team/got-your-back/wiki#google-workspace-admins) for setting up the service account credentials, then include the oauth2service.json credentials file in the volume you mount to `/config` to make it accessible to GYB. Setting the env variable `USE_SERVICE_ACCOUNT=1` will append the `--service-account` flag to all GYB calls, enabling it for both the cron jobs and `docker run` calls. Using service account credentials enables using the Google Workspace-only GYB commands with the container.

## File permissions
By default the container creates all new files in `/config` with a umask of `077` (`rw` for the owner, no permissions for group/others). This is because sensitive files containing auth tokens, etc will get created. However, this can cause issues if you swap users or if you access the files outside of the container. If you want the files created to be more widely accessible, you can pass a different umask (e.g., `022`: `rw` for owner `r` for everyone else, or `100`: `rw` for everyone) via the `UMASK` environment variable. Make sure you understand how [umask works](https://en.wikipedia.org/wiki/Umask) before relying on this for security.

## Parameters

| Parameter | Default | Function |
| :----: | --- | --- |
| `-e EMAIL=example@gmail.com` | - | (Required) Email address to use with GYB |
| `-e TZ=Americas/Los_Angeles` | UTC | Timezone (affects cron schedule) |
| `-e NOCRON=1` | - | If set, don't start crond. Useful for one-off container runs (e.g., GYB project creation) or actions that may take a long time to run (e.g., restores) |
| `-e NOSHORTURLS=1` | - | If set, block the GYB URL shortener |
| `-e CONFIG_DIR=/config` | `/config` | Directory for GYB config (ideally volume mounted). Is passed to GYB as `--config-folder` |
| `-e DEST_DIR=/config/data` | `/config/data` | Destination for backups (ideally volume mounted). Is passed to GYB as `--local-folder` |
| `-e UMASK=077` | 077 | umask for files created during a GYB run |
| `-e LOG_FILE=/config/gyb.log` | - | If provided, will log cron output to this file instead of the docker log |
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
| `-e MAIL_SUBJECT` | Error Running Got Your Back | Subject for the optional failure notification mail |
| `-e SMTP_HOST` | - | SMTP Host for sending failure notification mails |
| `-e SMTP_PORT` | - | SMTP Port for sending failure notification mails |
| `-e SMTP_USER` | - | SMTP User for sending failure notification mails |
| `-e SMTP_PASS` | - | SMTP Password for sending failure notification mails |
| `-e SMTP_TLS` | YES | Use TLS when connecting to SMTP_HOST|
| `-e USE_SERVICE_ACCOUNT=1` | - | If set, tells GYB to use Google Workspace service account credentials. This enables additional GYB commands that can only be used against Google Workspace accounts. Is passed to GYB as `--service-account` |
| `-v /config` | - | All data is stored in this volume |

## Bootstrapping Notes
See the [GYB Wiki](https://github.com/jay0lee/got-your-back/wiki#running-gyb-for-the-first-time) for authoritative steps. These are some rough notes:

- Run `docker run -it -e EMAIL=example@gmail.com -e NOCRON=1 -v ${PWD}/config:/config awbn/gyb /app/gyb --action create-project` and open the URL provided in the console
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
- Run `docker run -it -e EMAIL=example@gmail.com -e NOCRON=1 -v ${PWD}/config:/config awbn/gyb /app/gyb --action estimate --search "newer_than:7d"`
  - Select Scopes (Recommended: 1,6 for read-only backups; Gmail read-only and storage quota)
  - Visit provided URL and paste token into the console
    - Google may warn you that the app is not verified; this is the app that you created in the step above (to verify: click the name of the app and check that the email matches what you entered as the developer email above). You're giving yourself permissions to your own data
  - At this point the credentials should be fully saved and the service account authorized
    - Note: If you are using an 'external' app with a status of 'testing' the tokens expire every seven days and need to be manually refereshed. See [this issue](https://github.com/jay0lee/got-your-back/issues/282) and [Google's documentation](https://support.google.com/cloud/answer/10311615#zippy=%2Ctesting)

## Build, test, and release docker image

### Build
```bash
# e.g. docker build -t awbn/gyb .
docker build -t <repo>[:<tag>] .
```

Multi-platform image:
```bash
# e.g. ./buildx.sh -t awbn/gyb 
./buildx.sh -t <repo>[:<tag>]
```

### Test
Uses [container-structure-test](https://github.com/GoogleContainerTools/container-structure-test). Will download the binary if
it's not already on the path. Note that this does NOT extensively test GYB (other than ensuring the script can launch); it
tests the container wrappers and functionality.
```bash
# e.g. ./test.sh awbn/gyb
./test.sh <repo>[:<tag>]
```

### Release
`release.sh` is a helper script for [re]publishing docker images against GYB releases using remote GitHub workflows. Useful if the code in the repo changes and you want to publish an updated docker image against a GYB release. Uses the [GitHub cli](https://cli.github.com/). Note: must have contributor access to [awbn/docker-gyb](https://github.com/awbn/docker-gyb).
```bash
# e.g. ./release.sh v1.42 v1.50
./release.sh <tag...>
```

# Jenkins Bootstrap

Rebuild a single-node Jenkins controller for the home media infrastructure using Ubuntu Server, Docker, and this repository. Jenkins configuration and seed-job definitions are stored in Git; runtime state is kept in `./jenkins_home`.

## Disaster recovery

1. Install Ubuntu Server and Git. Install Docker Engine and the Docker Compose v2 plugin using Docker's [official Ubuntu instructions](https://docs.docker.com/engine/install/ubuntu/). Enable and start Docker, then verify `docker --version` and `docker compose version` work for your account.
2. Clone this public repository and enter it:

	```sh
	git clone https://github.com/danyeles/jenkins-bootstrap.git
	cd jenkins-bootstrap
	```

3. Start Jenkins:

	```sh
	./bootstrap.sh
	```

	The script creates `jenkins_home`, `casc`, and `seed-jobs` when missing, builds the Jenkins image with the plugins in `plugins.txt`, and starts the Compose service.
4. Open `http://<ubuntu-server-ip>:8080` from a machine that can reach the server. On the Jenkins unlock screen, read the initial administrator password from `./jenkins_home/secrets/initialAdminPassword` on the Ubuntu host. The same file is available in the container at `/var/jenkins_home/secrets/initialAdminPassword`. Complete Jenkins' first-run setup and create an administrator.
5. Sign in and run the automatically created `ArrSeed` job. It checks out the public `jenkins-infra` repository over HTTPS and runs its root `seed.groovy` Pipeline script. That pipeline reads `apps.yaml` and generates the deployment jobs.
6. Run the generated jobs to deploy the media infrastructure. The public `jenkins-shared-lib` repository is registered globally in JCasC and is available implicitly to pipeline scripts.

## What is managed here

- `docker-compose.yml` runs Jenkins, publishes ports `8080` and `50000`, persists `./jenkins_home`, and mounts the Docker socket.
- `Dockerfile` derives from `jenkins/jenkins:lts`, installs the Docker CLI used by deployment pipelines, and installs plugins with the official `jenkins-plugin-cli` during image build.
- `plugins.txt` declares the required Jenkins plugins, including Pipeline Utility Steps for `readYaml`; plugin dependencies are resolved by the plugin manager.
- `casc/jenkins.yaml` sets the system message and controller executors, then loads the seed-job DSL file.
- `casc/libraries.yaml` registers the public shared library using HTTPS and the `main` branch.
- `seed-jobs/seed-job.groovy` defines the `ArrSeed` Pipeline job and points it at `seed.groovy` in `jenkins-infra`.
- `bootstrap.sh` creates directories, checks the Docker prerequisites, builds and starts the service, and prints access and unlock information.

## Persistence and recovery notes

`jenkins_home` contains Jenkins runtime data, including users, job state, build history, and the initial setup state. Back it up separately if you need to preserve that data; the repository recreates controller configuration and jobs, but cannot restore build history or user data that was never backed up. To recover from a failed SSD, a fresh clone plus `./bootstrap.sh` recreates the configured controller, after which run `ArrSeed` to regenerate deployment jobs.

The `lts` image tag and unversioned plugin entries intentionally follow the current Jenkins LTS and compatible plugin releases. This favors a maintainable fresh recovery, but does not freeze exact binary versions. For byte-for-byte repeatability, pin the Jenkins image to a tested version/digest and pin each plugin version after validating an upgrade.

## Security

The Docker socket mount gives Jenkins jobs effective control of the Docker daemon, which is generally equivalent to root access on the Ubuntu host. Only run trusted pipeline code and restrict access to Jenkins and the server. Ports `8080` and `50000` are published on all host interfaces; use a firewall and do not expose Jenkins directly to the public internet without a properly configured HTTPS reverse proxy and access controls.

All Git repository URLs in this bootstrap use public HTTPS. No SSH keys or GitHub credentials are needed.

The infra repository's current `seed.groovy` imports the library as `my-shared-lib`; JCasC provides that name as a compatibility alias to the same public repository while also registering the requested `jenkins-shared-lib` name.

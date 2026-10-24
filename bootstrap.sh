#!/usr/bin/env bash
# Create the expected bind-mount directories and launch the reproducible Jenkins configuration.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
JENKINS_HOME_DIR="${SCRIPT_DIR}/jenkins_home"

if ! command -v docker >/dev/null 2>&1; then
  printf 'Docker is required. Install Docker Engine and Compose v2, then rerun this script.\n' >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'Docker Compose v2 is required. Install the Compose plugin, then rerun this script.\n' >&2
  exit 1
fi

if [[ ! -S /var/run/docker.sock ]]; then
  printf 'Docker socket /var/run/docker.sock is missing. Ensure the Docker daemon is running.\n' >&2
  exit 1
fi

mkdir -p "${JENKINS_HOME_DIR}" "${SCRIPT_DIR}/casc" "${SCRIPT_DIR}/seed-jobs"

# The official image runs as UID 1000. Set only the bind-mount root owner; existing files are untouched.
if [[ "$(stat -c '%u' "${JENKINS_HOME_DIR}")" != "1000" ]]; then
  if [[ "$(id -u)" == "0" ]]; then
    chown 1000:1000 "${JENKINS_HOME_DIR}"
  elif command -v sudo >/dev/null 2>&1; then
    sudo chown 1000:1000 "${JENKINS_HOME_DIR}"
  else
    printf 'Warning: %s is not owned by UID 1000 and sudo is unavailable; Jenkins may not be able to write to it.\n' "${JENKINS_HOME_DIR}" >&2
  fi
fi

export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
cd "${SCRIPT_DIR}"
docker compose build --pull
docker compose up -d

SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
printf '\nJenkins is starting.\n'
printf 'Local URL: http://localhost:8080\n'
if [[ -n "${SERVER_IP}" ]]; then
  printf 'Server URL: http://%s:8080\n' "${SERVER_IP}"
fi
printf 'Initial administrator password (host): %s/secrets/initialAdminPassword\n' "${JENKINS_HOME_DIR}"
printf 'Initial administrator password (container): /var/jenkins_home/secrets/initialAdminPassword\n'
printf 'View startup logs with: docker compose logs -f jenkins\n'
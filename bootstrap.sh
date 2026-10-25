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
  printf 'Docker socket /var/run/docker.sock is missing. Start Docker Engine and verify the socket exists before running bootstrap.\n' >&2
  exit 1
fi

DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)" || {
  printf 'Unable to detect the group ID of /var/run/docker.sock.\n' >&2
  exit 1
}
if [[ ! "${DOCKER_GID}" =~ ^[0-9]+$ ]]; then
  printf 'Invalid group ID detected for /var/run/docker.sock: %s\n' "${DOCKER_GID}" >&2
  exit 1
fi

ENV_FILE="${SCRIPT_DIR}/.env"
TEMP_ENV_FILE="$(mktemp "${SCRIPT_DIR}/.env.XXXXXX")" || {
  printf 'Unable to create a temporary .env file in %s.\n' "${SCRIPT_DIR}" >&2
  exit 1
}
cleanup() {
  if [[ -n "${TEMP_ENV_FILE:-}" && -f "${TEMP_ENV_FILE}" ]]; then
    rm -f -- "${TEMP_ENV_FILE}"
  fi
}
trap cleanup EXIT

if [[ -f "${ENV_FILE}" ]]; then
  awk '!/^[[:space:]]*DOCKER_GID[[:space:]]*=/' "${ENV_FILE}" > "${TEMP_ENV_FILE}" || {
    printf 'Unable to update %s.\n' "${ENV_FILE}" >&2
    exit 1
  }
fi
printf 'DOCKER_GID=%s\n' "${DOCKER_GID}" >> "${TEMP_ENV_FILE}" || {
  printf 'Unable to write Docker group ID to %s.\n' "${TEMP_ENV_FILE}" >&2
  exit 1
}
mv -- "${TEMP_ENV_FILE}" "${ENV_FILE}" || {
  printf 'Unable to update %s.\n' "${ENV_FILE}" >&2
  exit 1
}
TEMP_ENV_FILE=""

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

printf 'Detected Docker socket group ID: %s\n' "${DOCKER_GID}"
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
#!/usr/bin/env bash

shopt -s extglob
shopt -s dotglob
shopt -s nullglob

if [ -z "$BASH_VERSION" ]; then
  echo "Wrong interpreter, please run \"$0\" with bash"
  exit 1
fi

SCRIPT_PATH="$(dirname $(realpath -e "${BASH_SOURCE[0]}"))"
pushd "$SCRIPT_PATH" >/dev/null 2>&1

NEEDS_REBOOT=0
PODMAN_LOW_PORT=${PODMAN_LOW_PORT:-443}
NGINX_PATH=${NGINX_PATH:-"/opt/podman-nginx-ldap"}
NGINX_USER=${NGINX_USER:-"nginx"}
NGINX_USER_SUBUID_LOW=${NGINX_USER_SUBUID_LOW:-200000}
NGINX_USER_SUBUID_HIGH=${NGINX_USER_SUBUID_HIGH:-265535}
NGINX_USER_SUBGID_LOW=${NGINX_USER_SUBGID_LOW:-200000}
NGINX_USER_SUBGID_HIGH=${NGINX_USER_SUBGID_HIGH:-265535}

dnf install -y httpd-tools openssl podman-docker python3 python3-yaml
touch /etc/containers/nodocker

if [[ ! -f /etc/sysctl.d/98-unprivileged-low-port.conf ]]; then
  echo 'net.ipv4.ip_unprivileged_port_start = 443' | tee /etc/sysctl.d/98-unprivileged-low-port.conf
  NEEDS_REBOOT=1
fi

mkdir -p "${NGINX_PATH}"/.config/systemd/user
if ! id "${NGINX_USER}" >/dev/null 2>&1; then
  adduser -d "${NGINX_PATH}" -M -r -s /bin/bash "${NGINX_USER}"
  echo 'XDG_RUNTIME_DIR=/run/user/$(id -u)'                        > "${NGINX_PATH}"/.profile
  echo 'DBUS_SESSION_BUS_ADDRESS=unix:path=${XDG_RUNTIME_DIR}/bus' >> "${NGINX_PATH}"/.profile
  echo 'export DBUS_SESSION_BUS_ADDRESS'                           >> "${NGINX_PATH}"/.profile
  echo 'export XDG_RUNTIME_DIR'                                    >> "${NGINX_PATH}"/.profile
  chown -R "${NGINX_USER}":"${NGINX_USER}" "${NGINX_PATH}"
  loginctl enable-linger "${NGINX_USER}"
  usermod -a -G systemd-journal "${NGINX_USER}"
fi

touch /etc/subuid
touch /etc/subgid
if ! grep --quiet "${NGINX_USER}" /etc/subuid; then
  usermod --add-subuids ${NGINX_USER_SUBUID_LOW}-${NGINX_USER_SUBUID_HIGH} "${NGINX_USER}"
  NEEDS_REBOOT=1
fi
if ! grep --quiet "${NGINX_USER}" /etc/subgid; then
  usermod --add-subgids ${NGINX_USER_SUBGID_LOW}-${NGINX_USER_SUBGID_HIGH} "${NGINX_USER}"
  NEEDS_REBOOT=1
fi

if [[ ! -f /usr/local/bin/podman-compose ]]; then
  if [[ -f "$SCRIPT_PATH"/podman-compose ]]; then
    cp -v "$SCRIPT_PATH"/podman-compose /usr/local/bin/podman-compose
  else
    curl -o /usr/local/bin/podman-compose https://raw.githubusercontent.com/containers/podman-compose/devel/podman_compose.py
  fi
fi
chmod 755 /usr/local/bin/podman-compose

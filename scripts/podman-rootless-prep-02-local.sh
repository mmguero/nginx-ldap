#!/usr/bin/env bash

shopt -s extglob
shopt -s dotglob
shopt -s nullglob

if [ -z "$BASH_VERSION" ]; then
  echo "Wrong interpreter, please run \"$0\" with bash"
  exit 1
fi

NGINX_PATH=${NGINX_PATH:-"/opt/podman-nginx-ldap"}
NGINX_USER=${NGINX_USER:-"nginx"}

# as authentication will be done by LDAP, this username/password won't actually be used
BASIC_USER=${BASIC_USER:-"analyst"}
BASIC_PASSWORD=${BASIC_PASSWORD:-"L^RK@EK!$'A5hjYP"}
LDAP_TYPE=${LDAP_TYPE:-"winldap"}

XDG_RUNTIME_DIR=/run/user/$(id -u $NGINX_USER)
mkdir -p "$XDG_RUNTIME_DIR"
chown $NGINX_USER:$NGINX_USER "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# execute the entrypoint command specified
su --shell /bin/bash --preserve-environment ${NGINX_USER} << EOF
shopt -s extglob
shopt -s dotglob
shopt -s nullglob
set -e

export USER="${NGINX_USER}"
export HOME="${NGINX_PATH}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"

pushd "\${HOME}" >/dev/null 2>&1

for FILE in ./images/*; do podman load -i "\$FILE"; done
podman images

echo -e -n "${BASIC_USER}\n${BASIC_PASSWORD}\n${BASIC_PASSWORD}\n${LDAP_TYPE}\n\n\n" | ./scripts/auth_setup.sh

sed -i -e "s/^\([[:space:]]*NGINX_BASIC_AUTH[[:space:]]*:[[:space:]]\).*/\1'false'/" ./docker-compose.yml
sed -i -e "s/^\([[:space:]]*NGINX_LDAP_TLS_STUNNEL[[:space:]]*:[[:space:]]\).*/\1'false'/" ./docker-compose.yml
sed -i -n '/^[[:space:]]*healthcheck:/q;p' ./docker-compose.yml

### put other scripting stuff you need to do here #####################
# to reference variables defined outside this heredoc use ${VARIABLE} #
# to reference variables defined inside this heredoc use \${VARIABLE} #
#######################################################################

popd >/dev/null 2>&1

set +x

EOF

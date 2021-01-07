#!/bin/bash

shopt -s dotglob

if [[ "$OSTYPE" == "darwin"* ]]; then
  readonly SED_ARGS='-i .wksbck'
else
  readonly SED_ARGS='-i'
fi

readonly INFRASTRUCTURE=${INFRASTRUCTURE:-"liferay.cloud"}
readonly API_URL=https://api.${INFRASTRUCTURE}
readonly LOGIN_URL=${API_URL}/login
readonly PROJECTS_URL=${API_URL}/projects

main() {
  validate_program_installation

  print_opening_instructions

  prompt_for_database_secret_variables

  prompt_for_environments

  create_database_secrets
}

validate_program_installation() {
  if ! git status &>/dev/null; then
    echo >&2 "This script must be run from a git repository"

    exit
  fi

  if ! curl --version &>/dev/null; then
    CURL=false
  fi

  if ! wget --version &>/dev/null; then
    WGET=false
  fi

  if [[ $CURL == false ]] && [[ $WGET == false ]]; then
    echo >&2 "This script requires curl or wget to be installed"

    exit
  fi

  if ! lcp version &>/dev/null; then
    echo >&2 "This script requires lcp to be installed"

    exit
  fi
}

print_opening_instructions() {
  printf "\n### DXP Cloud Project Update Secrets V4 ###\n\n"
  printf "The script updates the required secrets for v4 on environments.\n\n"

  read -rs -p "Press enter to continue: "
}

prompt_for_database_secret_variables() {
  printf "\n"
  read -p "Please enter your project id: " -r PROJECT_ID

  echo 'Please login to DXP Cloud Console'
  lcp login

  LCP_CONFIG_FILE=$HOME/.lcp

  if [[ -f "$LCP_CONFIG_FILE" ]]; then
    echo "$LCP_CONFIG_FILE exists"
  else
    echo "$LCP_CONFIG_FILE does not exist!"
    exit 1
  fi

  TOKEN=$(grep -A 2 "infrastructure=${INFRASTRUCTURE}" "$LCP_CONFIG_FILE" | awk -F "=" '/token/ {print $2}')

  readonly PORTAL_ALL_PROPERTIES_LOCATION_V3=lcp/liferay/configs/common/portal-all.properties
  readonly PORTAL_ALL_PROPERTIES_LOCATION_V4=liferay/configs/common/portal-all.properties

  local PORTAL_ALL_PROPERTIES_LOCATION=${PORTAL_ALL_PROPERTIES_LOCATION_V3}
  if [[ ! -f ${PORTAL_ALL_PROPERTIES_LOCATION_V3} ]]; then
    local PORTAL_ALL_PROPERTIES_LOCATION=${PORTAL_ALL_PROPERTIES_LOCATION_V4}
  fi

  DATABASE_PASSWORD=$(grep "jdbc.default.password" "${PORTAL_ALL_PROPERTIES_LOCATION}" | cut -d '=' -f 2)

  [[ -z "${DATABASE_PASSWORD}" ]] &&
    read -p "Could not find jdbc.default.password in ${PORTAL_ALL_PROPERTIES_LOCATION}. Please enter your database password: " -r DATABASE_PASSWORD
}

prompt_for_environments() {
  printf '\nPlease enter a comma-delimited list of the different environments in your project to update the required secrets.'
  printf '\nFor example, you can write "dev,prd,other". In order to create the secrets in the environments, you must be either'
  printf '\nan ADMIN or OWNER in the environment.\n\n'

  IFS=',' read -p 'Please enter a comma-delimited list of environments: ' -ra ENVIRONMENTS

  ENVIRONMENTS=("${ENVIRONMENTS[@]}")

  printf "\nThis script will update the secrets for the following environments:\n"

  for env in "${ENVIRONMENTS[@]}"; do
    echo "$env"
  done
}

create_database_secrets() {
  for env in "${ENVIRONMENTS[@]}"; do
    local secrets
    local env_id="${PROJECT_ID}-${env}"

    if [ "$WGET" != false ]; then
      secrets=$(
        wget "${PROJECTS_URL}/${env_id}/secrets" \
          --header="Authorization: Bearer ${TOKEN}" \
          --header='content-type: application/x-www-form-urlencoded' \
          --auth-no-challenge \
          -O -
      )
    else
      secrets=$(
        curl "${PROJECTS_URL}/${env_id}/secrets" \
          -X GET \
          -H "Authorization: Bearer ${TOKEN}"
      )
    fi

    create_secret "${env_id}" "${secrets}" 'lcp-secret-database-name' 'lportal'
    create_secret "${env_id}" "${secrets}" 'lcp-secret-database-user' 'dxpcloud'
    create_secret "${env_id}" "${secrets}" 'lcp-secret-database-password' "${DATABASE_PASSWORD}"
  done
}

create_secret() {
  local env_id="${1}"
  local secrets="${2}"
  local secret_name="${3}"
  local secret_value="${4}"

  if echo "${secrets}" | grep "${secret_name}" &>/dev/null; then
    echo "The secret '${secret_name}' already exists, skipping secret creation"

    return
  fi

  echo "creating secret for ${env_id} ${secret_name}=${secret_value}"

  if [ "$WGET" != false ]; then
    wget "${PROJECTS_URL}/${env_id}/secrets" \
      --header="Authorization: Bearer ${TOKEN}" \
      --header='content-type: application/x-www-form-urlencoded' \
      --auth-no-challenge \
      --post-data="name=${secret_name}&value=${secret_value}" \
      -O -
  else
    curl "${PROJECTS_URL}/${env_id}/secrets" \
      -X POST \
      -H "Authorization: Bearer ${TOKEN}" \
      -H 'Content-Type: application/json; charset=utf-8' \
      -d $'{
        "name": "'"${secret_name}"'",
        "value": "'"${secret_value}"'"
      }'
  fi
}

main

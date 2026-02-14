#!/bin/bash
# flux-bootstrap.sh
# for connecting  FluxCD pipeline smoothly to the cluster


while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --config) ENV_FILE="$2"; shift 2;;
        *.env) ENV_FILE="$1"; shift;;
        *) break;;
    esac
done

if [[ -z "${ENV_FILE}" ]] || [[ ! -r "${ENV_FILE}" ]]; then
    echo "Error in reading ${ENV_FILE}" >&2
    exit 1
fi

set -a
source "${ENV_FILE}"
set +a


echo "Installing Flux CLI..."
curl -fsSL "https://fluxcd.io/install.sh" | sudo bash

echo "Bootstrapping Flux into the cluster..."
flux bootstrap github \
  --owner=${GITHUB_USER} \
  --repository=${REPO_NAME} \
  --branch=${BRANCH_NAME} \
  --path=./clusters/my-cluster \
  --personal

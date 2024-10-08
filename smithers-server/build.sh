#!/bin/bash
set -e

# IMAGE_NAME=us-east1-docker.pkg.dev/budget-server-370523/docker-smithers/smithers-server:1.20
IMAGE_NAME=registry.smithers.private/smithers-server:1.20
GIT_URL=https://github.com/toiletpapar/smithers-server.git
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo "SCRIPT DIR: $SCRIPT_DIR"

docker buildx build -t $IMAGE_NAME --build-context repo=$GIT_URL $SCRIPT_DIR

# In cmd (baremetal)
# docker push registry.smithers.private/smithers-server:1.20

# In cmd
# gcloud auth configure-docker us-east1-docker.pkg.dev
# docker push us-east1-docker.pkg.dev/budget-server-370523/docker-smithers/smithers-server:1.20
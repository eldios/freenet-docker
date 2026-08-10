# freenet-docker task runner. Run `just` for the list; the dev shell
# (flake.nix) provides just, hadolint, actionlint, act, curl, jq.

set shell := ["bash", "-euo", "pipefail", "-c"]

image := "freenet-local"
dockerfile := "Dockerfile"

default:
    @just --list

# Every gate the CI workflow runs, in the same order
ci: lint build test

# Smoke test both images: they must start and stay up, not just build
test:
    ./test/smoke.sh

# Lint the container definition and the workflows
lint:
    hadolint {{dockerfile}}
    actionlint

# Build both images
build: build-stable build-dev

# Minimal image on scratch, for running nodes
build-stable:
    docker build --target stable -t {{image}}:stable -f {{dockerfile}} .

# Same binary on alpine, with a shell for debugging
build-dev:
    docker build --target dev -t {{image}}:dev -f {{dockerfile}} .

# Dry-run the GitHub workflow locally
workflow-check:
    act -n

# Start a throwaway node (the port must be explicit, see Dockerfile notes)
run data="./.run/data":
    mkdir -p {{data}}
    docker run -d --name freenet-test \
        -v "$(realpath {{data}}):/data" \
        -p 31337:31337/udp -p 31337:31337/tcp \
        {{image}}:dev network --disable-auto-update --network-port 31337

# Follow the node's log (it writes to files, not stdout, so docker logs is empty)
logs data="./.run/data":
    tail -f {{data}}/.local/state/freenet/freenet.*.log

# How many peers the running node has reached
peers data="./.run/data":
    @grep -oE 'connections=[0-9]+' {{data}}/.local/state/freenet/freenet.*.log | tail -1 || echo "no connection count logged yet"

# Stop and remove the throwaway node and its data
clean data="./.run/data":
    -docker rm -f freenet-test
    rm -rf {{data}}

# Shell inside the dev image
shell:
    docker run --rm -it --entrypoint sh {{image}}:dev

# Compare the pinned version against the newest upstream release
check-release:
    #!/usr/bin/env bash
    set -euo pipefail
    pinned="$(grep -oP '^ARG FREENET_VERSION=\K.*' {{dockerfile}} | head -1)"
    latest="$(curl -fsSL https://api.github.com/repos/freenet/freenet-core/releases/latest | jq -r .tag_name)"
    echo "pinned:  ${pinned}"
    echo "latest:  ${latest#v}"
    [ "${pinned}" = "${latest#v}" ] && echo "up to date" || echo "a newer release is available"

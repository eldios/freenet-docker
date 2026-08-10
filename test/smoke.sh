#!/usr/bin/env bash
# Smoke tests for both image targets. Checks the things that have actually
# broken: an image that builds but cannot start, a version that does not match
# the pin, and the client API becoming reachable.
set -euo pipefail

IMAGE="${IMAGE:-freenet-local}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
NAME="freenet-smoke-$$"
FAILED=0

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }

# A named volume rather than a bind mount: the daemon owns it, so this works
# the same whether the tests run on a developer's machine or in a container
# that talks to an outside daemon.
VOLUME="freenet-smoke-vol-$$"
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true; docker volume rm -f "$VOLUME" >/dev/null 2>&1 || true' EXIT

expected_version="$(grep -oE '^ARG FREENET_VERSION=.*' "$DOCKERFILE" | head -1 | cut -d= -f2)"
[ -n "$expected_version" ] || { echo "cannot read FREENET_VERSION from $DOCKERFILE" >&2; exit 1; }
echo "testing ${IMAGE} against Freenet ${expected_version}"

for target in stable dev; do
    echo
    echo "target: ${target}"
    tag="${IMAGE}:${target}"

    if docker image inspect "$tag" >/dev/null 2>&1; then
        pass "image present"
    else
        fail "image ${tag} not built"
        continue
    fi

    reported="$(docker run --rm --entrypoint /usr/local/bin/freenet "$tag" --version 2>&1 | head -1)"
    if [[ "$reported" == *"$expected_version"* ]]; then
        pass "reports version ${expected_version}"
    else
        fail "version mismatch: ${reported}"
    fi

    user="$(docker image inspect "$tag" --format '{{.Config.User}}')"
    if [ "$user" = "1000:1000" ]; then
        pass "runs as non-root"
    else
        fail "unexpected user: ${user:-root}"
    fi

    if docker image inspect "$tag" --format '{{json .Config.ExposedPorts}}' | grep -q '7509'; then
        fail "client API port 7509 is exposed"
    else
        pass "client API port not exposed"
    fi

    # The node writes state into /tmp at startup and panics if it cannot, which
    # a scratch image with no writable /tmp will do. Building is not enough:
    # it has to still be running a moment later.
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    docker volume rm -f "$VOLUME" >/dev/null 2>&1 || true
    docker run -d --name "$NAME" -v "${VOLUME}:/data" "$tag" \
        network --disable-auto-update --network-port 31337 >/dev/null 2>&1

    sleep 20
    if [ "$(docker inspect "$NAME" --format '{{.State.Running}}')" = "true" ]; then
        pass "still running after 20s"
    else
        fail "exited with code $(docker inspect "$NAME" --format '{{.State.ExitCode}}')"
        docker logs "$NAME" 2>&1 | tail -5 | sed 's/^/        /'
    fi

    if docker logs "$NAME" 2>&1 | grep -qi panic; then
        fail "panicked at startup"
    else
        pass "no panic"
    fi

    docker rm -f "$NAME" >/dev/null 2>&1 || true
done

echo
if [ "$FAILED" -eq 0 ]; then
    echo "all smoke tests passed"
else
    echo "smoke tests failed"
fi
exit "$FAILED"

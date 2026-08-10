#!/usr/bin/env bash
# Compares every version pinned in this repository against its upstream
# release, so a stale pin is something you are told about rather than
# something you notice months later.
set -euo pipefail

OUTDATED=0

report() {
    local name="$1" pinned="$2" latest="$3"
    if [ "$pinned" = "$latest" ]; then
        printf '  ok        %-34s %s\n' "$name" "$pinned"
    else
        printf '  outdated  %-34s %s -> %s\n' "$name" "$pinned" "$latest"
        OUTDATED=1
    fi
}

gh_latest() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" | jq -r '.tag_name'
}

freenet_pinned="$(grep -oE '^ARG FREENET_VERSION=.*' Dockerfile | cut -d= -f2)"
freenet_latest="$(gh_latest freenet/freenet-core)"
report "freenet-core" "$freenet_pinned" "${freenet_latest#v}"

alpine_pinned="$(grep -oE '^ARG ALPINE_VERSION=.*' Dockerfile | cut -d= -f2)"
alpine_latest="$(curl -fsSL 'https://hub.docker.com/v2/repositories/library/alpine/tags?page_size=50&ordering=last_updated' \
    | jq -r '[.results[].name | select(test("^3\\.[0-9]+$"))] | unique | sort_by(split(".") | map(tonumber)) | last')"
report "alpine" "$alpine_pinned" "$alpine_latest"

# Actions pinned to a bare major float within it, so only the major is
# compared; a fully pinned version is compared exactly.
# Fed by process substitution rather than a pipe: a piped while runs in a
# subshell, where setting OUTDATED would be lost and the summary would claim
# everything matched.
while read -r _ ref; do
    repo="${ref%@*}"
    pinned="${ref#*@}"
    latest="$(gh_latest "$repo")"
    if [[ "$pinned" =~ ^v[0-9]+$ ]]; then
        latest="${latest%%.*}"
    fi
    report "$repo" "$pinned" "$latest"
done < <(grep -hoE 'uses: [^ ]+@v[0-9][0-9.]*' .github/workflows/*.yml | sort -u)

echo
if [ "$OUTDATED" -eq 0 ]; then
    echo "every pin matches upstream"
else
    echo "some pins are behind upstream"
fi
exit "$OUTDATED"

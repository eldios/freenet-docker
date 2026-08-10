<p align="center">
  <img src="assets/logo.png" alt="freenet-docker" width="200">
</p>

# freenet-docker

Container images for [Freenet](https://freenet.org), built from the official
release binaries with a build you can read in one file.

## Which Freenet

The one in [freenet/freenet-core](https://github.com/freenet/freenet-core): a
peer-to-peer network where applications run on the network itself and are
opened from an ordinary browser.

It is **not** the original Freenet from 2000, which was renamed
[Hyphanet](https://www.hyphanet.org/). The two share a name and nothing else.
Many images published under the name `freenet` are the older Java project, so
check which one you are pulling.

## Goals

- One `Dockerfile`, short enough to read end to end before trusting it.
- The binary is verified against the checksums published with the release.
- Nothing in the runtime image that the node does not need.
- Defaults that do not surprise you: no exposed control API, no unbounded
  resource use.

## Images

| Target | Base | For |
|---|---|---|
| `stable` | `scratch` | Running a node. The binary, certificates and a passwd entry, nothing else |
| `dev` | `alpine` | The same binary with a shell, for looking at things from inside |

The Linux release binaries are `static-pie`, so `scratch` needs no libc.

## Verification

The build downloads the release archive and the `SHA256SUMS.txt` published in
the same release, and checks the archive against it before extracting.

Upstream also publishes `SHA256SUMS.txt.sig`, a raw 64-byte Ed25519 signature
over that checksum file. The corresponding public key does not appear to be
published, so the signature is not verified here. Until it is, the checksum is
only as trustworthy as the release it was downloaded from.

## Build

```
just build
```

Or directly:

```
docker build --target stable -t freenet:stable .
docker build --target dev -t freenet:dev .
```

Select a version with `--build-arg FREENET_VERSION=0.2.123`.

## Run

```
docker run -d --name freenet \
    -v freenet-data:/data \
    -p 31337:31337/udp -p 31337:31337/tcp \
    freenet:stable network \
    --disable-auto-update \
    --network-port 31337
```

See `compose.example.yaml` for a fuller example including resource limits.

## Operating notes

**Set `--network-port` explicitly.** A node started without it binds an
ephemeral UDP port rather than the documented default, and a published port
then forwards nothing.

**Do not publish port 7509.** That is the client API. Upstream documents that
anything able to reach it can read and modify contract state, identities and
keys. It binds to loopback by default; these images do not expose it.

**Auto-update needs a supervisor.** When the node sees a new release it exits
with code 42 and expects something to run `freenet update` before restarting. A
container with a restart policy will instead return on the same version and do
it again. Either pass `--disable-auto-update` and upgrade by changing the image
tag, or supervise it yourself.

**Bound what the node contributes.** `--bandwidth-limit`,
`--total-bandwidth-limit`, `--max-hosting-disk` and `--hosting-disk-pct` exist
because a node will otherwise use what it finds.

**Logs are written to files.** The node writes to
`/data/.local/state/freenet/`, not to stdout, so `docker logs` shows nothing.
Read them from the volume.

**`/data` holds the node identity.** The transport keypair lives there; losing
it means becoming a different node. Back it up.

## Peers and gateways

A gateway needs `--public-network-address` and `--public-network-port`, so it
needs an address others can reach. An ordinary peer does not: nodes behind NAT,
including carrier-grade NAT, join through NAT traversal.

## Development

`nix develop` provides the toolchain, and `just` lists the tasks:

```
just ci             lint and build, the same gates CI runs
just run            start a throwaway node
just logs           follow its log
just peers          how many peers it has reached
just check-release  compare the pinned version against upstream
```

## Licence

MIT, see [LICENSE](LICENSE). Freenet itself is licensed by its own authors.

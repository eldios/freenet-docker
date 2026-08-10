# freenet-docker

Container images for [Freenet](https://freenet.org), built from the official
release binaries with a build you can read.

## Which Freenet

The one in [freenet/freenet-core](https://github.com/freenet/freenet-core): a
peer-to-peer network where applications run on the network itself and are
opened from an ordinary browser.

It is **not** the original Freenet from 2000, which was renamed
[Hyphanet](https://www.hyphanet.org/). The two share a name and nothing else.
Most images on Docker Hub tagged `freenet` are the old Java one, so check
before pulling.

## Why another image

`queeup/freenet-container` tracks upstream releases closely and works. Its
Docker Hub page points at `queeup-containers/freenet-container` as the source,
but that repository is not public, so how the image is assembled cannot be
audited.

For a program that holds your node identity and your keys, that seemed worth
fixing rather than tolerating. Everything here is in one file you can read.

## Images

| Target | Base | For |
|---|---|---|
| `stable` | `scratch` | Running a node. Nothing in the image but the binary, certificates and a passwd entry |
| `dev` | `alpine` | The same binary with a shell, for when something needs looking at from inside |

The Linux release binaries are `static-pie`, so `scratch` needs no libc.

## How the binary is verified

The build downloads the release tarball and `SHA256SUMS.txt` from the same
release, and checks the archive against it before opening it.

Upstream also publishes `SHA256SUMS.txt.sig`, a raw 64-byte Ed25519 signature.
We could not find the matching public key published anywhere, so that signature
cannot currently be verified. Until it is, the checksum is only as trustworthy
as the release page it came from. See the issue linked below.

## Build

```
docker build --target stable -t freenet:stable .
docker build --target dev -t freenet:dev .
```

Pin a different version with `--build-arg FREENET_VERSION=0.2.123`.

## Run

```
docker run -d --name freenet -v freenet-data:/data -p 31337:31337/udp freenet:stable
```

### Things worth knowing before running one

**Do not publish port 7509.** That is the client API. Upstream's own
documentation says anything that can reach it can read and modify contract
state, identities and keys. It binds to loopback by default and should stay
there; this image does not expose it.

**The node asks to be updated by exiting.** When it sees a new release it exits
with code 42 and expects a supervisor to run `freenet update` before
restarting. A container with a restart policy will instead come back on the
same version, see the new release again, and exit again. Either pass
`--disable-auto-update` and upgrade by changing the image tag, or supervise it
yourself.

**Bound what it contributes.** `--bandwidth-limit`, `--total-bandwidth-limit`,
`--max-hosting-disk` and `--hosting-disk-pct` exist for a reason: without them
a node will take what it can get.

**`/data` holds the node identity.** The transport keypair lives there. Back it
up, and understand that losing it means becoming a different node.

**Pass `--network-port` explicitly.** The help text documents a default of
31337, but a node started without the flag binds an ephemeral UDP port
instead, so a published port forwards nothing. Observed on 0.2.123.

**Logs go to files, not stdout.** The node writes to
`/data/.local/state/freenet/freenet.<date>.log` and a matching
`.error.<date>.log`, which means `docker logs` stays empty and a log collector
pointed at the container output sees nothing. Read them from the volume until
this is handled better.

## Does it work behind CGNAT

Yes. Tested on a Starlink line, which is CGNAT, with no port forwarding
possible: the node logged `NAT traversal connection established` and reached
39 peers within five minutes.

This is worth stating because it is not true of every network of this kind. On
I2P the same line can never carry transit traffic, because that role needs
inbound connections. Freenet only needs a reachable address for the gateway
role, which is optional.

## Gateways

A gateway needs `--public-network-address` and `--public-network-port`, so it
needs a reachable address. An ordinary peer does not, which is why a node
behind CGNAT can still take part.

## Licence

The packaging here is MIT. Freenet itself is licensed by its own authors.

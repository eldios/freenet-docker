# syntax=docker/dockerfile:1

# Freenet (the Rust project at freenet.org, not the old Freenet now called
# Hyphanet) packaged from the official release binaries.
#
# Two targets:
#   stable -> scratch, for nodes that just need to run
#   dev    -> alpine, same binary plus a shell for debugging

ARG ALPINE_VERSION=3.24
ARG FREENET_VERSION=0.2.125

FROM alpine:${ALPINE_VERSION} AS fetch

ARG FREENET_VERSION
ARG TARGETARCH

# The checksum is verified through a pipe, and without pipefail a failure in
# grep would be masked by sha256sum's exit status.
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Alpine drops superseded package versions, so pinning them here would make the
# build fail outright rather than drift. Nothing from this stage reaches the
# stable image.
# hadolint ignore=DL3018
RUN apk add --no-cache curl tar

WORKDIR /out

# The checksums come from the release itself and are verified before the
# archive is opened. Upstream also publishes a raw Ed25519 signature over that
# checksum file; it is not verified here because no corresponding public key is
# published. See README.
RUN set -eu; \
	case "${TARGETARCH}" in \
		amd64) arch=x86_64 ;; \
		arm64) arch=aarch64 ;; \
		*) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
	esac; \
	base="https://github.com/freenet/freenet-core/releases/download/v${FREENET_VERSION}"; \
	tarball="freenet-${arch}-unknown-linux-musl.tar.gz"; \
	curl -fsSL -o "${tarball}" "${base}/${tarball}"; \
	curl -fsSL -o SHA256SUMS.txt "${base}/SHA256SUMS.txt"; \
	grep " ${tarball}\$" SHA256SUMS.txt | sha256sum -c -; \
	tar -xzf "${tarball}"; \
	rm -f "${tarball}" SHA256SUMS.txt; \
	chmod 0755 freenet

# The node creates /tmp/freenet at startup and panics if it cannot. A scratch
# image has no /tmp at all, so one is staged here to be copied in and given to
# the runtime user.
RUN mkdir /staged-tmp

# The node stores its transport keypair and contract state under the data
# directory, so it must be a volume: losing it means losing the node identity.
FROM alpine:${ALPINE_VERSION} AS dev

# hadolint ignore=DL3018
RUN apk add --no-cache ca-certificates \
	&& adduser -D -u 1000 -h /data freenet

COPY --from=fetch /out/freenet /usr/local/bin/freenet

USER 1000:1000
WORKDIR /data
VOLUME ["/data"]

# Only the peer-to-peer listener. The client API on 7509 is deliberately not
# exposed: anything that reaches it can read and modify contract state,
# identities and keys, and it binds to loopback by default.
EXPOSE 31337/udp
EXPOSE 31337/tcp

ENTRYPOINT ["/usr/local/bin/freenet"]
CMD ["network"]

FROM scratch AS stable

# The binary is static-pie and needs no libc. Certificates are still copied
# because anything the node fetches over HTTPS would otherwise fail with an
# error that looks like a network problem.
COPY --from=dev /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=dev /etc/passwd /etc/passwd
COPY --from=fetch --chown=1000:1000 /staged-tmp /tmp
COPY --from=fetch /out/freenet /usr/local/bin/freenet

USER 1000:1000
WORKDIR /data
VOLUME ["/data"]

EXPOSE 31337/udp
EXPOSE 31337/tcp

ENTRYPOINT ["/usr/local/bin/freenet"]
CMD ["network"]

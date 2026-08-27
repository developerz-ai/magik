# Magik development container.
#
# TWO RUBIES, ON PURPOSE.
#
#   truffleruby   THE PRODUCTION TARGET. Non-negotiable architecture decision 1
#                 in docs/idea/00-build-spec.md: Magik runs on TruffleRuby, and
#                 its concurrency is REAL PARALLEL OS THREADS — no global lock,
#                 measured rather than assumed by scripts/probes/runtime.rb.
#                 That is precisely why decision 2 is Rack + Puma with a thread
#                 per request, and why there are no forked workers anywhere in
#                 the design: TruffleRuby implements no `fork`.
#                 Anything that only works on CRuby is a bug, and this
#                 container exists so that is discoverable before CI says so.
#
#   cruby         The development default, and what `ruby` resolves to. It boots
#                 in milliseconds where TruffleRuby's JIT needs a warm-up, so the
#                 inner loop (bin/dev, bin/check --only test) is far faster on it.
#                 The gemspec's floor is >= 3.2 for exactly this reason: tooling
#                 and development are supported on CRuby, production is not.
#
# Run the suite on both before you claim a change works:
#
#   bin/check                              # CRuby, the fast answer
#   truffleruby -Ilib -Itest test/...      # TruffleRuby, the real answer
#
# The base image already ships CRuby, rbenv, bundler, git and a non-root
# `vscode` user, so this file only adds TruffleRuby.

ARG RUBY_VERSION=3.2
FROM mcr.microsoft.com/devcontainers/ruby:1-${RUBY_VERSION}-bookworm

# The TruffleRuby standalone release to install. PINNED, and pins go stale:
# check https://github.com/oracle/truffleruby/releases and bump this, or
# override it per-build without editing the file:
#
#   docker build --build-arg TRUFFLERUBY_VERSION=34.0.1 .devcontainer
#
# As of 2026-08-26 this pin IS verified: 34.0.1 was installed and exercised on
# this machine (truffleruby 34.0.1, like ruby 3.4.9, Oracle GraalVM JVM), and
# both scripts/probes/runtime.rb and scripts/probes/pg_concurrency.rb were run
# against it. See docs/architecture/12-runtime-verification.md.
#
# Keep this current. The pin was 24.2.1 until a stale build nearly produced a
# wrong conclusion about the runtime — the probes only tell you the truth about
# the version you actually run them on.
ARG TRUFFLERUBY_VERSION=34.0.1
ARG TARGETARCH=amd64

# Postgres client tools: `psql` against docker/compose.yml, and pg_isready for
# the "is it actually up" step in docker/README.md. No server — the server is a
# container of its own.
RUN apt-get update \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install -y --no-install-recommends \
       postgresql-client \
       redis-tools \
       build-essential \
       libyaml-dev \
       libssl-dev \
       zlib1g-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# TruffleRuby, from the standalone tarball rather than a version manager: one
# download, one directory, no shell hooks, and `truffleruby` on PATH under its
# own name so it can never shadow the CRuby that `ruby` resolves to.
#
# A failed download does NOT fail the build. The container is still a working
# CRuby development environment without it, and a devcontainer that refuses to
# open because of a stale URL is a worse outcome than one that opens and says
# what is missing. The stub left behind exits 69 (EX_UNAVAILABLE) and prints the
# fix — the same "not installed is not broken" distinction bin/check makes.
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) tr_arch=amd64 ;; \
    arm64) tr_arch=aarch64 ;; \
    *)     tr_arch="" ;; \
  esac; \
  url="https://github.com/oracle/truffleruby/releases/download/graal-${TRUFFLERUBY_VERSION}/truffleruby-${TRUFFLERUBY_VERSION}-linux-${tr_arch}.tar.gz"; \
  ok=0; \
  if [ -n "$tr_arch" ] && curl -fsSL --retry 3 -o /tmp/truffleruby.tar.gz "$url"; then \
    mkdir -p /opt/truffleruby; \
    tar -xzf /tmp/truffleruby.tar.gz -C /opt/truffleruby --strip-components=1; \
    rm -f /tmp/truffleruby.tar.gz; \
    /opt/truffleruby/lib/truffle/post_install_hook.sh || true; \
    ln -sf /opt/truffleruby/bin/truffleruby /usr/local/bin/truffleruby; \
    ln -sf /opt/truffleruby/bin/gem /usr/local/bin/truffleruby-gem; \
    ln -sf /opt/truffleruby/bin/bundle /usr/local/bin/truffleruby-bundle; \
    ok=1; \
  fi; \
  if [ "$ok" = "0" ]; then \
    printf '%s\n' \
      '#!/bin/sh' \
      'echo "MAGIK_NO_TRUFFLERUBY: TruffleRuby was not installed when this image was built." >&2' \
      'echo "  cause: the pinned release tarball could not be downloaded (stale pin, no network, or an unsupported CPU architecture)." >&2' \
      'echo "  fix:   rebuild with a current version —" >&2' \
      'echo "         docker build --build-arg TRUFFLERUBY_VERSION=<x.y.z> .devcontainer" >&2' \
      'echo "         releases: https://github.com/oracle/truffleruby/releases" >&2' \
      'exit 69' \
      > /usr/local/bin/truffleruby; \
    chmod +x /usr/local/bin/truffleruby; \
  fi; \
  truffleruby --version || true

# `ruby` is CRuby. `truffleruby` is TruffleRuby. Neither is hidden behind the
# other, and no shell hook decides which you get.
RUN ruby --version && echo "cruby is on PATH as \`ruby\`; truffleruby is on PATH as \`truffleruby\`"

# Build script and system files: needed only during the build, they don't end up in the image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY cosign.pub /cosign.pub

# Base: Universal Blue base-main with the Fedora version pinned (updated by hand)
FROM ghcr.io/ublue-os/base-main:45

# All changes live in build_files/build.sh and in system_files/
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Final check of the image
RUN bootc container lint

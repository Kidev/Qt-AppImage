FROM ubuntu:24.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    squashfs-tools \
    file \
    wget \
    patchelf \
    imagemagick \
    tar \
    gzip \
    kmod \
    fuse \
    && rm -rf /var/lib/apt/lists/*

# Download appimagetool
RUN wget -O /usr/local/bin/appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage && \
    chmod +x /usr/local/bin/appimagetool

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

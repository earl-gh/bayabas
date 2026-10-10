# Kalyeah dedicated game server (headless Godot, WebSocket on $PORT).
# Build:  docker build -t kalyeah-server .
# Run:    docker run -p 8080:8080 kalyeah-server
FROM ubuntu:24.04

ARG GODOT_VERSION=4.6.2
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates wget unzip libfontconfig1 \
    && rm -rf /var/lib/apt/lists/* \
    && wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -O /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

WORKDIR /app
COPY . .
# Builds the import cache once so the server starts fast.
RUN godot --headless --import || true

ENV PORT=8080
EXPOSE 8080
# The title scene sees --server and switches to server/main.tscn.
CMD ["godot", "--headless", "--", "--server"]

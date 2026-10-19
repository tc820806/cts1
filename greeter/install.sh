#!/bin/bash
# Run as root: copy the greeter to /usr/local/share/cts1-greeter (or $1), where greetd's user can read it, and the
# sync units to /usr/local/lib/systemd/system (not enabled). Touches neither /etc/greetd nor the display manager.
set -eu

src=$(cd "$(dirname "$0")" && pwd)
dest=${1:-/usr/local/share/cts1-greeter}

if [ "$(id -u)" -ne 0 ]; then
    echo "install: run as root (sudo $0)" >&2
    exit 1
fi

tmp=$(mktemp -d "${dest%/*}/.cts1-greeter.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cp -r "$src"/. "$tmp"/
rm -rf "$tmp/install.sh" "$tmp/systemd"
chown -R root:root "$tmp"
find "$tmp" -type d -exec chmod 755 {} +
find "$tmp" -type f -exec chmod 644 {} +
chmod 755 "$tmp/sync.sh" "$tmp/start.sh"

rm -rf "$dest"
mv "$tmp" "$dest"
trap - EXIT
install -d /usr/local/lib/systemd/system
install -m 644 "$src"/systemd/cts1-greeter-sync@.path "$src"/systemd/cts1-greeter-sync@.service /usr/local/lib/systemd/system/
systemctl daemon-reload
echo "install: greeter installed to $dest, sync units to /usr/local/lib/systemd/system (not enabled)"

#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config/repo.env"
REPO_DIR="$ROOT_DIR/repo/repo"
SITE_DIR="$ROOT_DIR/site"

source "$CONFIG_FILE"

UM_REPO_DIR="$ROOT_DIR/repo/ultramarine"
UB_REPO_DIR="$ROOT_DIR/repo/ubuntu"
OS_REPO_DIR="$ROOT_DIR/repo/opensuse"

rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR/repo"
cp -r "$REPO_DIR"/. "$SITE_DIR/repo/"

um_section=""
ub_section=""
os_section=""

if [ -d "$UM_REPO_DIR" ] && ls "$UM_REPO_DIR"/*.rpm &>/dev/null; then
    mkdir -p "$SITE_DIR/repo/ultramarine"
    cp -r "$UM_REPO_DIR"/. "$SITE_DIR/repo/ultramarine/"
    um_section=$(cat <<EOF

  <h2>Ultramarine / Fedora (dnf)</h2>
  <p>Repo URL: <a href="$PAGES_BASE_URL/repo/ultramarine/">$PAGES_BASE_URL/repo/ultramarine/</a></p>
EOF
)
fi

if [ -d "$UB_REPO_DIR" ] && ls "$UB_REPO_DIR"/*.deb &>/dev/null; then
    mkdir -p "$SITE_DIR/repo/ubuntu"
    cp -r "$UB_REPO_DIR"/. "$SITE_DIR/repo/ubuntu/"
    ub_section=$(cat <<EOF

  <h2>Ubuntu (apt)</h2>
  <p>Repo URL: <a href="$PAGES_BASE_URL/repo/ubuntu/">$PAGES_BASE_URL/repo/ubuntu/</a></p>
EOF
)
fi

if [ -d "$OS_REPO_DIR" ] && ls "$OS_REPO_DIR"/*.rpm &>/dev/null; then
    mkdir -p "$SITE_DIR/repo/opensuse"
    cp -r "$OS_REPO_DIR"/. "$SITE_DIR/repo/opensuse/"
    os_section=$(cat <<EOF

  <h2>openSUSE (zypper)</h2>
  <p>Repo URL: <a href="$PAGES_BASE_URL/repo/opensuse/">$PAGES_BASE_URL/repo/opensuse/</a></p>
EOF
)
fi

cat > "$SITE_DIR/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$REPO_NAME</title>
</head>
<body>
  <h1>$REPO_NAME</h1>
  <p>Package repository for the Lenovo Yoga Tab Plus (TB520FU).</p>
  <p>Project site: <a href="https://lenovo-yoga-tab-plus.github.io/lapis/">https://lenovo-yoga-tab-plus.github.io/lapis/</a></p>
  <h2>Arch Linux (pacman)</h2>
  <p>Repo URL: <a href="$PAGES_BASE_URL/repo/">$PAGES_BASE_URL/repo/</a></p>${um_section}${ub_section}${os_section}
  <p>Image builder: endeavouros-lapis</p>
</body>
</html>
EOF

python "$ROOT_DIR/scripts/write_repo_index.py" "$SITE_DIR/repo"

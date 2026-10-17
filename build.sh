#!/bin/sh
# Wrap an official OpenLogi release into an AppImage. Nothing is recompiled:
# the binaries come unchanged from the upstream .deb.
#
#   ./build.sh v0.8.14            -> out/OpenLogi-0.8.14-x86_64.AppImage (+ .zsync)
#
# Env: UPDATE_REPO (owner/repo the AppImage updates from; default from git remote)
set -eu

TAG="${1:?usage: build.sh <upstream tag, e.g. v0.8.14>}"
VERSION="${TAG#v}"
ARCH=x86_64
DEB_ARCH=amd64
UPSTREAM=AprilNEA/OpenLogi
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/work"
OUT="$ROOT/out"
APPDIR="$WORK/OpenLogi.AppDir"

if [ -z "${UPDATE_REPO:-}" ]; then
  UPDATE_REPO="$(git -C "$ROOT" remote get-url origin 2>/dev/null \
    | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')" || true
fi

rm -rf "$WORK" && mkdir -p "$WORK" "$OUT"
cd "$WORK"

echo ">> Downloading OpenLogi $TAG"
curl -fsSL -o openlogi.deb \
  "https://github.com/$UPSTREAM/releases/download/$TAG/openlogi-$TAG-linux-$DEB_ARCH.deb"

echo ">> Building AppDir"
mkdir -p "$APPDIR"
dpkg-deb -x openlogi.deb "$APPDIR"

# Keep the device rules inside the image for "setup"; drop files that only
# make sense for a system package.
mkdir -p "$APPDIR/usr/lib/openlogi"
mv "$APPDIR/etc/udev/rules.d/70-openlogi.rules" "$APPDIR/usr/lib/openlogi/"
rm -rf "$APPDIR/etc" "$APPDIR/usr/lib/systemd"

install -m 755 "$ROOT/appimage/AppRun" "$APPDIR/AppRun"
install -m 755 "$ROOT/appimage/openlogi-appimage-setup" "$APPDIR/usr/bin/"

sed -e "/^\[Desktop Entry\]/a X-AppImage-Version=$VERSION" \
  "$APPDIR/usr/share/applications/openlogi.desktop" > "$APPDIR/openlogi.desktop"
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/openlogi.png" "$APPDIR/openlogi.png"
ln -sf openlogi.png "$APPDIR/.DirIcon"

echo ">> Packing AppImage"
TOOL="$WORK/appimagetool"
curl -fsSL -o "$TOOL" \
  "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
chmod +x "$TOOL"

NAME="OpenLogi-$VERSION-$ARCH.AppImage"
set --
if [ -n "${UPDATE_REPO:-}" ]; then
  owner="${UPDATE_REPO%%/*}"; repo="${UPDATE_REPO#*/}"
  set -- -u "gh-releases-zsync|$owner|$repo|latest|OpenLogi-*-$ARCH.AppImage.zsync"
fi
cd "$OUT"
ARCH=$ARCH APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream "$@" "$APPDIR" "$NAME"

echo ">> Built $OUT/$NAME"

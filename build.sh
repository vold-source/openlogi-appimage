#!/bin/sh
# =============================================================================
# build.sh: turn an official OpenLogi release into an AppImage
# =============================================================================
#
# Nothing is compiled or changed. The script:
#   1. downloads OpenLogi's official .deb package for the requested version,
#   2. unpacks it into a folder (an "AppDir", the AppImage's contents),
#   3. adds the two small scripts from this repo (AppRun and the setup script),
#      the app's icon and its menu entry,
#   4. packs the folder into a single .AppImage file with appimagetool, the
#      standard tool from the AppImage project.
#
# Usage:
#   ./build.sh v0.8.14     -> out/OpenLogi-0.8.14-x86_64.AppImage (+ .zsync)
#   ./build.sh v0.8.14 1   -> out/OpenLogi-0.8.14.1-x86_64.AppImage
#
# The optional second number is a "packaging revision": a fix to this repo's
# packaging while OpenLogi itself stays the same. It becomes a fourth version
# number, because AppImage managers such as AppManager only offer an update
# when the version number goes up.
#
# Why the .deb and not the .rpm? Both contain byte-for-byte identical program
# files. The GitHub build machines run Ubuntu, which can unpack a .deb with
# built-in tools (dpkg-deb), so no extra software has to be installed.
#
# Optional setting: UPDATE_REPO=owner/repo tells the AppImage where to look for
# updates. Without it, it's taken from this git checkout's GitHub address.
# =============================================================================

# Stop at the first error (-e) and treat unset variables as errors (-u).
set -eu

# --- Inputs ------------------------------------------------------------------
TAG="${1:?usage: build.sh <upstream tag, e.g. v0.8.14> [packaging revision]}"
REVISION="${2:-0}"                  # 0 = first build of this OpenLogi version
VERSION="${TAG#v}"                  # "v0.8.14" -> "0.8.14"
if [ "$REVISION" != 0 ]; then VERSION="$VERSION.$REVISION"; fi   # -> "0.8.14.1"

# --- Fixed settings ----------------------------------------------------------
ARCH=x86_64                         # AppImage name for 64-bit Intel/AMD
DEB_ARCH=amd64                      # the same thing, as OpenLogi names its .deb
UPSTREAM=AprilNEA/OpenLogi          # OpenLogi's official GitHub repository
ROOT="$(cd "$(dirname "$0")" && pwd)"   # this repository's folder
WORK="$ROOT/work"                   # scratch folder, wiped on every build
OUT="$ROOT/out"                     # finished AppImages end up here
APPDIR="$WORK/OpenLogi.AppDir"      # the folder that becomes the AppImage

# Work out which GitHub repo updates come from, e.g. "vold-source/openlogi-appimage".
if [ -z "${UPDATE_REPO:-}" ]; then
  UPDATE_REPO="$(git -C "$ROOT" remote get-url origin 2>/dev/null \
    | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')" || true
fi

# Start from a clean scratch folder.
rm -rf "$WORK" && mkdir -p "$WORK" "$OUT"
cd "$WORK"

# --- 1. Download the official package ----------------------------------------
echo ">> Downloading OpenLogi $TAG"
curl -fsSL -o openlogi.deb \
  "https://github.com/$UPSTREAM/releases/download/$TAG/openlogi-$TAG-linux-$DEB_ARCH.deb"

# --- 2. Unpack it -------------------------------------------------------------
echo ">> Building AppDir"
mkdir -p "$APPDIR"
dpkg-deb -x openlogi.deb "$APPDIR"    # unpacks only the files, runs nothing

# --- 3. Rearrange and add our files -------------------------------------------
# The device rules file is kept inside the AppImage so "setup" can copy it to
# /etc later. The package's system-wide autostart file is removed, because an
# AppImage can't install system files; "setup" writes its own instead.
mkdir -p "$APPDIR/usr/lib/openlogi"
mv "$APPDIR/etc/udev/rules.d/70-openlogi.rules" "$APPDIR/usr/lib/openlogi/"
rm -rf "$APPDIR/etc" "$APPDIR/usr/lib/systemd"

# Add this repo's two scripts (install -m 755 = copy and make runnable).
install -m 755 "$ROOT/appimage/AppRun" "$APPDIR/AppRun"
install -m 755 "$ROOT/appimage/openlogi-appimage-setup" "$APPDIR/usr/bin/"

# An AppImage needs its menu entry (.desktop file) and icon at the top level.
# The menu entry is OpenLogi's own, with one added line saying the version.
sed -e "/^\[Desktop Entry\]/a X-AppImage-Version=$VERSION" \
  "$APPDIR/usr/share/applications/openlogi.desktop" > "$APPDIR/openlogi.desktop"
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/openlogi.png" "$APPDIR/openlogi.png"
ln -sf openlogi.png "$APPDIR/.DirIcon"   # icon file managers show for the AppImage

# --- 4. Pack it into an AppImage ----------------------------------------------
echo ">> Packing AppImage"
TOOL="$WORK/appimagetool"
curl -fsSL -o "$TOOL" \
  "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
chmod +x "$TOOL"

NAME="OpenLogi-$VERSION-$ARCH.AppImage"

# Embed the "update information": a short note inside the AppImage telling
# AppImage managers to check the latest release of this GitHub repo for a file
# matching OpenLogi-*-x86_64.AppImage.zsync. appimagetool also creates that
# .zsync file; it lets managers download only the parts that changed.
set --
if [ -n "${UPDATE_REPO:-}" ]; then
  owner="${UPDATE_REPO%%/*}"; repo="${UPDATE_REPO#*/}"
  set -- -u "gh-releases-zsync|$owner|$repo|latest|OpenLogi-*-$ARCH.AppImage.zsync"
fi

cd "$OUT"
# APPIMAGE_EXTRACT_AND_RUN=1 lets appimagetool (itself an AppImage) run on
# build machines without FUSE. --no-appstream skips an optional app-store
# metadata check that OpenLogi doesn't provide data for.
ARCH=$ARCH APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream "$@" "$APPDIR" "$NAME"

echo ">> Built $OUT/$NAME"

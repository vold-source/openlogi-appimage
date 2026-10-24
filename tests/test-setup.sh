#!/bin/sh
# =============================================================================
# test-setup.sh: automatic safety test for "setup" and "remove"
# =============================================================================
#
# Runs appimage/openlogi-appimage-setup many times in a throwaway folder and
# checks that it does exactly what it should:
#   - setup installs the device rules and the autostart file,
#   - remove takes everything away again,
#   - running either one twice does no harm,
#   - files that setup didn't create are never replaced or deleted,
#   - nothing is left behind when the password prompt is cancelled.
#
# It is safe to run on any computer. It never touches the real /etc, your real
# home folder or your real services: the password prompt (pkexec), the device
# tool (udevadm) and the service tool (systemctl) are replaced by harmless
# stand-ins that only write down what they were asked to do.
#
# Run it with:   sh tests/test-setup.sh
# It prints PASS or FAIL for each check and ends with a summary.
# Origin: written for this repository.
# =============================================================================

set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/appimage/openlogi-appimage-setup"

# Safety catch: never run as the administrator (root). As a normal user, the
# test can't change the real system even if something goes wrong.
if [ "$(id -u)" = 0 ]; then
  echo "Stopped: don't run this test as root (or with sudo)." >&2
  exit 1
fi

# Everything happens in this throwaway folder, which is deleted at the end.
T="$(mktemp -d)" || exit 1
# Safety catch: stop unless the throwaway folder really exists, so the clean-up
# below can never point at a real folder.
[ -n "$T" ] && [ -d "$T" ] || { echo "Stopped: couldn't create a temporary folder." >&2; exit 1; }
trap 'rm -rf "$T"' EXIT

FAILS=0
check() {   # check "description" command...
  desc="$1"; shift
  if "$@"; then echo "PASS  $desc"; else echo "FAIL  $desc"; FAILS=$((FAILS + 1)); fi
}
no() { ! "$@"; }

# --- Stand-ins for the system tools ------------------------------------------
mkdir -p "$T/stub"
cat > "$T/stub/systemctl" <<EOF
#!/bin/sh
echo "systemctl \$*" >> "$T/log"
EOF
cat > "$T/stub/udevadm" <<EOF
#!/bin/sh
echo "udevadm \$*" >> "$T/log"
EOF
# The password prompt: runs the command (without real admin rights), unless
# the test file "$T/cancel" exists, which acts like pressing Cancel. As a
# safety catch it refuses any command that isn't aimed at the throwaway folder.
cat > "$T/stub/pkexec" <<EOF
#!/bin/sh
echo "pkexec" >> "$T/log"
[ -e "$T/cancel" ] && exit 126
case "\$*" in
  *"$T/root/"*) exec "\$@" ;;
  *) echo "test pkexec: refused a command outside the test folder: \$*" >&2; exit 99 ;;
esac
EOF
chmod +x "$T/stub/"*
[ -x "$T/stub/pkexec" ] || { echo "Stopped: couldn't create the stand-in tools." >&2; exit 1; }

# --- A pretend unpacked AppImage ---------------------------------------------
# make_app NAME RULES-TEXT: builds a fake AppImage folder with this setup script
# and a rules file with the given content (so we can pretend OpenLogi updated
# its rules).
make_app() {
  mkdir -p "$T/$1/usr/bin" "$T/$1/usr/lib/openlogi"
  cp "$SCRIPT" "$T/$1/usr/bin/openlogi-appimage-setup"
  printf '%s\n' "$2" > "$T/$1/usr/lib/openlogi/70-openlogi.rules"
}
make_app app1 "# OpenLogi udev rules (version 1)"
make_app app2 "# OpenLogi udev rules (version 2)"

ROOT="$T/root"                                     # pretend system root
RULES="$ROOT/etc/udev/rules.d/70-openlogi.rules"
H="$T/home"                                        # pretend home folder
UNIT="$H/.local/share/systemd/user/openlogi-agent.service"
OLD_UNIT="$H/.config/systemd/user/openlogi-agent.service"
RECORD="$H/.local/share/openlogi-appimage/installed-70-openlogi.rules"

# run APP setup|remove: runs the script from that fake AppImage, with a clean
# environment that points only at the throwaway folder.
run() {
  : > "$T/log"
  mkdir -p "$T/tmp"
  sub=install; [ "$2" = remove ] && sub=remove
  env -i PATH="$T/stub:/usr/bin:/bin" HOME="$H" TMPDIR="$T/tmp" \
    APPIMAGE="${APPIMAGE_PATH-/apps/OpenLogi}" \
    OPENLOGI_SETUP_TEST_ROOT="$ROOT" \
    sh "$T/$1/usr/bin/openlogi-appimage-setup" "$sub" > "$T/out" 2>&1
}
reset() { rm -rf "$ROOT" "$H" "$T/tmp" "$T/cancel"; mkdir -p "$ROOT/etc/udev/rules.d" "$H"; }
same() { cmp -s "$1" "$2"; }
logged() { grep -q -- "$1" "$T/log"; }
empty_dir() { [ -z "$(ls -A "$1" 2>/dev/null)" ]; }

# =============================================================================
echo "--- Fresh setup"
reset
run app1 setup; rc=$?
check "setup succeeds" [ $rc = 0 ]
check "rules file installed" same "$RULES" "$T/app1/usr/lib/openlogi/70-openlogi.rules"
check "autostart file written" grep -q 'Written by the OpenLogi AppImage setup' "$UNIT"
check "autostart starts the AppImage" grep -q '^ExecStart="/apps/OpenLogi" agent$' "$UNIT"
check "autostart switched on" logged "enable openlogi-agent.service"
check "copy of installed rules kept" same "$RECORD" "$RULES"
check "no temporary file left" empty_dir "$T/tmp"

echo "--- Setup a second time"
run app1 setup; rc=$?
check "second setup succeeds" [ $rc = 0 ]
check "no password asked when rules are already there" no logged pkexec
check "rules file unchanged" same "$RULES" "$T/app1/usr/lib/openlogi/70-openlogi.rules"
check "autostart file still ours" grep -q 'Written by the OpenLogi AppImage setup' "$UNIT"

echo "--- Remove"
run app1 remove; rc=$?
check "remove succeeds" [ $rc = 0 ]
check "rules file deleted" [ ! -e "$RULES" ]
check "autostart file deleted" [ ! -e "$UNIT" ]
check "autostart switched off" logged "disable --now openlogi-agent.service"
check "device permissions refreshed (hidraw)" logged "trigger --subsystem-match=hidraw"
check "device permissions refreshed (uinput)" logged "name=uinput"
check "kept copy deleted" [ ! -e "$H/.local/share/openlogi-appimage" ]
check "remove explains how to uninstall" grep -q 'Launch at login' "$T/out"

echo "--- Remove a second time"
run app1 remove; rc=$?
check "second remove succeeds" [ $rc = 0 ]
check "no password asked when nothing is left" no logged pkexec

# =============================================================================
echo "--- Someone else's rules file is in the way"
reset
echo "# my own rules" > "$RULES"
run app1 setup; rc=$?
check "setup stops" [ $rc != 0 ]
check "their rules file untouched" grep -qx '# my own rules' "$RULES"
check "no autostart file written" [ ! -e "$UNIT" ]
check "no password asked" no logged pkexec
run app1 remove
check "remove leaves their rules file alone" grep -qx '# my own rules' "$RULES"

echo "--- Someone else's autostart file is in the way"
reset
mkdir -p "$(dirname "$UNIT")"; printf '[Service]\nExecStart=/usr/bin/true\n' > "$UNIT"
run app1 setup; rc=$?
check "setup stops" [ $rc != 0 ]
check "no rules file installed" [ ! -e "$RULES" ]
check "their autostart file untouched" grep -q '^ExecStart=/usr/bin/true$' "$UNIT"
run app1 remove
check "remove leaves their autostart file alone" grep -q '^ExecStart=/usr/bin/true$' "$UNIT"
check "remove doesn't switch their service off" no logged "disable"

echo "--- Someone else's autostart file in ~/.config, none of ours"
reset
mkdir -p "$(dirname "$OLD_UNIT")"; printf '[Service]\nExecStart=/usr/bin/true\n' > "$OLD_UNIT"
run app1 remove; rc=$?
check "remove succeeds" [ $rc = 0 ]
check "their file untouched" grep -q '^ExecStart=/usr/bin/true$' "$OLD_UNIT"
check "remove doesn't switch their service off" no logged "disable"

echo "--- OpenLogi's own throwaway autostart file is replaced"
reset
mkdir -p "$(dirname "$UNIT")"; printf '[Service]\nExecStart=/tmp/.mount_abc/usr/bin/openlogi-agent\n' > "$UNIT"
run app1 setup; rc=$?
check "setup succeeds" [ $rc = 0 ]
check "replaced by ours" grep -q 'Written by the OpenLogi AppImage setup' "$UNIT"

echo "--- Autostart file from the very first version of setup"
reset
mkdir -p "$(dirname "$OLD_UNIT")"; echo "# Written by the OpenLogi AppImage setup" > "$OLD_UNIT"
run app1 setup
check "our old file is cleaned up" [ ! -e "$OLD_UNIT" ]
reset
mkdir -p "$(dirname "$OLD_UNIT")"; echo "# someone else's" > "$OLD_UNIT"
run app1 setup
check "someone else's file there is left alone" [ -e "$OLD_UNIT" ]

# =============================================================================
echo "--- OpenLogi changes its rules in an update"
reset
run app1 setup
run app2 setup; rc=$?
check "setup with the new version succeeds" [ $rc = 0 ]
check "rules file updated to the new version" same "$RULES" "$T/app2/usr/lib/openlogi/70-openlogi.rules"
check "kept copy updated too" same "$RECORD" "$RULES"
reset
run app1 setup
run app2 remove; rc=$?
check "remove from the new version succeeds" [ $rc = 0 ]
check "it still deletes the old rules file" [ ! -e "$RULES" ]

# =============================================================================
echo "--- Password prompt cancelled"
reset
touch "$T/cancel"
run app1 setup; rc=$?
check "setup stops" [ $rc != 0 ]
check "no rules file installed" [ ! -e "$RULES" ]
check "no autostart file written" [ ! -e "$UNIT" ]
check "no temporary file left" empty_dir "$T/tmp"
rm "$T/cancel"; run app1 setup
touch "$T/cancel"
run app1 remove; rc=$?
check "remove stops" [ $rc != 0 ]
check "rules file still there" [ -e "$RULES" ]
check "kept copy still there, so remove can be retried" [ -e "$RECORD" ]
rm "$T/cancel"; run app1 remove; rc=$?
check "retried remove succeeds" [ $rc = 0 ]
check "rules file deleted" [ ! -e "$RULES" ]

echo "--- Started without the AppImage"
reset
APPIMAGE_PATH="" run app1 setup; rc=$?
check "setup refuses" [ $rc != 0 ]
check "nothing installed" [ ! -e "$RULES" ]

echo "--- AppImage in a folder with a space in its name"
reset
APPIMAGE_PATH="/my apps/OpenLogi" run app1 setup
check "start command quoted correctly" grep -q '^ExecStart="/my apps/OpenLogi" agent$' "$UNIT"

# =============================================================================
echo
if [ "$FAILS" = 0 ]; then echo "All checks passed."; else echo "$FAILS check(s) FAILED."; exit 1; fi

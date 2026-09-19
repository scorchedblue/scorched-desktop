#!/usr/bin/bash
#
# Run qmllint over the QML files that are eligible for it.
#
# Takes file names relative to quickshell/. The list lives in the justfile and
# is explicit on purpose -- see the comment on the `qmllint` recipe there.
#
# Three things have to be true before qmllint can read this shell at all, and
# this script arranges the first two (AGENTS.md has the measurements):
#
#   1. Quickshell's own `qmldir` and `.qmltypes` on the import path. They come
#      from the container built by .ci/Containerfile; without them all six
#      Quickshell imports fail and every later warning is cascade.
#   2. A `qmldir` for this repository's 14 `pragma Singleton` files. Without it
#      they resolve as types but not as members, and every `Popouts.toggle`
#      reads as a missing property.
#   3. `pragma ComponentBehavior: Bound` on the file being linted. That one is
#      a source change with runtime consequences, so it is in the files
#      themselves rather than here.
#
# The qmldir in (2) is generated into a scratch copy rather than committed to
# quickshell/. That directory is rsynced to ~/.config/quickshell/ verbatim by
# `just sync`, and Quickshell resolves `pragma Singleton` without a qmldir of
# its own -- adding one would put a file the shell has never run with into the
# live config to satisfy a linter. Generating it also means a new singleton is
# picked up by having been written, not by someone remembering to list it.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="scorched-qmllint:local"

if [ "$#" -eq 0 ]; then
    echo "usage: ${0##*/} <file.qml> [...]   (names relative to quickshell/)" >&2
    exit 2
fi

if ! command -v podman >/dev/null 2>&1; then
    echo "podman is required: qmllint ships in qt6-qtdeclarative-devel, which" >&2
    echo "neither the ScorchedBlue image nor a stock CI runner carries." >&2
    exit 1
fi

# Cached to a layer locally, a genuine build on a fresh runner. Kept in the
# script rather than the recipe so the control below cannot run against a
# different image than the check did.
podman build -f "$repo_root/.ci/Containerfile" -t "$image" "$repo_root"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

prepare() {
    local dest="$1"
    mkdir -p "$dest"
    cp "$repo_root"/quickshell/*.qml "$dest/"
    # Anywhere in the file, not just line 1: a pragma may sit below a header
    # comment, as `ComponentBehavior` does in Bar.qml. A comment cannot match
    # this pattern, because a QML comment starts with `//`.
    for f in "$dest"/*.qml; do
        if grep -q '^pragma Singleton$' "$f"; then
            printf 'singleton %s 1.0 %s\n' "$(basename "$f" .qml)" "$(basename "$f")"
        fi
    done | sort >"$dest/qmldir"
}

# A bind mount into a container needs relabelling where SELinux is enforcing,
# which is everywhere this runs locally, and `Z` is the private label because
# the source is a scratch directory nothing else reads. The CI runner is Ubuntu
# with no SELinux at all, where podman's handling of the flag is not something
# to depend on -- so ask the kernel rather than pass it blind.
mount_opts="ro"
if [ -d /sys/fs/selinux ]; then
    mount_opts="ro,Z"
fi

# `--missing-property error` is the point of the exercise: that is the class
# that catches a call to an API that no longer exists, which is what reached
# main green in #12 and #13. Everything else keeps its default level, so it
# prints without failing -- the surviving `Loader.item.x` and `parent.x`
# warnings are duck-typed deliberately and are a separate decision.
lint() {
    podman run --rm -v "$1:/src:$mount_opts" "$image" \
        -I /usr/lib64/qt6/qml \
        --missing-property error \
        "${@:2}"
}

prepare "$work/check"
echo "qmllint: $* ($(grep -c . "$work/check/qmldir") singletons declared)"
lint "$work/check" "$@"
echo "ok: qmllint found no missing property in $*"

# The control. A lint that cannot fail is worth nothing, and this repository
# keeps finding checks that could not. Inject the #12/#13 defect -- a member
# that does not exist, read through `root` from inside a nested Component --
# and require qmllint to reject it.
#
# The injection site is deliberate: inside a Component, which is precisely
# where the defect hid. Without `pragma ComponentBehavior: Bound` qmllint
# cannot resolve `root` to a type there, reports a bare `unqualified` warning
# instead, and this control fails -- so it also pins requirement (3).
prepare "$work/control"
sed -i '/Popouts\.toggle("calendar"/ s/root\.modelData/root.qmllintControlNoSuchMember/' \
    "$work/control/Bar.qml"
if ! grep -q 'root\.qmllintControlNoSuchMember' "$work/control/Bar.qml"; then
    echo "control failed: could not inject a bogus member into Bar.qml" >&2
    echo "the anchor this script seds on has moved; fix the sed, not this check" >&2
    exit 1
fi

control_out="$work/control.log"
if lint "$work/control" Bar.qml >"$control_out" 2>&1; then
    echo "control failed: qmllint accepted a member that does not exist" >&2
    sed -n '1,40p' "$control_out" >&2
    exit 1
fi
if ! grep -q 'missing-property' "$control_out"; then
    echo "control failed: qmllint rejected the bogus member, but not as" >&2
    echo "missing-property -- the rule this check exists for did not fire." >&2
    sed -n '1,40p' "$control_out" >&2
    exit 1
fi
echo "ok: control rejected a member that does not exist [missing-property]"

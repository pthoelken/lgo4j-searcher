#!/bin/bash -e

# Thanks to @becker-rzht for your assistance in this case!

tmpdir=$(mktemp -d)
cd "$tmpdir"

cleaner() {
    echo "* Removing $tmpdir"
    rm -rf "${tmpdir:-does-not-exist}"
}

trap cleaner INT TERM EXIT

detector="https://github.com/beckerr-rzht/log4j-detector/raw/release/log4j-detector-2021.12.29.jar"

echo -n "* Downloading detector ... "
wget -q "$detector" && echo OK

java=$(find . -name java -type f -executable| head -1)
if [ -z "$java" ]; then
    echo "java not found" >&2
    exit 1
fi

find_opt=(
    /
    \( -type d \( -fstype autofs -o -fstype fuse.sshfs -o -fstype nfs -o -fstype proc -o -fstype sshfs -o -fstype sysfs -o -fstype tmpfs \) -prune -o -type f \)  
    -not -path  \*/.snapshots/\*
    -not -path  \*/.m2/repo/\*
    -type f -print
)

echo "* Scanning using $java and ${detector##*/}:"

warn=()
while read line; do

    case "$line" in
    "-- Problem"*" encrypted "*) ;;         # HIDE
    "-- Problem"*".zip.ZipException"*) ;;   # HIDE
    "-- Problem"*".io.EOFException"*) ;;    # HIDE
    "-- Problem"*"no magic number"*) ;;     # HIDE
    "-- Problem"*"not find ZIP magic"*);;   # HIDE
    "-- Problem"*"malformed") ;;            # HIDE
    "-- Problem"*"invalid distance"*) ;;    # HIDE
    "-- Problem"*) echo "  ${line#-}";;     # SHOW (unknown problems)
    "-- "*);;                               # HIDE
    *" _POTENTIALLY_SAFE_"*);;              # HIDE
    *" _OLD_");;                            # HIDE (for the moment)
    *) echo "  - $line" ;;                  # SHOW (the rest)
    esac
done < <(find "${find_opt[@]}" | "$java" -jar ${detector##*/} --stdin 2>&1 || true)
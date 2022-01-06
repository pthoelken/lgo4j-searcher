#!/bin/bash -e

# Original from @becker-rzht
# Edited from @pthoelken


strTempDir=$(mktemp -d)
strDate=$(date '+%d-%m-%Y_%H-%M-%S')
strLogDirectory=~/log4j-log
strLogUnparsed=$strLogDirectory/log4j-$strDate-$HOSTNAME-$USER-unparsed.log
strLogParsed=$strLogDirectory/log4j-$strDate-$HOSTNAME-$USER-parsed.log

objDetector="https://github.com/beckerr-rzht/log4j-detector/raw/release/log4j-detector-2021.12.29.jar"
objJava=$(find . -name java -type f -executable| head -1)

cd "$strTempDir"

cleaner() {
    echo "* Removing $strTempDir"
    rm -rf "${strTempDir:-does-not-exist}"
}
trap cleaner INT TERM EXIT

if [ ! -d $strLogDirectory ]; then
    mkdir -p $strLogDirectory
fi

function CheckApplication() {
    if ! hash $1 2>/dev/null; then
        EventError "Software $1 is not installed. Please be sure, that $1 is installed before running this script! Abort."
        exit 1
    fi
}

function DownloadJava() {
    m="$(dpkg --print-architecture 2>/dev/null || uname -m)"
    case "$m" in
        armsf) jre="https://cdn.azul.com/zulu-embedded/bin/zulu11.52.13-ca-jdk11.0.13-linux_aarch32sf.tar.gz" ;; # RPI
        armhf) jre="https://cdn.azul.com/zulu-embedded/bin/zulu11.52.13-ca-jdk11.0.13-linux_aarch32hf.tar.gz" ;; # RPI
        *64)   jre="https://cdn.azul.com/zulu/bin/zulu11.52.13-ca-jre11.0.13-linux_x64.tar.gz" ;; # 64 Bit
        i?86)  jre="https://cdn.azul.com/zulu/bin/zulu11.52.13-ca-jre11.0.13-linux_i686.tar.gz" ;; # 32 Bit
        *)     echo "ERROR: No java for $m" 2>&1; exit 1
    esac

    echo -n "* Downloading: jre ... "
    wget -qO - "$jre" | tar xzf - && echo OK
}

function DownloadLatestDetector() {
    echo -n "* Downloading: log4j-detector latest version ... "
    wget -q "$objDetector" && echo OK
}

if [ -z "$objJava" ]; then
    echo "* Error: Java not found" >&2
    exit 1
fi

function Scanning() {
    find_opt=(
    /
    \( -type d \( -fstype autofs -o -fstype fuse.sshfs -o -fstype nfs -o -fstype proc -o -fstype sshfs -o -fstype sysfs -o -fstype tmpfs \) -prune -o -type f \)  
    -not -path  \*/.snapshots/\*
    -not -path  \*/.m2/repo/\*
    -type f -print
    )

    echo "* Scanning using $objJava and ${objDetector##*/}:"

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
    done < <(find "${find_opt[@]}" | "$objJava" -jar ${objDetector##*/} --stdin 2>&1 || true)
}

function ParseLogs() {
    echo "* Processing: Parse log for $1 output ..."
    cat $strLogUnparsed | grep -i $1 | tee -a $strLogParsed > /dev/null 2>&1
    rm -rf $strLogUnparsed && echo OK
}

function ParseLogsCall() {
    ParseLogs "_VULNERABLE_"
    ParseLogs "_OLD_"
    ParseLogs "_POTENTIALLY_SAFE_"
}

function ApplicationCheck() {
    CheckApplication "sudo"
    CheckApplication "tee"
    CheckApplication "grep"
    CheckApplication "wget"
}

function mainCall() {
    ApplicationCheck
    DownloadJava
    DownloadLatestDetector
    Scanning | tee -a $strLogUnparsed
    ParseLogsCall
}

mainCall
exit 0
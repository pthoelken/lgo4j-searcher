#!/bin/bash

set -e

cd "$(dirname "$0")"
strCur=$PWD
strDate=$(date '+%d-%m-%Y_%H-%M-%S')
strLogDirectory=~/log4j-log
strLogFilePath=$strLogDirectory/$strDate-result-full-scan.log
strLogInFilePath=$strLogDirectory/$strDate-in-scan.log
strFinalResultLog=$strLogDirectory/$strDate-result-shrinked.log

strJavaLog4JBinary=log4j-detector-latest.jar
strJavaLog4JDownloadURL=https://github.com/mergebase/log4j-detector/raw/master/log4j-detector-latest.jar

if [ ! -d $strLogDirectory ]; then
        mkdir -p $strLogDirectory
fi

function Logger() {
    $1 >> $strLogFilePath
}

function EventError() {
    printf "\n✘✘✘ | $strDate | $1 \n"
}

function EventSuccess() {
    printf "\n✔✔✔ | $strDate | $1 \n"
}

function EventResultWarning() {
    printf "\n⚠ ⚠ ⚠ | $strDate | RESULTS FOR $1 \n"
}

 
function CheckApplicationExists() {
    if [ ! -n `which $1` 2>/dev/null ]; then
        EventError "Software $1 is not installed. Please be sure, that $1 is installed before running this script! Abort."
        exit 1
    fi
}

function WrapperCall() {
    sudo find / -xdev -type f | tee $strLogInFilePath | sudo java -jar $strJavaLog4JBinary --stdin --verbose 2>&1 | tee $strLogFilePath > /dev/null 2>&1
}

function DownloadLatestJarFile() {

    if [ ! -f $strJavaLog4JBinary ]; then
        curl -Lo $strJavaLog4JBinary $strJavaLog4JDownloadURL
    fi
    
}

function ParseResults() {
    if (grep -i "_VULNERABLE_" $strLogFilePath || grep -i "_OLD_" $strLogFilePath || grep -i "_POTENTIALLY_SAFE_" $strLogFilePath ); then

        printf "\n---------- WARNING ---------- WARNING ---------- WARNING  ---------- WARNING ---------- WARNING ---------- WARNING ----------\n"

        EventError "ALERT ALERT ALERT | SOMEONE LOOKS NOT GOOD! LOOKING FOR _OLD_ or _VULNERABLE_ or _POTENTIALLY_SAFE_ in the logfile at $strLogFilePath"

        printf "\n---------------------------------------------------------------------------------------------------------------------------------"

        printf "\n\nHostname: $HOSTNAME" 
        printf "\nUsername: $USERNAME" 
        printf "\nDatum: $strDate\n" 

        EventResultWarning "_VULNERABLE_"
        printf "
        Description of _VULNERABLE_: You need to upgrade or remove this file.\n\n"

        printf "List of vulnerabilities in your files from _VULNERABLE_:\n"
        cat $strLogFilePath | grep -u "_VULNERABLE_"
        printf "\n\n---------------------------------------------------------------------------------------------------------------------------------"

        EventResultWarning "_OLD_"
        printf "
        Description of _OLD_: You are safe from CVE-2021-44228, but should plan to upgrade because Log4J 1.2.x has been EOL for 7 years and 
        has several known-vulnerabilities.\n\n"

        printf "List of vulnerabilities in your files from _OLD_:\n"
        cat $strLogFilePath | grep -u "_OLD_"
        printf "\n\n---------------------------------------------------------------------------------------------------------------------------------"

        EventResultWarning "_POTENTIALLY_SAFE_"
        printf "
        Description of _POTENTIALLY_SAFE_: The JndiLookup.class file is not present, either because your version of Log4J is very old (pre 2.0-beta9), 
        or because someone already removed this file. Make sure it was someone in your team or company that removed JndiLookup.class if that's the case, 
        because attackers have been known to remove this file themselves to prevent additional competing attackers from gaining access to compromised systems.\n\n"

        printf "List of vulnerabilities in your files from _POTENTIALLY_SAFE_:\n"
        cat $strLogFilePath | grep -u "_POTENTIALLY_SAFE_"

        printf "\n\n---------- WARNING ---------- WARNING ---------- WARNING  ---------- WARNING ---------- WARNING ---------- WARNING ----------"

        printf "\n\n !!! PLEASE CHECK YOUR REPORT FROM $strFinalResultLog\n"

        exit 1
    else 
        EventSuccess "No results found! Have a nice day and keep smilin :) - if you want you can find your logs here $strLogFilePath" | tee -a $strLogFilePath
        rm -rf $strFinalResultLog
        exit 0
    fi   
}

function ApplicationCheck() {
    CheckApplicationExists "curl"
    CheckApplicationExists "java"
    CheckApplicationExists "sudo"
    CheckApplicationExists "tee"
    CheckApplicationExists "grep"
}


function mainCall() {

    touch $strFinalResultLog

    ApplicationCheck
    DownloadLatestJarFile
    WrapperCall
    ParseResults | tee -a $strFinalResultLog
    rm -rf $strLogInFilePath

}

mainCall
exit 0
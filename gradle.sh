#!/bin/bash -ex

#include common functions
MY_PATH=`dirname $(readlink -f "$0")`
source "${MY_PATH}/_utils.sh"

function usage {
    echo "Usage:"
    echo " $0 -r <packageUrl> -t <releaseDir> [-u <downloadUsername>] [-p <downloadPassword>] [-a <awsCliProfile>]"
    echo " -r     Package url (http, S3 or local file)"
    echo " -t     Target release dir normaly a folder where the last path is 'releases' "
    echo " -u     Download username"
    echo " -p     Download password"
    echo " -a     aws cli profile (defaults to 'default')"
    echo ""
    echo "Optional you can set following Variables: YAD_INSTALL_SCRIPT"
    exit $1
}

if [ -z "${YAD_INSTALL_SCRIPT}" ]; then
    echo "Use default YAD_INSTALL_SCRIPT"
    YAD_INSTALL_SCRIPT="./gradlew"
fi


AWSCLIPROFILE='default'
EXTRA=0

while getopts 'r:t:u:p:a:' OPTION ; do
case "${OPTION}" in
        r) YAD_PACKAGE="${OPTARG}";;
        t) YAD_RELEASE_FOLDER="${OPTARG}";;
        u) YAD_PACKAGE_USERNAME="${OPTARG}";;
        p) YAD_PACKAGE_PASSWORD="${OPTARG}";;
        s) YAD_SHARED_FOLDER_BASE="${OPTARG}";;
        a) AWSCLIPROFILE="${OPTARG}";;
        \?) echo; usage 1;;
    esac
done

# Create tmp dir and make sure it's going to be deleted in any case
TMPDIR=`mktemp -d`
function cleanup {
    echo "Removing temp dir ${TMPDIR}"
    rm -rf "${TMPDIR}"
}
trap cleanup EXIT

PACKAGE_BASENAME=`basename $YAD_PACKAGE`

download $YAD_PACKAGE $TMPDIR $PACKAGE_BASENAME

echo "Extracting setup package"
unzip -o "${TMPDIR}/${PACKAGE_BASENAME}" "setup/*" -d "${TMPDIR}" || { echo "Error while extracting setup package" ; exit 1; }

cd "${TMPDIR}/setup/"

# Install the package
if [ ! -f "${YAD_INSTALL_SCRIPT}" ] ; then echo "Could not find installer ${TMPDIR}/${YAD_INSTALL_SCRIPT} - you may want to define another installer with the Variable YAD_INSTALL_SCRIPT" ; exit 1; fi
./${YAD_INSTALL_SCRIPT} || { echo "Installing package failed"; exit 1; }
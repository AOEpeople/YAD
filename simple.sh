#!/bin/bash -ex

#include common functions
MY_PATH=`dirname $(readlink -f "$0")`
source "${MY_PATH}/_utils.sh"

function usage {
    echo "Usage:"
    echo " $0 -r <packageUrl> [-u <downloadUsername>] [-p <downloadPassword>] [-a <awsCliProfile>]"
    echo " -r     Package url (http, S3 or local file)"
    echo " -u     Download username"
    echo " -p     Download password"
    echo " -a     aws cli profile (defaults to 'default')"
    echo ""
    echo "Optional you can set following Variables: YAD_INSTALL_SCRIPT"
    exit $1
}

if [ -z "${YAD_INSTALL_SCRIPT}" ]; then
    echo "Use default YAD_INSTALL_SCRIPT"
    YAD_INSTALL_SCRIPT="install/install.sh"
fi

AWSCLIPROFILE='default'
EXTRA=0

while getopts 'r:t:u:p:a:' OPTION ; do
case "${OPTION}" in
        r) YAD_PACKAGE="${OPTARG}";;
        u) YAD_PACKAGE_USERNAME="${OPTARG}";;
        p) YAD_PACKAGE_PASSWORD="${OPTARG}";;
        a) AWSCLIPROFILE="${OPTARG}";;
        \?) echo; usage 1;;
    esac
done

PACKAGE_BASENAME=`basename "$YAD_PACKAGE"`
PACKAGE_NAME="${PACKAGE_NAME%.*}"

# Create tmp dir 
PACKAGE_TMPDIR=`mktemp -d -t yad.${PACKAGE_NAME}`

download $YAD_PACKAGE $PACKAGE_TMPDIR $PACKAGE_BASENAME

echo "Extracting setup package"
UNZIP_DIR="${PACKAGE_TMPDIR}/package"
unzip -o "${PACKAGE_TMPDIR}/${PACKAGE_BASENAME}" -d ${UNZIP_DIR} || { echo "Error while extracting setup package" ; exit 1; }

cd "${UNZIP_DIR}"

# Install the package
command -v ${YAD_INSTALL_SCRIPT} > /dev/null 2>&1 || { echo >&2 "${YAD_INSTALL_SCRIPT} not available - you may want to define another installer with the Variable YAD_INSTALL_SCRIPT. Aborting."; exit 1; }
${YAD_INSTALL_SCRIPT} || { echo "Installing package failed"; exit 1; }


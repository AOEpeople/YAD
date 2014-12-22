#!/bin/bash -ex

#include common functions
MY_PATH=`dirname $(readlink -f "$0")`
source "${MY_PATH}/_utils.sh"

function usage {
    echo "Usage:"
    echo " $0 -r <packageUrl> -t <releaseDir> [-u <downloadUsername>] [-p <downloadPassword>] [-a <awsCliProfile>] [-d]"
    echo " -r     Package url (http, S3 or local file)"
    echo " -t     Target release dir normaly a folder where the last path is 'releases' "
    echo " -u     Download username"
    echo " -p     Download password"
    echo " -a     aws cli profile (defaults to 'default')"
    echo ""
    echo "Optional you can set following Variables: YAD_INSTALL_SCRIPT"
    exit $1
}


if [ -z "YAD_INSTALL_SCRIPT" ]; then
    echo "Use default YAD_INSTALL_SCRIPT"
    YAD_INSTALL_SCRIPT="setup/install.sh"
fi


AWSCLIPROFILE='default'
EXTRA=0

while getopts 'r:t:u:p:a:' OPTION ; do
case "${OPTION}" in
        r) YAD_PACKAGE="${OPTARG}";;
        t) YAD_RELEASE_FOLDER="${OPTARG}";;
        u) YAD_PACKAGE_USERNAME="${OPTARG}";;
        p) YAD_PACKAGE_PASSWORD="${OPTARG}";;
        a) AWSCLIPROFILE="${OPTARG}";;
        \?) echo; usage 1;;
    esac
done
# Check if releases folder exists
if [ ! -d "${YAD_RELEASE_FOLDER}" ] ; then echo "Releases dir ${YAD_RELEASE_FOLDER} not found"; exit 1; fi

# Create tmp dir and make sure it's going to be deleted in any case
TMPDIR=`mktemp -d`
function cleanup {
    echo "Removing temp dir ${TMPDIR}"
    #rm -rf "${TMPDIR}"
}
trap cleanup EXIT

# Call download function
download $YAD_PACKAGE $TMPDIR

PACKAGE_BASENAME=`basename $YAD_PACKAGE`
PACKAGE_NAME=${PACKAGE_BASENAME%.*.*}

# Unpack the package
mkdir "${TMPDIR}/package" || { echo "Error while creating temporary package folder" ; exit 1; }
echo "Extracting base package"
tar xzf "${TMPDIR}/package.tar.gz" -C "${TMPDIR}/package" || { echo "Error while extracting base package" ; exit 1; }

#Check if package contained subfolder
UNPACKED_FOLDER="${TMPDIR}/package"
if [ -d "${TMPDIR}/package/$PACKAGE_NAME" ] ; then
    UNPACKED_FOLDER="${TMPDIR}/package/$PACKAGE_NAME"
fi

# Get buildnumber
if [ -f "${UNPACKED_FOLDER}/version.txt" ] ; then
    RELEASENAME=`cat ${UNPACKED_FOLDER}/version.txt`
elif [ -f "${UNPACKED_FOLDER}/build.txt" ] ; then
    RELEASENAME=`cat ${UNPACKED_FOLDER}/build.txt`
else
    echo "Could not find ${UNPACKED_FOLDER}/$PACKAGE_NAME/version.txt or build.txt! Fallback to timestamp";
    RELEASENAME=$(date +%s)
fi

if [ -z "${RELEASENAME}" ] ; then echo "Error detecting a RELEASENAME!"; exit 1; fi

# check if current release already exist
FINAL_RELEASEFOLDER="${YAD_RELEASE_FOLDER}/${RELEASENAME}"
if [ -d "${FINAL_RELEASEFOLDER}" ] ; then echo "Release folder ${FINAL_RELEASEFOLDER} already exists"; exit 1; fi

# Move unpacked folder to target path:
mv "${UNPACKED_FOLDER}" "${FINAL_RELEASEFOLDER}" || { echo "Error while moving package ${UNPACKED_FOLDER} folder to ${FINAL_RELEASEFOLDER}" ; exit 1; }

# Install the package
if [ ! -f "${FINAL_RELEASEFOLDER}/${YAD_INSTALL_SCRIPT}" ] ; then echo "Could not find installer ${FINAL_RELEASEFOLDER}/${YAD_INSTALL_SCRIPT} - you may want to define another installer with the Variable YAD_INSTALL_SCRIPT" ; exit 1; fi
${FINAL_RELEASEFOLDER}/${YAD_INSTALL_SCRIPT} || { echo "Installing package failed"; exit 1; }

echo
echo "Updating release symlinks"
echo "-------------------------"

cd ${YAD_RELEASE_FOLDER}

echo "Setting next symlink (${YAD_RELEASE_FOLDER}/next) to this release (${RELEASENAME})"
ln -sf "${RELEASENAME}" "next" || { echo "Error while symlinking the 'next' folder"; exit 1; }

# If you want to manually check before switching the other symlinks, this would be a good point to stop (maybe add another parameter to this script)

#if [ -n "${CURRENT_BUILD}" ] ; then
#    echo "Setting previous (${RELEASES}/previous) to current (${CURRENT_BUILD})"
#    ln -sfn "${CURRENT_BUILD}" "${RELEASES}/previous"
#fi

echo "Settings latest (${YAD_RELEASE_FOLDER}/latest) to release folder (${RELEASENAME})"
ln -sfn "${RELEASENAME}" "latest" || { echo "Error while symlinking 'latest' to release folder" ; exit 1; }

if [[ -h "${YAD_RELEASE_FOLDER}/current" ]] ; then
    echo "Setting previous to previous"
    ln -sfn "`readlink ${YAD_RELEASE_FOLDER}/current`" "previous"
fi

echo "Settings current (${YAD_RELEASE_FOLDER}/current) to 'latest'"
ln -sfn "latest" "current" || { echo "Error while symlinking 'current' to 'latest'" ; exit 1; }
echo "--> THIS PACKAGE IS LIVE NOW! <--"

echo "Deleting next symlink (${YAD_RELEASE_FOLDER}/next)"
unlink "${YAD_RELEASE_FOLDER}/next"


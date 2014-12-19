#!/bin/bash -ex

# TODO - Escape wget credentials parameter proberly

function usage {
    echo "Usage:"
    echo " $0 -r <packageUrl> -t <targetDir> [-u <downloadUsername>] [-p <downloadPassword>] [-a <awsCliProfile>] [-d]"
    echo " -r     Package url (http, S3 or local file)"
    echo " -t     Target dir (root dir) - a subfolder containing the 'releases' directory"
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
        r) PACKAGEURL="${OPTARG}";;
        t) ENVROOTDIR="${OPTARG}";;
        u) USERNAME="${OPTARG}";;
        p) PASSWORD="${OPTARG}";;
        a) AWSCLIPROFILE="${OPTARG}";;
        \?) echo; usage 1;;
    esac
done
# Check if releases folder exists
RELEASES="${ENVROOTDIR}/releases"
if [ ! -d "${RELEASES}" ] ; then echo "Releases dir ${RELEASES} not found"; exit 1; fi

# Create tmp dir and make sure it's going to be deleted in any case
TMPDIR=`mktemp -d`
function cleanup {
    echo "Removing temp dir ${TMPDIR}"
    #rm -rf "${TMPDIR}"
}
trap cleanup EXIT

if [ -f "${PACKAGEURL}" ] ; then
    cp "${PACKAGEURL}" "${TMPDIR}/package.tar.gz" || { echo "Error while copying base package" ; exit 1; }
elif [[ "${PACKAGEURL}" =~ ^https?:// ]] ; then
    if [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ] ; then
        CREDENTIALS="--user=${USERNAME} --password=${PASSWORD}"
    fi
    echo "Downloading package via http"
    wget --no-check-certificate --auth-no-challenge ${CREDENTIALS} "${PACKAGEURL}" -O "${TMPDIR}/package.tar.gz" || { echo "Error while downloading base package from http" ; exit 1; }

elif [[ "${PACKAGEURL}" =~ ^s3:// ]] ; then
    echo "Downloading package via S3"
    aws --profile ${AWSCLIPROFILE} s3 cp "${PACKAGEURL}" "${TMPDIR}/package.tar.gz" || { echo "Error while downloading base package from S3" ; exit 1; }

fi
PACKAGE_BASENAME=`basename $PACKAGEURL`

PACKAGE_NAME=${PACKAGE_BASENAME%.*.*}

# Unpack the package
mkdir "${TMPDIR}/package" || { echo "Error while creating temporary package folder" ; exit 1; }
echo "Extracting base package"
tar xzf "${TMPDIR}/package.tar.gz" -C "${TMPDIR}/package" || { echo "Error while extracting base package" ; exit 1; }

if [ ! -f "${TMPDIR}/package/$PACKAGE_NAME/version.txt" ] ; then echo "Could not find ${TMPDIR}/package/$PACKAGE_NAME/version.txt";
 exit 1; fi

BUILD_NUMBER=`cat ${TMPDIR}/package/$PACKAGE_NAME/version.txt`
if [ -z "${BUILD_NUMBER}" ] ; then echo "Error reading build number"; exit 1; fi

# check if current release already exist
RELEASEFOLDER="${RELEASES}/${BUILD_NUMBER}"
if [ -d "${RELEASEFOLDER}" ] ; then echo "Release folder ${RELEASEFOLDER} already exists"; exit 1; fi

# Move files to release folder
mv "${TMPDIR}/package/$PACKAGE_NAME" "${RELEASEFOLDER}" || { echo "Error while moving package folder" ; exit 1; }

echo

# Install the package
if [ ! -f "${RELEASEFOLDER}/${YAD_INSTALL_SCRIPT}" ] ; then echo "Could not find installer ${RELEASEFOLDER}/${YAD_INSTALL_SCRIPT}" ; exit 1; fi
${RELEASEFOLDER}/${YAD_INSTALL_SCRIPT} || { echo "Installing package failed"; exit 1; }

echo
echo "Updating release symlinks"
echo "-------------------------"

echo "Setting previous to previous"
ln -sfn "`readlink ${RELEASES}/current`" "${RELEASES}/previous"

echo "Settings current (${RELEASES}/current) to '${BUILD_NUMBER}'"
ln -sfn "${BUILD_NUMBER}" "${RELEASES}/current" || { echo "Error while symlinking 'current' to '${BUILD_NUMBER}'" ;
exit 1; }

echo "--> THIS PACKAGE IS LIVE NOW! <--"

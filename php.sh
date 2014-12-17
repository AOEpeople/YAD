#!/bin/bash

# TODO - Make sharedfolders settings optional or use a environemnt variable?
# TODO - Escape wget credentials parameter proberly

function usage {
    echo "Usage:"
    echo " $0 -r <packageUrl> -t <targetDir> [-u <downloadUsername>] [-p <downloadPassword>] [-a <awsCliProfile>] [-d]"
    echo " -r     Package url (http, S3 or local file)"
    echo " -t     Target dir (root dir) - a subfolder releases and shared is expected"
    echo " -u     Download username"
    echo " -p     Download password"
    echo " -a     aws cli profile (defaults to 'default')"
    echo ""
    echo "Optional you can set following Variables: INSTALLSCRIPT"
    exit $1
}



if [ -z "$INSTALLSCRIPT" ]; then
    echo "Use default INSTALLSCRIPT"
    INSTALLSCRIPT="install.sh"
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

# Check if the shared folder exists
SHAREDFOLDER="${ENVROOTDIR}/shared"
SHAREDFOLDERS=( "var" "media" )
if [ ! -d "${SHAREDFOLDER}" ] ; then echo "Shared folder ${SHAREDFOLDER} not found"; exit 1; fi
for i in "${SHAREDFOLDERS[@]}" ; do
    if [ ! -d "${SHAREDFOLDER}/$i" ] ; then echo "Shared folder ${SHAREDFOLDER}/$i not found"; exit 1; fi
done

# Create tmp dir and make sure it's going to be deleted in any case
TMPDIR=`mktemp -d`
function cleanup {
    echo "Removing temp dir ${TMPDIR}"
    rm -rf "${TMPDIR}"
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

# Unpack the package
mkdir "${TMPDIR}/package" || { echo "Error while creating temporary package folder" ; exit 1; }
echo "Extracting base package"
tar xzf "${TMPDIR}/package.tar.gz" -C "${TMPDIR}/package" || { echo "Error while extracting base package" ; exit 1; }


if [ ! -f "${TMPDIR}/package/build.txt" ] ; then echo "Could not find ${TMPDIR}/package/build.txt"; exit 1; fi

BUILD_NUMBER=`cat ${TMPDIR}/package/build.txt`
if [ -z "${BUILD_NUMBER}" ] ; then echo "Error reading build number"; exit 1; fi

RELEASENAME="build_${BUILD_NUMBER}"

# check if current release already exist
RELEASEFOLDER="${RELEASES}/${RELEASENAME}"
if [ -d "${RELEASEFOLDER}" ] ; then echo "Release folder ${RELEASEFOLDER} already exists"; exit 1; fi

# Move files to release folder
mv "${TMPDIR}/package" "${RELEASEFOLDER}" || { echo "Error while moving package folder" ; exit 1; }


# Install the package
if [ ! -f "${RELEASEFOLDER}/${INSTALLSCRIPT}" ] ; then echo "Could not find installer ${RELEASEFOLDER}/${INSTALLSCRIPT}" ; exit 1; fi
${RELEASEFOLDER}/${INSTALLSCRIPT} || { echo "Installing package failed"; exit 1; }

echo
echo "Updating release symlinks"
echo "-------------------------"

echo "Setting next symlink (${RELEASES}/next) to this release (${RELEASEFOLDER})"
ln -sf "next" "${RELEASES}/next" || { echo "Error while symlinking the 'next' folder"; exit 1; }

# If you want to manually check before switching the other symlinks, this would be a good point to stop (maybe add another parameter to this script)

#if [ -n "${CURRENT_BUILD}" ] ; then
#    echo "Setting previous (${RELEASES}/previous) to current (${CURRENT_BUILD})"
#    ln -sfn "${CURRENT_BUILD}" "${RELEASES}/previous"
#fi

echo "Settings latest (${RELEASES}/latest) to release folder (${RELEASENAME})"
ln -sfn "${RELEASENAME}" "${RELEASES}/latest" || { echo "Error while symlinking 'latest' to release folder" ; exit 1; }

echo "Settings current (${RELEASES}/current) to 'latest'"
ln -sfn "latest" "${RELEASES}/current" || { echo "Error while symlinking 'current' to 'latest'" ; exit 1; }
echo "--> THIS PACKAGE IS LIVE NOW! <--"

echo "Deleting next symlink (${RELEASES}/next)"
unlink "${RELEASES}/next"

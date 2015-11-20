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
    echo " -s     PATH to the folder where shared assets are stored, YAD_SHARED_FOLDERS need to be set, PATH/YAD_SHARED_FOLDERS[i] linked to target/current/YAD_SHARED_FOLDERS[i]"
    echo ""
    echo "Optional you can set following Variables: YAD_INSTALL_SCRIPT, YAD_POSTINSTALL_SCRIPT, YAD_ALLOW_REINSTALL"
    exit $1
}


if [ -z "${YAD_INSTALL_SCRIPT}" ]; then
    echo "Using default YAD_INSTALL_SCRIPT"
    YAD_INSTALL_SCRIPT="setup/install.sh"
fi


AWSCLIPROFILE=''
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
# Check if releases folder exists
if [ ! -d "${YAD_RELEASE_FOLDER}" ] ; then echo "Releases dir ${YAD_RELEASE_FOLDER} not found"; exit 1; fi

if [ -f "${YAD_RELEASE_FOLDER}/INSTALLING.lock" ] ; then echo "Install already in progress"; exit 1; fi

# Check if shared folder base exists if set
if [ ! -z ${YAD_SHARED_FOLDER_BASE+x} ] && [ ! -d ${YAD_SHARED_FOLDER_BASE} ]; then echo "Shared dir ${YAD_SHARED_FOLDER_BASE} not found"; exit 1; fi
if [ ! -z ${YAD_SHARED_FOLDER_BASE+x} ] &&  [ -z ${YAD_SHARED_FOLDERS+x} ]; then echo "If you want to symlink shared folders, than "; exit 1; fi

# Create tmp dir and make sure it's going to be deleted in any case
TMPDIR=`mktemp -d`
function cleanup {
    echo "Removing temp dir ${TMPDIR}"
    rm -rf "${TMPDIR}"
    if [ -f "${YAD_RELEASE_FOLDER}/INSTALLING.lock" ]; then rm ${YAD_RELEASE_FOLDER}/INSTALLING.lock; fi
}
trap cleanup EXIT

# Call download function
download $YAD_PACKAGE $TMPDIR 'package.tar.gz'

PACKAGE_BASENAME=`basename $YAD_PACKAGE`
PACKAGE_NAME=${PACKAGE_BASENAME%.*.*}

# Unpack the package
mkdir "${TMPDIR}/package" || { echo "Error while creating temporary package folder" ; exit 1; }
echo "Extracting base package"
tar xzf "${TMPDIR}/package.tar.gz" -C "${TMPDIR}/package" || { echo "Error while extracting base package" ; exit 1; }

# Check if package contained subfolder "package"
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
    echo "Could not find ${UNPACKED_FOLDER}/version.txt or build.txt! Fallback to timestamp";
    RELEASENAME=$(date +%s)
fi

# Check if package contained subfolder with "/$RELEASENAME/"
if [ -d "${TMPDIR}/package/$RELEASENAME" ] ; then
    UNPACKED_FOLDER="${TMPDIR}/package/$RELEASENAME"
fi

if [ -z "${RELEASENAME}" ] ; then echo "Error detecting a RELEASENAME!"; exit 1; fi

# check if current release already exist
FINAL_RELEASEFOLDER="${YAD_RELEASE_FOLDER}/${RELEASENAME}"
if [ -d "${FINAL_RELEASEFOLDER}" ]
then
    if [ -z ${YAD_ALLOW_REINSTALL+x} ]
    then
        echo "Release folder ${FINAL_RELEASEFOLDER} already exists";
        exit 1;
    else
        tmpReleaseFolder=$FINAL_RELEASEFOLDER
        counter=0;
        while [ -d  $tmpReleaseFolder ]
        do
            counter=$((counter + 1))
            tmpReleaseFolder="${FINAL_RELEASEFOLDER}_${counter}"
        done;
        FINAL_RELEASEFOLDER=$tmpReleaseFolder
    fi
fi

# Add Lock-File
touch ${YAD_RELEASE_FOLDER}/INSTALLING.lock

if [ -x "${YAD_PREINSTALL_SCRIPT}" ] ; then
    echo "Executing \"${YAD_PREINSTALL_SCRIPT}\" as pre-install script."
    ${YAD_PREINSTALL_SCRIPT} -r "${FINAL_RELEASEFOLDER}" || { echo "ERROR!!!! The pre-install script failed!"; exit 1; }
fi

# Move unpacked folder to target path:
mv "${UNPACKED_FOLDER}" "${FINAL_RELEASEFOLDER}" || { echo "Error while moving package ${UNPACKED_FOLDER} folder to ${FINAL_RELEASEFOLDER}" ; exit 1; }

# Shared folders feature
if [[ ! -z ${YAD_SHARED_FOLDER_BASE+x} ]] && [[ -d ${YAD_SHARED_FOLDER_BASE} ]]
then
    for path in ${YAD_SHARED_FOLDERS};
    do
        if [ -d "${FINAL_RELEASEFOLDER}/${path}" ]; then rm -rf ${FINAL_RELEASEFOLDER}/${path}; fi
        ln -s ${YAD_SHARED_FOLDER_BASE}/${path} ${FINAL_RELEASEFOLDER}/${path}
    done
fi

# Install the package
if [ ! -f "${FINAL_RELEASEFOLDER}/${YAD_INSTALL_SCRIPT}" ] ; then echo "Could not find installer ${FINAL_RELEASEFOLDER}/${YAD_INSTALL_SCRIPT} - you may want to define another installer with the Variable YAD_INSTALL_SCRIPT" ; exit 1; fi
${FINAL_RELEASEFOLDER}/${YAD_INSTALL_SCRIPT} || { echo "Installing package failed"; exit 1; }

echo
echo "Updating release symlinks"
echo "-------------------------"

cd ${YAD_RELEASE_FOLDER}

echo "Setting next symlink (${YAD_RELEASE_FOLDER}/next) to this release (${RELEASENAME})"
ln -sf "${FINAL_RELEASEFOLDER}" "next" || { echo "Error while symlinking the 'next' folder"; exit 1; }

# If you want to manually check before switching the other symlinks, this would be a good point to stop (maybe add another parameter to this script)

#if [ -n "${CURRENT_BUILD}" ] ; then
#    echo "Setting previous (${RELEASES}/previous) to current (${CURRENT_BUILD})"
#    ln -sfn "${CURRENT_BUILD}" "${RELEASES}/previous"
#fi

if [[ -h "${YAD_RELEASE_FOLDER}/current" ]] ; then
    echo "Setting previous to previous"
    ln -sfn "`readlink --canonicalize ${YAD_RELEASE_FOLDER}/current`" "previous"
fi

echo "Settings latest (${YAD_RELEASE_FOLDER}/latest) to release folder (${RELEASENAME})"
ln -sfn "${FINAL_RELEASEFOLDER}" "latest" || { echo "Error while symlinking 'latest' to release folder" ; exit 1; }

if [ -x "${YAD_POSTINSTALL_SCRIPT}" ] ; then
    echo "Executing \"${YAD_POSTINSTALL_SCRIPT}\" as postinstall script."
    ${YAD_POSTINSTALL_SCRIPT} -r "${FINAL_RELEASEFOLDER}" || { echo "ERROR!!!! The postinstall script failed and denied switching the current symlink! This is pretty serious..."; exit 1; }
fi

echo "Settings current (${YAD_RELEASE_FOLDER}/current) to 'latest'"
ln -sfn "latest" "current" || { echo "Error while symlinking 'current' to 'latest'" ; exit 1; }
echo "--> THIS PACKAGE IS LIVE NOW! <--"

# Remove Lock-File
rm ${YAD_RELEASE_FOLDER}/INSTALLING.lock

echo "Deleting next symlink (${YAD_RELEASE_FOLDER}/next)"
unlink "${YAD_RELEASE_FOLDER}/next"

# clean up old releases
YAD_KEEP=${YAD_RELEASES_TO_KEEP:-5}
ls -1t "${YAD_RELEASE_FOLDER}" | egrep -v "current|latest|next|previous|$(basename $FINAL_RELEASEFOLDER)" | sort -r | tail -n +$(($YAD_KEEP+1)) | xargs rm -rf


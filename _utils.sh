#!/bin/bash


####
# Download function to download a package
# @param package_url
# @param targetDir
#
# Global Variables read: YAD_PACKAGE_USERNAME, YAD_PACKAGE_PASSWORD, AWSCLIPROFILE
#
####
function download  {
    local package_url=$1
    local targetDir=$2

    if [ -f "${package_url}" ] ; then
        cp "${package_url}" "${targetDir}/package.tar.gz" || { echo "Error while copying base package to ${targetDir}" ; exit 1; }
    elif [[ "${package_url}" =~ ^https?:// ]] ; then
        if [ ! -z "${YAD_PACKAGE_USERNAME}" ] && [ ! -z "${YAD_PACKAGE_PASSWORD}" ] ; then
            echo "Using username ${YAD_PACKAGE_USERNAME} and given password to download"
            # TODO - Escape wget credentials parameter proberly
            CREDENTIALS="--user=${YAD_PACKAGE_USERNAME} --password=${YAD_PACKAGE_PASSWORD}"
        fi
        echo "Downloading package via http"
        wget --no-verbose --no-check-certificate --auth-no-challenge ${CREDENTIALS} "${package_url}" -O "${targetDir}/package.tar.gz" || { echo "Error while downloading base package from http" ; exit 1; }

    elif [[ "${package_url}" =~ ^s3:// ]] ; then
        echo "Downloading package via S3"
        if [ -z "AWSCLIPROFILE" ]; then
             echo "Missing Variable AWSCLIPROFILE"
            exit 1
        fi
        aws --profile ${AWSCLIPROFILE} s3 cp "${package_url}" "${targetDir}/package.tar.gz" || { echo "Error while downloading base package from S3" ; exit 1; }

    fi
}

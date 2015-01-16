#!/bin/bash -ex
BASE_PATH=$( cd $(dirname $0) ; pwd -P )

##############
# Validation
if [ -z "YAD_DEPLOY" ]; then
    echo "YAD_DEPLOY not set - set it to e.g. php.sh"
    exit 1
fi

if [ -z "YAD_RELEASE_FOLDER" ]; then
    echo "YAD_RELEASE_FOLDER not set"
    exit 1
fi

if [ -z "YAD_PACKAGE" ]; then
    echo "YAD_PACKAGE not set - set it to the URL or location of the package that should be installed"
    exit 1
fi

##############
# Dispatching
echo $YAD_DEPLOY
"$BASE_PATH/$YAD_DEPLOY" -t $YAD_RELEASE_FOLDER -r $YAD_PACKAGE
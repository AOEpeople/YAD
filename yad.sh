#!/bin/bash -ex
BASE_PATH=$( cd $(dirname $0) ; pwd -P )
echo $YAD_DEPLOY
"$BASE_PATH/$YAD_DEPLOY" -t $YAD_RELEASE_FOLDER -r $YAD_PACKAGE

# dispatching

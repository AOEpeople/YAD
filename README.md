# YAD

Light weight deployment scripts

This repository is suggested to be located under `/etc/yad/deploy/`

## Deploymentscript "php.sh"

Takes care of downloading a package with the application. Takes care of managing the releases and the symlinks.

Uses the following Variables:

-  YAD_RELEASE_FOLDER : Path to the folder where the package should be installed.
    Inside of this folder some symlinks are maintained by the script: latest, current, previous and next

-  YAD_PACKAGE : Url to the package

-  YAD_PACKAGE_USERNAME, YAD_PACKAGE_PASSWORD : Optional the username required to download the package

-  AWSCLIPROFILE : If the package points to S3, this is the profile that will be used

## Concepts:
The deployment concept of YAD consists of the following steps and conventions:

1.  Deployment Preparation:
    For every application there exists a deploymentscript under /usr/local/bin following the naming convention
    yad_<projectname>_<applicationname>_<environmentname>

    This script itself is very light and the only thing it does is including the settings file for this application.
    (a script under "/etc/yad/<projectname>/<applicationname>/<environmentname>", which normaly only contains some defined Variables (like DB_HOST ...), that the installation of this application expects.)

    This script then triggers the standard yad deployment scripts.

2.  Deployment:
    The standard yad deploymentscripts are located under /etc/yad/deploy

    The deploymentscript is just responsible for downloading the application package from a specified url, taking care of cleaning up old releases if required, and then triggers the installation script.
    For more details read https://github.com/aoepeople/yad

3.  Installation:
    The installation is completely in the responsibility of the application.
    A typical step in the installation is adjusting application settings like database settings.
    We recommend using "settings injection": The installation process should expect the settings in environment variables! Exactly the ones included in step 1 :-)

###Available options
Option | Type | Description | Default | Required
--- | --- | --- | --- | ---
`YAD_DEPLOY` | String | Script to use for the installation | php.sh | YES
`YAD_RELEASE_FOLDER` | String | Release directory where your application should be installed |  | YES
`YAD_INSTALL_SCRIPT` | String | Entry point for your package installation | setup/install.sh | NO
`YAD_PACKAGE` | String | Used to download the deployment artefact (can be zip, tar.gz) |  | YES
`YAD_PACKAGE_USERNAME` | String | User to login in order to download the artefact |  | NO
`YAD_PACKAGE_PASSWORD` | String | Password to login in order to download the artefact | | NO
`YAD_PREINSTALL_SCRIPT` | String | Executable script that is triggered before the installation starts |  | NO
`YAD_POSTINSTALL_SCRIPT` | String | Executable script that is triggered before the symlink switch is done |  | NO
`YAD_POSTDEPLOYMENT_SCRIPT` | String | Executable script that is triggered after deployment (symlinking) |  | NO
`YAD_RELEASES_TO_KEEP` | Integer | Keep only the number of releases (rest will be deleted) | 5 | NO
`YAD_ADD_EXTRA_PACKAGE` | String | If set the extra package (.extra.tar.gz) will downloaded and extracted on top of the original package |  | NO

### Example
project: starfleet
application: magento
environment: staging

call:

    /usr/local/bin/yad_starfleet_magento_staging
    |--> source /etc/yad/starfleet/magento/staging.sh (File containing the settings for this environment.)
    |--> call /etc/yad/deploy/yad.sh
         |--> basic validation that YAD_* variables are defined
         |--> ensure /etc/yad/deploy/__APP__.sh is available
         |--> call the specific deployment-script e.g. /etc/yad/deploy/php.sh

/usr/local/bin/yad_starfleet_magento_staging content:

    #!/bin/bash

    source "/etc/yad/starfleet/magento/staging.sh"
    /etc/yad/deploy/yad.sh


/etc/yad/starfleet/magento/staging.sh content:

    ## starfleet-magento

    export DB_HOST='localhost'
    export DB_USER='mg_stage'
    export DB_PASS='mg_pass'
    export DB_NAME='magento_staging'

    #######################
    # YAD specific settings

    export YAD_DEPLOY=php.sh
    export YAD_RELEASE_FOLDER=/var/www/starfleet/magento/staging/releases
    export YAD_INSTALL_SCRIPT=setup/install.sh

    # package containing at least an install.sh install script
    # supports tgz and zip packages
    export YAD_PACKAGE=https://example.tdl/artifact/starfleet-magento.tar.gz
    export YAD_PACKAGE_USERNAME=__USERNAME__
    export YAD_PACKAGE_PASSWORD=__PASSWORD__

## Deploymentscript "gradle.sh"

It expect a zip archive as artefact with a folder setup. In the setup folder should be a gradle build file.
As default the gradlew wrapper will be called.
Change YAD_INSTALL_SCRIPT=gradle if you have installed the wrapper on the target machine.

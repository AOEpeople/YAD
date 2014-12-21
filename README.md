# YAD

Light weight deployment scripts

This repository is suggested to be located under `/etc/yad/deploy/`

## Deploymentscript "php.sh"

Takes car of downloading a package with the application. Takes care of managing the releases and the symlinks.

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


### Example
project: starfleet
application: magento
environment: staging

call:

    /usr/local/bin/yad_starfleet_magento_staging
    |--> source /etc/yad/starfleet/magento/staging.sh (File containing the settings for this environment.)
    |--> call /etc/yad/yad.sh
         |--> validate whatever
         |--> ensure /etc/yad/deploy/ is checked out
         |--> call the specific deployment-script e.g. /etc/yad/deploy/php.sh

/usr/local/bin/yad_starfleet_magento_staging content:

    YAD_PROJECT="starfleet"
    YAD_APPLICATION="magento"
    YAD_ENVIRONMENT="staging"

    source "/etc/yad/${YAD_PROJECT}/${YAD_APPLICATION}/${YAD_ENVIRONMENT}.sh"
    /etc/yad/deploy/yad.sh


/etc/yad/starfleet/magento/staging.sh content:

    DB_HOST='localhost'
    DB_USER='mg_stage'
    DB_PASS='mg_pass'
    DB_NAME='magento_staging'
    
    # package containing at least an install.sh install script
    # supports tgz and zip packages
    YAD_PACKAGE="http://integration.host/job/xyz/artifacts/magento.tgz"

    YAD_DEPLOY='php.sh'
    # can be one of:
    # something.sh (called in /etc/yad/deploy/something.sh)
    # /usr/local/my/deploy.sh (to call something specific)
    # https://buildserver/artifact/special_deploy.sh (download and execute?!)

    YAD_RELEASE_FOLDER="/var/www/${YAD_PROJECT}/${YAD_APPLICATION}/${ENVIRONMENT}/releases/"



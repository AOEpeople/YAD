# YAD

This repository belongs to `/etc/yad/deploy/`


## Example:
project: starfleet
application: magento
environment: staging

call:

    /usr/local/bin/yad_starfleet_magento_staging
    |--> source /etc/yad/starfleet/magento/staging.sh (/etc/yad/starfleet/ is a git repo)
    |--> call /etc/yad/yad.sh
         |--> validate whatever
         |--> ensure /etc/yad/deploy/ is checked out
         |--> call /etc/yad/deploy/php.sh

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

## responibilities

/usr/local/bin/yad_starfleet_magento

`-> source /etc/yad/starfleet/magento/staging.sh`

`-> call /etc/yad/deploy/yad.sh`

/etc/yad/deploy/yad.sh

`-> validation`

`-> call /etc/yad/deploy/php.sh`


/usr/local/bin/yad_starfleet_magento <-- basiert auf generische yad.sh, kann lokale defaults haben

/etc/yad/deploy <-- repository für deploy-scripte, e.g. php.sh, java.sh, etc...

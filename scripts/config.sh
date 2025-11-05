#!/bin/bash

# This script provides common customization options for the ISO
# 
# Usage: Copy this file to config.sh and make changes there.  Keep this file (default_config.sh) as-is
#   so that subsequent changes can be easily merged from upstream.  Keep all customiations in config.sh

# The version of Ubuntu to generate.  Successfully tested LTS: bionic, focal, jammy, noble
# See https://wiki.ubuntu.com/DevelopmentCodeNames for details
export TARGET_UBUNTU_VERSION="noble"

# The Ubuntu Mirror URL. It's better to change for faster download.
# More mirrors see: https://launchpad.net/ubuntu/+archivemirrors
export TARGET_UBUNTU_MIRROR="http://us.archive.ubuntu.com/ubuntu/"

# The packaged version of the Linux kernel to install on target image.
# See https://wiki.ubuntu.com/Kernel/LTSEnablementStack for details
export TARGET_KERNEL_PACKAGE="linux-generic"

# The file (no extension) of the ISO containing the generated disk image,
# the volume id, and the hostname of the live environment are set from this name.
export TARGET_NAME="ubuntu-pbx"

# The text label shown in GRUB for booting into the live environment
export GRUB_LIVEBOOT_LABEL="Probar Ubuntu-PBX sin instalar"

# The text label shown in GRUB for starting installation
export GRUB_INSTALL_LABEL="Instalar Ubuntu-PBX"

# Packages to be removed from the target system after installation completes succesfully
export TARGET_PACKAGE_REMOVE="
    ubuntu-standard
    ubiquity \
    casper \
    discover \
    laptop-detect \
    os-prober \
    wpagui \
    grub-gfxpayload-lists
"

# Package customisation function.  Update this function to customize packages
# present on the installed system.
function customize_image() {
    # Instalar asterisk
    apt-get install -y asterisk asterisk-dahdi asterisk-doc asterisk-flite asterisk-mobile asterisk-modules asterisk-mp3 asterisk-ooh323 asterisk-prompt-es asterisk-tests asterisk-config asterisk-moh* asterisk-core-sounds-es*

    # Herramientas útiles
    apt-get install -y \
        ubuntu-server \
        openssh-server \
        wget \
        apt-transport-https \
        curl \
        nano \
        less

    apt-get install -y build-essential linux-headers-`uname -r` openssh-server apache2 mariadb-server mariadb-client bison flex php8.2 php8.2-curl php8.2-cli php8.2-common php8.2-mysql php8.2-gd php8.2-mbstring  php8.2-intl php8.2-xml php-pear curl sox libncurses5-dev libssl-dev mpg123 libxml2-dev libnewt-dev sqlite3  libsqlite3-dev pkg-config automake libtool autoconf git unixodbc-dev uuid uuid-dev libasound2-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev odbc-mariadb libical-dev libneon27-dev libsrtp2-dev  libspandsp-dev sudo subversion libtool-bin python-dev-is-python3 unixodbc vim wget libjansson-dev software-properties-common nodejs npm ipset iptables fail2ban php-soap

    # apache
    sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/8.2/apache2/php.ini
    sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/8.2/apache2/php.ini
    sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
    sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
    a2enmod rewrite
    systemctl restart apache2
    rm /var/www/html/index.html

    #odbc

    cat <<EOF > /etc/odbcinst.ini
[MySQL]
Description = ODBC for MySQL (MariaDB)
Driver = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
FileUsage = 1
EOF

cat <<EOF > /etc/odbc.ini
[MySQL-asteriskcdrdb]
Description = MySQL connection to 'asteriskcdrdb' database
Driver = MySQL
Server = localhost
Database = asteriskcdrdb
Port = 3306
Socket = /var/run/mysqld/mysqld.sock
Option = 3
EOF


    # FreePBX
    cd /usr/local/src
    wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-17.0-latest-EDGE.tgz
    tar zxvf freepbx-17.0-latest-EDGE.tgz
    cd /usr/local/src/freepbx/
    ./start_asterisk start
    ./install -n


    #Modulos
    fwconsole ma installall
    fwconsole reload
    fwconsole restart


    #systemd
    cat <<EOF > /etc/systemd/system/freepbx.service
[Unit]
Description=FreePBX VoIP Server
After=mariadb.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/fwconsole start -q
ExecStop=/usr/sbin/fwconsole stop -q
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable freepbx

    # Remover paquetes innecesarios
    apt-get autoremove -y
}

# Used to version the configuration.  If breaking changes occur, manual
# updates to this file from the default may be necessary.
export CONFIG_FILE_VERSION="0.4"

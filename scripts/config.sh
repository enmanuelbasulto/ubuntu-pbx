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
    sed -i 's";\[radius\]"\[radius\]"g' /etc/asterisk/cdr.conf
    sed -i 's";radiuscfg => /usr/local/etc/radiusclient-ng/radiusclient.conf"radiuscfg => /etc/radcli/radiusclient.conf"g' /etc/asterisk/cdr.conf
    sed -i 's";radiuscfg => /usr/local/etc/radiusclient-ng/radiusclient.conf"radiuscfg => /etc/radcli/radiusclient.conf"g' /etc/asterisk/cdr.conf
    
    # Herramientas útiles
    apt-get install -y \
        ubuntu-server \
        openssh-server \
        wget \
        apt-transport-https \
        curl \
        nano \
        less

    apt-get install mpg123 nodejs npm mariadb-server mariadb-client apache2 php libapache2-mod-php php-intl php-mysql php-curl php-cli php-zip php-xml php-gd php-common php-mbstring php-xmlrpc php-bcmath php-json php-sqlite3 php-soap php-zip php-ldap php-imap php-cas php-pear sox fail2ban -y

    # apache
    sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/8.3/apache2/php.ini
    sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/8.3/apache2/php.ini
    sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
    sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
    a2enmod rewrite
    rm /var/www/html/index.html

    # FreePBX
    cd /usr/local/src
    wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-17.0-latest-EDGE.tgz
    tar zxvf freepbx-17.0-latest-EDGE.tgz
    cd /usr/local/src/freepbx/
    ./start_asterisk start

    echo "Iniciar mariadb (toscamente porque systemd es una mierda, pero es lo que se usa y queremos resolver un problema no iniciar una revolución)"
    
    echo "Starting MariaDB in chroot environment..."

# Check if MySQL is already running
if [ -S /var/run/mysqld/mysqld.sock ]; then
    echo "MySQL is already running!"
    exit 0
fi

# Create necessary directories
mkdir -p /var/run/mysqld
mkdir -p /var/log/mysql

# Set permissions
chown -R mysql:mysql /var/run/mysqld
chown -R mysql:mysql /var/log/mysql
chmod 755 /var/run/mysqld

# Initialize database if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Start MariaDB
echo "Starting MariaDB server..."
sudo -u mysql /usr/sbin/mysqld \
  --datadir=/var/lib/mysql \
  --socket=/var/run/mysqld/mysqld.sock \
  --log-error=/var/log/mysql/error.log \
  --pid-file=/var/run/mysqld/mysqld.pid \
  --user=mysql &

# Wait for MySQL to start
sleep 5

# Check if MySQL started successfully
if [ -S /var/run/mysqld/mysqld.sock ]; then
    echo "MariaDB started successfully!"
    
    # Secure installation if first time
    if [ ! -f /var/lib/mysql/.secured ]; then
        echo "Running initial security setup..."
        mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';"
        mysql -e "DELETE FROM mysql.user WHERE User='';"
        mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        mysql -e "DROP DATABASE IF EXISTS test;"
        mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
        mysql -e "FLUSH PRIVILEGES;"
        touch /var/lib/mysql/.secured
    fi
else
    echo "Failed to start MariaDB. Check /var/log/mysql/error.log for details."
    exit 1
fi
echo "=== MariaDB Socket Diagnostic ==="
echo "1. Socket file check:"
ls -la /var/run/mysqld/mysqld.sock 2>/dev/null || echo "Socket file not found"

echo "2. MariaDB socket variable:"
mysql -u root -e "SHOW VARIABLES LIKE 'socket';" 2>/dev/null || echo "Cannot connect to MySQL"

echo "3. Directory permissions:"
ls -ld /var/run/mysqld/ 2>/dev/null || echo "Directory not found"

echo "4. Process check:"
ps aux | grep mysql | grep -v grep

echo "5. Network listeners:"
ss -tlnp | grep 3306
    
    ./install -n


    #Instalar módulos
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
    systemctl enable apache2
    systemctl enable mariadb

    # Remover paquetes innecesarios
    apt-get autoremove -y
}

# Used to version the configuration.  If breaking changes occur, manual
# updates to this file from the default may be necessary.
export CONFIG_FILE_VERSION="0.4"

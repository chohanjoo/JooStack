#!/bin/bash

IP=10.0.0.11
MYSQL_ROOT_PASSWORD=root
RABBIT_PASS=root
HOSTNAME=controller

# OpenStack packages for Ubuntu
echo "\n\n[STEP] OpenStack packages for Ubuntu\n\n"

add-apt-repository cloud-archive:stein
apt update && apt dist-upgrade -y
apt install python3-openstackclient -y

# SQL database for Ubuntu
echo "\n\n[STEP] SQL database for Ubuntu\n\n"
apt install mariadb-server python-pymysql -y

echo "[mysqld]
bind-address = "$IP"

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8" > /etc/mysql/mariadb.conf.d/99-openstack.cnf

service mysql restart

apt install -y aptitude
aptitude -y install expect

# Not required in actual script

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password? [Y/n]\"
send \"y\r\"
expect \"New password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Re-enter new password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

echo "$SECURE_MYSQL"

aptitude -y purge expect

# Message queue for Ubuntu
echo "\n\n[STEP] Message queue for Ubuntu\n\n"

apt install rabbitmq-server -y
rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"


# Memcached for Ubuntu
echo "\n\n[STEP] Memcached for Ubuntu\n\n"

apt install memcached python-memcache -y
sed -i 's/-l 127.0.0.1/-l 10.0.0.11/' /etc/memcached.conf
service memcached restart


# Etcd for Ubuntu
echo "\n\n[STEP] Etcd for Ubuntu\n\n"

apt install etcd -y

echo "
ETCD_NAME=\""$HOSTNAME"\"
ETCD_DATA_DIR=\""/var/lib/etcd"\"
ETCD_INITIAL_CLUSTER_STATE=\"new\"
ETCD_INITIAL_CLUSTER_TOKEN=\"etcd-cluster-01\"
ETCD_INITIAL_CLUSTER=\""controller=http://"$IP":2380"\"
ETCD_INITIAL_ADVERTISE_PEER_URLS=\""http://"$IP":2380"\"
ETCD_ADVERTISE_CLIENT_URLS=\""http://"$IP":2379"\"
ETCD_LISTEN_PEER_URLS=\""http://0.0.0.0:2380"\"
ETCD_LISTEN_CLIENT_URLS=\""http://"$IP":2379"\"
" >> /etc/default/etcd

: << 'END'
sed -i "s/^ETCD_NAME.*/ETCD_NAME="""$HOSTNAME"""/" /etc/default/etcd
sed -i "s/^ETCD_DATA_DIR.*/ETCD_DATA_DIR=""/var/list/etcd""/" /etc/default/etcd
sed -i "s/^ETCD_INITIAL_CLUSTER_STATE.*/ETCD_INITIAL_CLUSTER_STATE=""new""/" /etc/default/etcd
sed -i "s/^ETCD_INITIAL_CLUSTER_TOKEN.*/ETCD_INITIAL_CLUSTER_TOKEN=""etcd-cluster-01""/" /etc/default/etcd
sed -i "s/^ETCD_INITIAL_CLUSTER.*/ETCD_INITIAL_CLUSTER=""controller=http://"$IP":2380""/" /etc/default/etcd
sed -i "s/^ETCD_INITIAL_ADVERTISE_PEER_URLS.*/ETCD_INITIAL_ADVERTISE_PEER_URLS=""http://"$IP":2380""/" /etc/default/etcd
sed -i "s/^ETCD_ADVERTISE_CLIENT_URLS.*/ETCD_ADVERTISE_CLIENT_URLS=""http://"$IP":2379""/" /etc/default/etcd
sed -i "s/^ETCD_LISTEN_PEER_URLS.*/ETCD_LISTEN_PEER_URLS=""http://0.0.0.0:2380""/" /etc/default/etcd
sed -i "s/^ETCD_LISTEN_CLIENT_URLS.*/ETCD_LISTEN_CLIENT_URLS=""http://"$IP":2379""/" /etc/default/etcd
END

systemctl enable etcd
systemctl restart etcd

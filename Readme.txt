#./galera_mysqlboot.sh
usage: ./galera_mysqlboot.sh (start|monitor|bootstrap-pxc) /etc/my.cnf

./galera_mysqlboot.sh manages MySQL Database an galera cluster

The 'start' operation starts the database.
The 'stop' operation stops the database.
The 'monitor' operation reports whether the database seems to be working
The 'bootstrap-pxc' operation reports whether the mysql demaon with bootstrap-pxc parameters by itself as cluster bootstrap
###########################


echo '/usr/local/check_openstack/galera_mysqlboot.sh bootstrap-pxc' >> /etc/rc.d/rc.local

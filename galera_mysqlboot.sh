#!/bin/bash
#linuxpf 20150417
HOSTNAME=$(uname -n)
galera_client_binary_default="/usr/bin/mysql"
galera_config_default=${2:-"/etc/my.cnf"}
galera_socket_default=${3:-"/var/lib/mysql/mysql.sock"}
[ ! -f $galera_config_default ] && echo "$galera_config_default not found" && exit 1

galera_datadir_default=`cat $galera_config_default|awk -F"=" '/^datadir=/ {print $NF}'`
galera_cluster_hostlist=`cat $galera_config_default|awk -F"=" '/^wsrep_cluster_address/ {print substr($NF,9)}'|tr ',' ' '`

galera_check_port=9200
galera_user_default="mysql"
galera_group_default="mysql"
galera_pid_default="${galera_datadir_default}/${HOSTNAME}.pid"
galera_test_user_default="root"
galera_test_passwd_default="password"
#galera_timeout_default="5"
#
usage(){
    cat <<UEND
usage: $0 (start|monitor|bootstrap-pxc) /etc/my.cnf 

$0 manages MySQL Database an galera cluster

The 'start' operation starts the database.
The 'stop' operation stops the database.
The 'monitor' operation reports whether the database seems to be working
The 'bootstrap-pxc' operation reports whether the mysql demaon with bootstrap-pxc parameters by itself as cluster bootstrap

UEND
}

mysql_clean() {
    echo "...mysql cleanup ..."
   
    [ -f /var/lock/subsys/mysql ] && rm -f /var/lock/subsys/mysql
    [ -f $galera_socket_default ] && rm -f $galera_socket_default
    [ -f $galera_socket_default ] && rm -f $galera_socket_default
}


mysql_test(){
    mesg=0
    /usr/bin/clustercheck
    if [ $? -eq 0 ]; then
        echo "mysql running ,localhost check ok "
        mesg=1
    else
        echo "localhost check fail"
    fi
}

killpid(){
    if [ `ps -ef |grep -i mysql|grep -v grep |wc -l` -gt 1 ]; then
        kill -9 `ps -ef |grep -i mysqld|grep -v grep|awk '{print $2}'`
    fi
}
mysql_pxc(){
     mysql_test
     [ $mesg -gt 0 ] && exit 1
     num=0
     if [ `ps -ef |grep -i mysql|grep -v grep |wc -l` -gt 1 ]; then
         killpid
     fi
     #/etc/init.d/mysql start
     #[ $? -eq 0 ] && echo 'started mysql sucesses' ||echo 'started mysql failed!'
     for host in $galera_cluster_hostlist;do
          [ ! -f /usr/bin/nc ] && yum -y install nc
          echo "host:$host"
          /usr/bin/nc -zv $host $check_port 2>/dev/null
          if [ $? -eq 0 ];then
              num=$((num+1))
              echo -e "\033[32;1m$host clustercheck ok\033[0m"
          else
              echo -e "\033[31;1m$host clustercheck false\033[0m"
          fi
     done
     if [ $num -lt 1 ];then
         mysql_clean
         echo -e "\033[32;1mmysql demaon with bootstrap-pxc parameters by itself as cluster bootstrap...\033[0m"
         /etc/init.d/mysql bootstrap-pxc
         mysql_test
         [ $mesg -lt 1 ] && /etc/init.d/mysql restart-bootstrap||echo 'ok'
     fi
}


mysql_start(){
     mysql_test
     [ $mesg -gt 0 ] && exit 1    
     /etc/init.d/mysql start
}


mysql_monitor(){
     stat_log="/tmp/mysql_monitor.log"
     mysql_test
     mysql -u${galera_test_user_default} -p${galera_test_passwd_default} -e "SHOW STATUS LIKE 'wsrep%'" >$stat_log
     [ ! -f  $stat_log ] && exit 1
     wsrep_connected=`cat $stat_log|awk '/wsrep_connected/ {print $NF}'`
     wsrep_ready=`cat $stat_log|awk '/wsrep_ready/ {print $NF}'`
     wsrep_cluster_status=`cat $stat_log|awk '/Primary/ {print $NF}'`
     wsrep_local_state_comment=`cat $stat_log|awk '/wsrep_local_state_comment/ {print $NF}'`
     if [ -z $wsrep_connected ];then
         echo -e "\033[31;1mwsrep_connected failed\033[0m"
     elif [ $wsrep_connected == "ON" ];then
         echo   -e "\033[32;1mwsrep_connected:ON\033[0m"
         [ -n $wsrep_ready -a $wsrep_ready == "ON" ] && echo -e "\033[32;1mwsrep_ready:ON\033[0m"  || echo "wsrep_ready:$wsrep_ready falled"
         [ -z $wsrep_cluster_status -o  $wsrep_cluster_status != "Primary" ] && echo "wsrep_cluster_status:failed" || echo -e "\033[32;1mwsrep_cluster_status:$wsrep_cluster_status\033[0m"
         [ -n $wsrep_local_state_comment -a $wsrep_local_state_comment == "Synced" ] && echo -e "\033[32;1mwsrep_local_state_comment:Synced\033[0m" || echo "wsrep_local_state_comment:$wsrep_local_state_comment failed"
     else
          echo -e "\033[31;1mwsrep_connected:$wsrep_connected failed\033[0m"
     fi
}
case "$1" in
    start)        mysql_start;;
    stop)         /etc/init.d/mysql stop;;
    monitor)      mysql_monitor;;
    bootstrap-pxc):
                  mysql_pxc;;
    *)            usage;;
esac

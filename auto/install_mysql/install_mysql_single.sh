#!/bin/bash
##################################
# File Name:install_mysql_single.sh
# Author:zhangjiale
# Version:V1.0
# Description:install single instance for MySQL

export OPERATE_LOG=/tmp/operate_install_mysql_single.log
export FORMAT_TIME=`date +"%Y-%m-%d_%H:%M:%S"`
export STARTTIME=`date +"%Y-%m-%d %H:%M:%S"`
export LOCAL_IP=$LOCAL_IP
export MYSQL="/usr/local/mysql/bin/mysql"
export BASEDIR="$(dirname "$0")"
yum list net-tools |grep "Installed Packages" >/dev/null 2>&1
[ $? -ne 0 ] && yum -y install net-tools >>$OPERATE_LOG 2>&1
export SID=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|head -1|awk -F'.' '{print $NF}' `
export EXISTS_PORT=`netstat -ntpl |grep mysqld |awk '{print $4}' |awk -F ':' '{print $NF}'|awk BEGIN{RS=EOF}'{gsub(/\n/," ");print}'`
export EXISTS_PORT_NUM=`netstat -ntpl |grep mysqld |awk '{print $4}' |awk -F ':' '{print $NF}'|awk BEGIN{RS=EOF}'{gsub(/\n/," ");print}'|wc -l`
if [ $EXISTS_PORT_NUM -gt 0 ];then
        echo -e "MySQL instance $EXISTS_PORT already exists. Please choice an unused port to use !!!"
        read -p "Input you will use MySQL-Instance Port:" MYSQL_PORT
else 
        export MYSQL_PORT="3306"
        echo -e "No MySQL Instance started. choice 3306 port to use."
fi

read -p "Input you will use MySQL-Version{5.7 or 8.0}:" MYSQL_VERSION

cat /etc/passwd |grep -w mysql >/dev/null 2>&1 && echo "User:mysql is exists" >/dev/null || groupadd mysql >/dev/null 2>&1  && useradd -r -g mysql -s /bin/false mysql >/dev/null 2>&1 
export DBPATH="/database/mysql$MYSQL_PORT/"
if [ ! -d ${DBPATH} ];then
        mkdir -p /database/mysql$MYSQL_PORT/{data,binlog,relaylog,redolog,tmp,undolog,backup}
fi
chown -R mysql.mysql /database/mysql$MYSQL_PORT/

export MY_V=$MYSQL_VERSION
#mysql_tarball=`find $basedir -maxdepth 1 -name 'mysql*-glibc*.tar*' |grep $my_v |awk -F'/' '{print $2}'`


#MySQL buffer_pool调优
MYSQL_INSTANCE_NUM=`ps aux |grep mysqld |grep sock |grep port |wc -l`
if [ $MYSQL_INSTANCE_NUM -eq 0 ];then
  export INNODB_BUFFER_POOL_SIZE=$[SERVER_TOTAL_MEM*75/100]
else
  export MYSQL_INSTANCE_NUM=$[MYSQL_INSTANCE_NUM+1]
  export INNODB_BUFFER_POOL_SIZE=$[SERVER_TOTAL_MEM/$MYSQL_INSTANCE_NUM*75/100]
fi

if [ $INNODB_BUFFER_POOL_SIZE -lt 1024 ];then
  export INNODB_BUFFER_POOL_SIZE=1024
fi

export INNODB_BUFFER_POOL_SIZE=$INNODB_BUFFER_POOL_SIZE"M"

#MySQL InnoDB read/write io_thread调优
CPU_NUM=`lscpu |grep -w 'CPU(s)' |head -1 |awk '{print $2}'`
export INNODB_READ_IO_THREADS=$CPU_NUM
export INNODB_WRITE_IO_THREADS=$CPU_NUM
export INNODB_THREAD_CONCURRENCY=$CPU_NUM*2

cp -r $BASEDIR/my_template.cnf /etc/mysql_$MYSQL_PORT.cnf

# 修改配置文件中关于性能参数
sed -i "s#\(innodb_buffer_pool_size=\).*#\1$INNODB_BUFFER_POOL_SIZE#g" /etc/mysql_$MYSQL_PORT.cnf
sed -i "s#\(innodb_read_io_threads=\).*#\1$INNODB_READ_IO_THREADS#g" /etc/mysql_$MYSQL_PORT.cnf
sed -i "s#\(innodb_write_io_threads=\).*#\1$INNODB_WRITE_IO_THREADS#g" /etc/mysql_$MYSQL_PORT.cnf
sed -i "s#\(innodb_thread_concurrency=\).*#\1$INNODB_THREAD_CONCURRENCY#g" /etc/mysql_$MYSQL_PORT.cnf

# 修改复制线程性能参数
sed -i "s#\(slave_parallel_type=\).*#\1LOGICAL_CLOCK#g" /etc/mysql_$MYSQL_PORT.cnf
sed -i "s#\(slave_parallel_workers=\).*#\1$CPU_NUM#g" /etc/mysql_$MYSQL_PORT.cnf
# 修改配置文件基础参数
sed -i "s#\(server_id=\).*#\1$SID#g" /etc/mysql_$MYSQL_PORT.cnf
sed -i "s#3306#$MYSQL_PORT#g" /etc/mysql_$MYSQL_PORT.cnf
sed -i "s#report_host=node1_ip#report_host=$LOCAL_IP#g" /etc/mysql_$MYSQL_PORT.cnf

[ $? -eq 0 ] && echo "Modify my.cnf.$MYSQL_PORT Successfully" >/dev/null || echo "Modify my.cnf.$MYSQL_PORT failed " 

    
if [[ $MY_V == "5.7" ]];then
    if [ ! -f $BASEDIR/mysql-5.7.28-linux-glibc2.12-x86_64.tar.gz ];then
        echo "No package found"
        exit 1
    fi
    tar xzf $BASEDIR/mysql-5.7.28-linux-glibc2.12-x86_64.tar.gz  -C /usr/local/
    if [ ! -d /usr/local/mysql ];then
        mv /usr/local/mysql-5.7.28-linux-glibc2.12-x86_64 /usr/local/mysql >/dev/null 2>&1
        chown -R mysql.mysql /usr/local/mysql
        ln -s /usr/local/mysql/bin/mysql* /usr/bin/ >/dev/null 2>&1
        cd /usr/local/mysql && ./bin/mysqld --defaults-file=/etc/mysql_$MYSQL_PORT.cnf --initialize-insecure
        sleep 10
        export ERROR_NUM=`cat /database/mysql$MYSQL_PORT/data/mysql$MYSQL_PORT.err |grep -w '[ERROR]' |wc -l`
        if [ $ERROR_NUM -gt 0 ];then 
        echo "Initialize error,check you initialize!!! " >>$OPERATE_LOG
        fi
        ./bin/mysqld_safe --defaults-file=/etc/mysql_$MYSQL_PORT.cnf --user=mysql & >>$OPERATE_LOG
    else
        cd /usr/local/mysql && ./bin/mysqld --defaults-file=/etc/mysql_$MYSQL_PORT.cnf --initialize-insecure
        sleep 10
        export ERROR_NUM=`cat /database/mysql$MYSQL_PORT/data/mysql$MYSQL_PORT.err |grep -w '[ERROR]' |wc -l`
        if [ $ERROR_NUM -gt 0 ];then 
        echo "Initialize error,check you initialize!!! " >>$OPERATE_LOG
        fi
        ./bin/mysqld_safe --defaults-file=/etc/mysql_$MYSQL_PORT.cnf --user=mysql & >>$OPERATE_LOG
        
    fi
elif [[ $MY_V == "8.0" ]]; then
    if [ ! -f $BASEDIR/mysql-8.0.16-linux-glibc2.12-x86_64.tar.xz ];then
        echo "No package found"
        exit 1
    fi
    tar xf $BASEDIR/mysql-8.0.16-linux-glibc2.12-x86_64.tar.xz  -C /usr/local/
    if [ ! -d /usr/local/mysql ];then
        mv /usr/local/mysql-8.0.16-linux-glibc2.12-x86_64 /usr/local/mysql >/dev/null 2>&1
        chown -R mysql.mysql /usr/local/mysql
        ln -s /usr/local/mysql/bin/mysql* /usr/bin/ >/dev/null 2>&1
        cd /usr/local/mysql && ./bin/mysqld --defaults-file=/etc/mysql_$MYSQL_PORT.cnf --initialize-insecure
        sleep 10
        export ERROR_NUM=`cat /database/mysql$MYSQL_PORT/data/mysql$MYSQL_PORT.err |grep -w '[ERROR]' |wc -l`
        if [ $ERROR_NUM -gt 0 ];then 
        echo "Initialize error,check you initialize!!! " >>$OPERATE_LOG
        fi
        ./bin/mysqld_safe --defaults-file=/etc/mysql_$MYSQL_PORT.cnf --user=mysql & >>$OPERATE_LOG
    else 
        cd /usr/local/mysql
        ./bin/mysqld --defaults-file=/etc/mysql_$MYSQL_PORT.cnf --initialize-insecure
        sleep 10
        export ERROR_NUM=`cat /database/mysql$MYSQL_PORT/data/mysql$MYSQL_PORT.err |grep -w '[ERROR]' |wc -l`
        if [ $ERROR_NUM -gt 0 ];then 
        echo "Initialize error,check you initialize!!! " >>$OPERATE_LOG
        fi
        ./bin/mysqld_safe --defaults-file=/etc/mysql_$MYSQL_PORT.cnf --user=mysql & >>$OPERATE_LOG
    fi
fi


#启动MySQL服务后连续连接实例30次，判断连接是否正常，正常连接后退出。
export TIME=1
while [ $TIME -lt 30 ]
do
   $MYSQL -uroot -S /tmp/mysql_$MYSQL_PORT.sock -e "select version();" >/dev/null 2>&1
   if [ $? -eq 0 ]
   then
       echo "Try $TIME times connect to MySQL-$MY_V instance successfully">>$OPERATE_LOG
       $MYSQL -uroot -S /tmp/mysql_$MYSQL_PORT.sock -e "grant all on *.* to root@localhost identified by 'root@qunje2020' with grant option; grant all on *.* to root@127.0.0.1 identified by 'root@qunje2020' with grant option;grant all on *.* to root@'%' identified by 'root@qunje2020' with grant option;" >/dev/null 2>&1
       break
   elif [ $TIME -gt 30 ]
   then
       echo "Try $TIME times connect to MySQL-$MY_V instance end in failure" >>$OPERATE_LOG
       break
   else
       sleep 1
       TIME=`expr $TIME + 1`
       echo "Try $TIME times connect MySQL-$MY_V instance ing ......" >>$OPERATE_LOG
  fi
done

export ENDTIME=`date +"%Y-%m-%d %H:%M:%S"`
export BEGIN_DATE=`date -d "$STARTTIME" +%s`
export END_DATE=`date -d "$ENDTIME" +%s`
export SPENDTIME=`expr $END_DATE - $BEGIN_DATE`
echo "AT $FORMAT_TIME: takes $SPENDTIME sec for install single instance for MySQL operation" >>$OPERATE_LOG


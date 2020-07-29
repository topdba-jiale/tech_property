#!/bin/bash
##################################
# File Name:install.sh
# Author:zhangjiale
# Version:V1.0
# Description:HotDB-Cloud components Configure 

#释放系统cache占用
function purge_sys_cache(){
CLEANMEMFLAG=0
echo 3 > /proc/sys/vm/drop_caches
if [ $? -eq 0 ]; then
    CLEANMEMFLAG=1
fi
}

#服务器总内存
function check_sys_mem(){
export TOTAL_MEM=$(free |sed -n '2p'|awk -F ' ' '{print $2}')
export SERVER_TOTAL_MEM=$(free|sed -n '2p'|awk -F ' ' '{print $4}')
export SERVER_TOTAL_MEM=$[SERVER_TOTAL_MEM/1024]

if [ $CLEANMEMFLAG -eq 1 ];then
    export SERVER_TOTAL_MEM=$[SERVER_TOTAL_MEM*90/100]
else
    export TOTAL_MEM=$[TOTAL_MEM*90/100]
    if [ $TOTAL_MEM -lt $SERVER_TOTAL_MEM ];then
	    export SERVER_TOTAL_MEM=$TOTAL_MEM
    fi
fi
echo "The free memery is "$SERVER_TOTAL_MEM"M"
}


case "$1" in
    mysql_single)
    sh ./install_mysql_single.sh;;
    mysql_mgr)
    sh ./install_mysql_mgr.sh
    sh ./ntpdate_service.sh;;
    mysql_mm_init)
    sh ./install_mysql_mm_1.sh;;
    mysql_mm_sync)
    sh ./install_mysql_mm_2.sh
    sh ./ntpdate_service.sh;;
    check)
    check_sys_mem;;
    *)
    echo "usage: $0 {mysql_single|mysql_mgr|mysql_mm_init|mysql_mm_sync|check}"
    exit 1
esac



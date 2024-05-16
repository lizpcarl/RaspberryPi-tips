#!/bin/bash
#/etc/storage/myautossh.sh
#author: LiZheping
#create date:2023-4-6
#modify date:2024-3-8
#feature:
#1.由于autossh的问题，反向代理中断时，无法有效的重连。
#2.检测autossh的运行状态，检测并启动autossh反向代理端口的连接。
#3.向指定服务器上报本机的ipv6地址，方便其它openVPN用户使用本机ipv6代理上网。
#注意要修改2组端口号、服务器地址
#在crontab -e中添加```* * * * * /etc/init.d/myraspssh.sh```

echo "hello,start check autossh",$PATH
#ps -ef|grep ssh|grep -v "sshd\|openssh\|myraspssh.sh\|grep"

sshPort=56788
motionPort=56789
#appPort=56790
serverHost=xyzbuy.cn
serverUser=myname
reportIPServer=http://www.xyzbuy.cn/ip.php
# testIpv4URL=http://4.ipw.cn
# testIpv6URL=http://6.ipw.cn
#testIpv6URL=http://speed.neu6.edu.cn
testIpv4URL=http://v4.ipv6-test.com/api/myip.php
testIpv6URL=http://v6.ipv6-test.com/api/myip.php

allsshCount=`ps -ef|grep ssh|grep -v "sshd\|openssh\|myraspssh.sh\|grep" -c`
autosshCount=`ps -ef|grep autossh|grep -v "sshd\|openssh\|myraspssh.sh\|grep" -c`
sshCount=$((allsshCount-autosshCount))
# echo $sshCount

motionCount=`ps -ef|grep motion|grep -v grep -c`

startAutoSSH(){
    # sudo /etc/init.d/autossh restart
    /usr/bin/autossh -M 10001:10002 -fNy -o "PubkeyAuthentication=yes" -o "StrictHostKeyChecking=false" -o "PasswordAuthentication=no" -o "ServerAliveInterval=60" -o "ServerAliveCountMax=3" -R $sshPort:localhost:22 -i /home/pi/.ssh/id_rsa ${serverUser}@$serverHost
    /usr/bin/autossh -M 10003:10004 -fNy -o "PubkeyAuthentication=yes" -o "StrictHostKeyChecking=false" -o "PasswordAuthentication=no" -o "ServerAliveInterval=60" -o "ServerAliveCountMax=3" -R $motionPort:localhost:8081 -i /home/pi/.ssh/id_rsa ${serverUser}@$serverHost
    #/usr/bin/autossh -M 10005:10006 -fNy -o "PubkeyAuthentication=yes" -o "StrictHostKeyChecking=false" -o "PasswordAuthentication=no" -o "ServerAliveInterval=60" -o "ServerAliveCountMax=3" -R $appPort:localhost:7001 -i /home/pi/.ssh/id_rsa ${serverUser}@$serverHost
}
stopAutoSSH(){
    ps -ef|grep 'autossh\/autossh'|awk '{print "sudo kill -9 "$2}'|sh
    ps -ef|grep '\/usr\/bin\/ssh '|awk '{print "sudo kill -9 "$2}'|sh
}

reportIpv6Interval(){
    if [ -n "$reportIPServer" ]
    then
        #ipv6Addr=`ifconfig |grep "inet6 addr:"|awk '{print $3}'|grep "240"`
        ipv6Addr=$(ip -6 addr list scope global | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)
        reportIpv6=`curl -s ${reportIPServer}/ip.php?myname=${HOSTNAME}\&ipv6Addr=$ipv6Addr`
        echo `date`, $reportIpv6 #>>$AUTOSSH_LOGFILE
    fi

    wanV6address=$(ip -6 addr list scope global $wanNicName | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)
    if [ -n "$wanV6address" ]
    then
        v6addrfile=~/.dynv6.addr6
        if [ -f ${v6addrfile} ]
        then
            uptimeSec=`cat /proc/uptime|awk '{printf "%d",$1}'`  #开机时间
            v6addrFileSec=`stat -c %Y ${v6addrfile}`   #文件产生的时间
            dateNowSec=`date +%s`
            if [ $(($dateNowSec - $v6addrFileSec)) -gt $uptimeSec ]
            then   #文件是此次开机之间产生的，需要删除旧文件；
                echo "rm ${v6addrfile}"
                rm ${v6addrfile}
            fi
        fi
    fi
}

ipv4headercode=`curl -Is $testIpv4URL| head -1 | cut -d " " -f2`
if [ "$ipv4headercode" == "200" ]
then
    reportIpv6Interval
    if [ $sshCount -ge 2 ]
    then
        echo `date`,"Detected $sshCount ssh process. Check Done!"
    else
        echo `date`,"Not found(sshCount=$sshCount) the ssh restart the autossh"
        stopAutoSSH
        # killall -9 autossh /usr/bin/ssh
        startAutoSSH
        if [ $? -ne 0 ]
        then
            echo `date`,"start autossh has some error, try ssh directly."
        fi
    fi
fi

if [ $motionCount -ne 1 ]
then
    ps -ef|grep 'motion'|grep -v grep|awk '{print "sudo kill -9 "$2}'|sh
    echo `date`,"not found the motion, start motion...$motionCount"
    sudo motion -c /etc/motion/motion.conf
    if [ $? -ne 0 ]
    then
        echo `date`,"start motion has some error."
    fi
fi
#!/bin/bash
#/etc/storage/myautossh.sh
#author: LiZheping
#create date:2023-4-6
#modify date:2023-5-5
#feature:
#1.由于autossh的问题，反向代理中断时，无法有效的重连。
#2.检测autossh的运行状态，检测并启动autossh反向代理端口的连接。
#3.向指定服务器上报本机的ipv6地址，方便其它openVPN用户使用本机ipv6代理上网。
#在crontab -e中添加```* * * * * /etc/init.d/myraspssh.sh```

echo "hello,start check autossh",$PATH
#ps -ef|grep ssh|grep -v "sshd\|openssh\|myraspssh.sh\|grep"

serverHost=xyzbuy.cn
serverUser=git
testIpv4URL=http://xyzbuy.cn

sshCount=`ps -ef|grep ssh|grep -v "sshd\|openssh\|myraspssh.sh\|grep" -c`
# echo $sshCount

motionCount=`ps -ef|grep motion|grep -v grep -c`

startAutoSSH(){
    # sudo /etc/init.d/autossh restart
    /usr/bin/autossh -M 10001:10002 -fNy -o "PubkeyAuthentication=yes" -o "StrictHostKeyChecking=false" -o "PasswordAuthentication=no" -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3" -R 56701:localhost:22 -i /home/pi/.ssh/id_rsa ${serverUser}@$serverHost
    /usr/bin/autossh -M 10003:10004 -fNy -o "PubkeyAuthentication=yes" -o "StrictHostKeyChecking=false" -o "PasswordAuthentication=no" -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3" -R 56781:localhost:8081 -i /home/pi/.ssh/id_rsa ${serverUser}@$serverHost
}
stopAutoSSH(){
    ps -ef|grep 'autossh\/autossh'|awk '{print "kill -9 "$2}'|sh
    ps -ef|grep '\/usr\/bin\/ssh '|awk '{print "kill -9 "$2}'|sh
}

ipv4headercode=`curl -Is $testIpv4URL| head -1 | cut -d " " -f2`
if [ "$ipv4headercode" != "200" ]
then
    exit 0
fi

if [ $sshCount -ne 4 ]
then
    echo `date`,"Detected $sshCount ssh process. Check Done!"
else
    echo `date`,"Not found the ssh restart the autossh"
    stopAutoSSH
    # killall -9 autossh /usr/bin/ssh
    startAutoSSH
    if [ $? -ne 0 ]
    then
        echo `date`,"start autossh has some error, try ssh directly."
    fi
fi

if [ $motionCount -ne 1 ]
then
    ps -ef|grep 'motion'|grep -v grep|awk '{print "kill -9 "$2}'|sh
	echo `date`,"not found the motion, start motion..."
	sudo motion -c /etc/motion/motion.conf
    if [ $? -ne 0 ]
    then
        echo `date`,"start motion has some error."
    fi
fi
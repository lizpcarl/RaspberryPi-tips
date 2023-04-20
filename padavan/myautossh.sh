#!/bin/bash
#/etc/storage/myautossh.sh
#author: LiZheping
#create date:2023-2-15
#modify date:2023-4-20
#feature:
#1.无tf卡时每次自动下载opkg，并使用opkg安装autossh、6relayd，实现反向代理注册，并启动ipv6中继模式
#2.检测autossh的运行状态，检测并启动autossh反向代理端口的连接。
#3.向指定服务器上报本机的ipv6地址，方便其它openVPN用户使用本机ipv6代理上网。
#注意要修改tfCardPath、2组端口号、服务器地址

echo "hello,start check autossh"

sshPort=56788
vpnPort=56789
tfCardPath=/media/U
wanNicName=eth2.2
serverHost=xyzbuy.cn
serverUser=myname
reportIPServer=http://www.xyzbuy.cn/ip.php
testIpv4URL=http://speed4.neu6.edu.cn
testIpv6URL=http://speed.neu6.edu.cn

if [ -f /etc/storage/known_hosts ]
then
    cp /etc/storage/known_hosts ~/.ssh/
fi

export PATH=$PATH:/opt/bin:/opt/sbin
#针对newifi3的特殊情况，未mount到正确的盘上。/dev/sda是USB接口的盘，存在；但/opt未mount，还是空的目录
optDir=`ls -A /opt`
if [[ -z "$optDir" && -b /dev/sda ]]
then
    if [ ! -d ${tfCardPath} ]   #/media/U目录不存在时才创建这个空目录
    then
        mkdir ${tfCardPath}
    fi
    uDiskDir=`ls -A ${tfCardPath}`
    if [ -z "$uDiskDir" ]   #/media/U目录为空时才mount
    then
        mount -t ext4 /dev/sda ${tfCardPath}
    fi
    if [ ! -d ${tfCardPath}/opt ]   #/media/U目录不存在时才创建这个空目录
    then
        mkdir ${tfCardPath}/opt
    fi
    if [ -d ${tfCardPath}/opt ]
    then
        mount ${tfCardPath}/opt /opt
    fi
fi

#检测/opt/bin目录是否存在，目录存在文件不存在时就补添加ssh链接；在tf卡映像文件丢失时，该目录就会变成不存在，也无法创建；
ExecSshPath=/usr/bin/ssh
if [ -d /opt/bin ]
then
    if [ ! -f /opt/bin/ssh ]
    then
        #/opt/bin/ssh是autossh程序默认调用的程序，所以在可能的情况下，都直接链接。
        ln -s /usr/bin/ssh /opt/bin/ssh
    fi
    ExecSshPath=/opt/bin/ssh
else
    echo "/opt/bin/ is not exist"
    ExecSshPath=/usr/bin/ssh
fi

sshCount=`ps |grep $ExecSshPath|grep -v grep -c`
#result=$(expr $optCount + $usrCount)
# echo $sshCount

clearLogFilePath(){
    export -n AUTOSSH_LOGFILE
    unset AUTOSSH_LOGFILE
}
configAutosshLogFile(){
    defaultLogPath=${tfCardPath}/autossh.log
    homeLogPath=~/autossh.log
    #未定义日志路径时才执行一次，后面有值就不需要调用了。
    if [ -z $AUTOSSH_LOGFILE ]
    then
        if [ -d $tfCardPath ]
        then
            export AUTOSSH_LOGFILE=$defaultLogPath
            if [ ! -f $defaultLogPath ]
            then
                touch -f $defaultLogPath
            fi
        else
            if [ -f $homeLogPath ]
            then
                logSize=`ls -l $homeLogPath |awk '{print $5}'`
                if [ $logSize -gt 100000 ]
                then
                    rm $homeLogPath
                    touch -f $homeLogPath
                fi
            fi
            #删除日志文件后重新创建日志文件，没有tf卡的系统，防止占用过多日志存储空间。
            export AUTOSSH_LOGFILE=$homeLogPath
        fi
    fi
    if [ -n $reportIPServer ]
    then
        #ipv6Addr=`ifconfig |grep "inet6 addr:"|awk '{print $3}'|grep "240"`
        ipv6Addr=$(ip -6 addr list scope global | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)
        reportIpv6=`curl -s ${reportIPServer}/ip.php?myname=${HOSTNAME}\&ipv6Addr=$ipv6Addr`
        echo `date`, $reportIpv6 >>$AUTOSSH_LOGFILE
    fi
}
firewallPassIpv6(){
    ip6tables -F
    ip6tables -X
    ip6tables -P INPUT ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
}
startMySSH(){
    echo "start myautossh"
    $ExecSshPath -fNy -K 1 -o "ExitOnForwardFailure=yes" -R $sshPort:localhost:22 -i /etc/storage/id_rsa ${serverUser}@$serverHost
    $ExecSshPath -fNy -K 1 -o "ExitOnForwardFailure=yes" -R $vpnPort:localhost:1194 -i /etc/storage/id_rsa ${serverUser}@$serverHost
}
startAutoSSH(){
    echo "start autossh"
    /etc/storage/autossh -M 10001:10002 -fNy -o "PubkeyAuthentication=yes" -o "StrictHostKeyChecking=false" -o "PasswordAuthentication=no" -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3" -R $sshPort:localhost:22 -i /etc/storage/id_rsa ${serverUser}@$serverHost
    /etc/storage/autossh -M 10003:10004 -fNy -o "PubkeyAuthentication=yes" -o "StrictHostKeyChecking=false" -o "PasswordAuthentication=no" -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3" -R $vpnPort:localhost:1194 -i /etc/storage/id_rsa ${serverUser}@$serverHost
}

#存在问题:对于无tf卡的路由器，可能存在opkg、autossh程序丢失，此时就要转为直接调用系统的/usr/bin/ssh
#但/usr/bin/ssh在与服务器断开后，并不能自行结束进程，导致$sshCount有值，但实际已经断开，又无法重启。
#if [[ $optCount -gt 1 || $usrCount -gt 1 ]]
configAutosshLogFile
if [ $sshCount -gt 1 ]
then
    echo `date`,"Detected $sshCount ssh(${ExecSshPath}) process. Check Done!">>$AUTOSSH_LOGFILE
else
    echo `date`,"Not found the ssh(${ExecSshPath})! restart the autossh">>$AUTOSSH_LOGFILE
    killall -9 autossh ssh
    startAutoSSH
    if [ $? -ne 0 ]
    then
        echo `date`,"start autossh has some error, try ssh directly.">>$AUTOSSH_LOGFILE
        clearLogFilePath
        startMySSH
    fi
fi

if [ -x "`which 6relayd`" ]
then
    wanV6address=$(ip -6 addr list scope global $wanNicName | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)
    if [ -n $wanV6address ]
    then
        device=br0
        lanV6address=$(ip -6 addr list scope global $device | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)
        if [ -z $lanV6address ]
        then
            6relayd -d -A $wanNicName br0
            echo `date`,"start 6relayd for ipv6 in LAN.">>$AUTOSSH_LOGFILE
        else
            relaydCount=`ps |grep 6relayd|grep -v grep -c`
            ipv4headercode=`curl -Is $testIpv4URL| head -1 | cut -d " " -f2`
            ipv6headercode=`curl -Is $testIpv6URL| head -1 | cut -d " " -f2`
            if [ $relaydCount -lt 1 ] || [ "$ipv4headercode" = "200" -a "$ipv6headercode" != "200" ]
            then #ipv6网络偶尔中断不通：存在ipv6地址，但v6中继功能失效，v4通而v6不通，此时就再启动中继
                killall -9 6relayd
                6relayd -d -A $wanNicName br0
                echo `date`,"start 6relayd since relay disconnected.">>$AUTOSSH_LOGFILE
            fi
        fi
        firewallPassIpv6
    fi
else #针对无tf卡opkg、autossh、6relayd在重启后丢失的情况，丢失后会重新安装一遍
    ipv6headercode=`curl -Is $testIpv6URL | head -1 | cut -d " " -f2`
    if [ "$ipv6headercode" = "200" ]  #网络畅通的情况下才启动opkg安装
    then
        if [ ! -x "`which opkg`" ]
        then
            echo `date`,"Waitting opt install opkg">>$AUTOSSH_LOGFILE
            wget -O - http://bin.entware.net/mipselsf-k3.4/installer/generic.sh | /bin/sh
        fi
        if ! [ -x "`which 6relayd`" ]
        then
            echo `date`,"start install 6relayd autossh">>$AUTOSSH_LOGFILE
            opkg update
            opkg install 6relayd autossh
            echo `date`,"6relayd has been installed">>$AUTOSSH_LOGFILE
            if [ -f /opt/sbin/autossh ]
            then
                if [ ! -f /etc/storage/autossh ]
                then
                    ln -s /opt/sbin/autossh /etc/storage/autossh
                fi
            fi
        fi
    fi
fi
#!/bin/bash
#/etc/storage/myautossh.sh
#author: LiZheping
#create date:2023-2-15
#modify date:2024-5-16
#feature:
#1.无tf卡时每次自动下载opkg，并使用opkg安装autossh、6relayd，实现反向代理注册，并启动ipv6中继模式
#2.检测autossh的运行状态，检测并启动autossh反向代理端口的连接。
#3.向指定服务器上报本机的ipv6地址，方便其它openVPN用户使用本机ipv6代理上网。
#注意要修改2组端口号、服务器地址
#在crontab -e中添加“*/2 * * * * /etc/storage/myautossh.sh”

echo "hello,start check autossh"

sshPort=56788
vpnPort=56789

#tf卡或u盘的物理文件路径，一般为：/dev/sda
tfCardSourcePath=/dev/sda
tfCardDestPath=/media/U
wanNicName=eth2.2
serverHost=xyzbuy.cn
serverUser=myName
reportIPServer=http://www.xyzbuy.cn/ip.php
# testIpv4URL=http://4.ipw.cn
# testIpv6URL=http://6.ipw.cn
#testIpv6URL=http://speed.neu6.edu.cn
testIpv4URL=http://v4.ipv6-test.com/api/myip.php
testIpv6URL=http://v6.ipv6-test.com/api/myip.php

defaultLogPath=${tfCardDestPath}/autossh.log
homeLogPath=~/autossh.log
autosshLogFilePath=$defaultLogPath
if [ ! -f $defaultLogPath ]
then
    if [ ! -f $homeLogPath ]
    then
        touch -f $homeLogPath
    fi
    autosshLogFilePath=$homeLogPath
fi

#个别情况为/dev/mmcblk0，就直接修改这个配置项
if [ -b /dev/mmcblk0 ]
then
   tfCardSourcePath=/dev/mmcblk0
   echo `date`, "tfCardSourcePath configured to $tfCardSourcePath">>$autosshLogFilePath
fi

firewallPassIpv6(){
    ip6tables -F
    ip6tables -X
    ip6tables -P INPUT ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
}

wanV6address=$(ip -6 addr list scope global $wanNicName | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)
if [ -n "$wanV6address" ]
then
    v6addrfile=~/.dynv6.addr6
    if [ -f ${v6addrfile} ]
    then
        uptimeSec=`cat /proc/uptime|awk '{printf "%d",$1}'`  #开机时间
        v6addrFileSec=`stat -c %Y ${v6addrfile}`   #文件产生的时间
        dateNowSec=`date +%s`
        if [ $(($dateNowSec - $v6addrFileSec + 300)) -gt $uptimeSec ]
        then   #说明刚开机不久，同时允许穿透防火墙
            firewallPassIpv6
        fi
        if [ $(($dateNowSec - $v6addrFileSec)) -gt $uptimeSec ]
        then   #文件是此次开机之间产生的，需要删除旧文件；
            echo `date`, "rm ${v6addrfile}">>$autosshLogFilePath
            rm ${v6addrfile}
        fi
    else
        firewallPassIpv6  #不存在v6的文件，说明是刚开机不久，同时允许穿透防火墙
    fi
fi

if [ -f /etc/storage/known_hosts ]
then
    cp /etc/storage/known_hosts ~/.ssh/
fi

export PATH=$PATH:/opt/bin:/opt/sbin

optMountFromSDCard(){
    if [ ! -d ${tfCardDestPath}/opt ]   #/media/U/opt目录不存在时才创建这个空目录
    then
        echo `date`, "mkdir ${tfCardDestPath}/opt">>$autosshLogFilePath
        mkdir ${tfCardDestPath}/opt
        sleep 1
    fi
    if [ -d ${tfCardDestPath}/opt ]
    then
        isOldOptMounted=`df -h|grep /opt|awk 'index($1,"/dev/"){print $1}'|wc -l`
        if [ $isOldOptMounted -lt 1 ] #仅mount一次，如果发现/opt已经与2个以上/dev设备mounted，就不做mount动作了。
        then
            if [ -f ${tfCardDestPath}/opt/o_p_t.img ]
            then #对于R6220直接挂载硬盘，硬盘没有ext4的分区(NTFS或FAT)，此时挂载映射文件
                echo `date`, "mount -t ext4 ${tfCardDestPath}/opt/o_p_t.img /opt">>$autosshLogFilePath
                mount -t ext4 ${tfCardDestPath}/opt/o_p_t.img /opt
            else
                echo `date`, "mount ${tfCardDestPath}/opt /opt">>$autosshLogFilePath
                mount ${tfCardDestPath}/opt /opt
            fi
        else
            echo `date`, "${tfCardDestPath}/opt has already mounted(${isOldOptMounted}) to /opt">>$autosshLogFilePath
        fi
    fi
}
if [ -b "${tfCardSourcePath}" ]  #已安装tf卡的路由器，块设备文件存在
then
    if [ ! -d ${tfCardDestPath} ]   #/media/U目录不存在时才创建这个空目录
    then
        echo `date`, "mkdir ${tfCardDestPath}">>$autosshLogFilePath
        mkdir ${tfCardDestPath}
        sleep 1
    fi
    uDiskDir=`ls -A ${tfCardDestPath}`
    if [ -z "$uDiskDir" ]   #/media/U目录为空时才mount
    then
        echo `date`, "mount -t ext4 ${tfCardSourcePath} ${tfCardDestPath}">>$autosshLogFilePath
        mount -t ext4 ${tfCardSourcePath} ${tfCardDestPath}
        sleep 1
        isOldOptDir=`df -h|grep /opt|awk '$1=="tmpfs"{print $1}'` #首次开机使用系统默认的/opt映射到了tmpfs上
        #还有某种情况下，/opt被mount到了/dev/loop0这个块文件。
        if [ -n "$isOldOptDir" ] #卸载系统默认的/opt映射，更换为直接使用tf卡中的opt映射
        then
            echo `date`, "umount /opt">>$autosshLogFilePath
            umount /opt
            sleep 1
        fi
        optMountFromSDCard
        firewallPassIpv6  #首次登录系统才执行一次“允许穿透防火墙”
    fi
fi
#针对newifi3的特殊情况，未mount到正确的盘上。/dev/sda是USB接口的盘，存在；但/opt未mount，还是空的目录
optDir=`ls -A /opt`
if [[ -z "$optDir" && -b "${tfCardSourcePath}" ]]
then
    optMountFromSDCard
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
    if [ -f /opt/bin/ssh ]
    then
        ExecSshPath=/opt/bin/ssh
    fi
else
    echo `date`, "/opt/bin/ is not exist">>$autosshLogFilePath
    ExecSshPath=/usr/bin/ssh
fi

sshCount=`ps |grep $ExecSshPath|grep -v grep -c`
#result=$(expr $optCount + $usrCount)
# echo `date`, $sshCount>>$autosshLogFilePath

clearLogFilePath(){
    export -n AUTOSSH_LOGFILE
    unset AUTOSSH_LOGFILE
}
configAutosshLogFile(){
    #未定义日志路径时才执行一次，后面有值就不需要调用了。
    if [ -z "$AUTOSSH_LOGFILE" ]
    then
        if [ -d $tfCardDestPath ]
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
    if [ -n "$reportIPServer" ]
    then
        #ipv6Addr=`ifconfig |grep "inet6 addr:"|awk '{print $3}'|grep "240"`
        ipv6Addr=$(ip -6 addr list scope global | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)
        reportIpv6=`curl -s ${reportIPServer}/ip.php?myname=${HOSTNAME}\&ipv6Addr=$ipv6Addr`
        echo `date`, "return IP & port:$reportIpv6">>$AUTOSSH_LOGFILE
    fi
}
startMySSH(){
    echo `date`,"start myssh">>$autosshLogFilePath
    $ExecSshPath -fNy -K 1 -o "ExitOnForwardFailure=yes" -R $sshPort:localhost:22 -i /etc/storage/id_rsa ${serverUser}@$serverHost
    $ExecSshPath -fNy -K 1 -o "ExitOnForwardFailure=yes" -R $vpnPort:localhost:1194 -i /etc/storage/id_rsa ${serverUser}@$serverHost
}
startAutoSSH(){
    echo `date`,"start autossh">>$AUTOSSH_LOGFILE
    /etc/storage/autossh -M 10001:10002 -fNy -o "PubkeyAuthentication=yes" -o "StrictHostKeyChecking=false" -o "PasswordAuthentication=no" -o "ServerAliveInterval=60" -o "ServerAliveCountMax=3" -R $sshPort:localhost:22 -i /etc/storage/id_rsa ${serverUser}@$serverHost
    /etc/storage/autossh -M 10003:10004 -fNy -o "PubkeyAuthentication=yes" -o "StrictHostKeyChecking=false" -o "PasswordAuthentication=no" -o "ServerAliveInterval=60" -o "ServerAliveCountMax=3" -R $vpnPort:localhost:1194 -i /etc/storage/id_rsa ${serverUser}@$serverHost
}

#存在问题:对于无tf卡的路由器，可能存在opkg、autossh程序丢失，此时就要转为直接调用系统的/usr/bin/ssh
#但/usr/bin/ssh在与服务器断开后，并不能自行结束进程，导致$sshCount有值，但实际已经断开，又无法重启。
#if [[ $optCount -gt 1 || $usrCount -gt 1 ]]
configAutosshLogFile
if [ $sshCount -gt 1 ]
then
    echo `date`,"Detected $sshCount ssh(${ExecSshPath}) process. Check Done!">>$AUTOSSH_LOGFILE
else
    echo `date`,"Not found the running ssh(${ExecSshPath})! restart the autossh">>$AUTOSSH_LOGFILE
    killall -9 autossh ssh
    startAutoSSH
    if [ $? -ne 0 ]
    then
        echo `date`,"start autossh has some error ($?), try ssh directly.">>$autosshLogFilePath
        clearLogFilePath
        startMySSH
        configAutosshLogFile
    fi
fi

#opkg不存在时，自动安装opkg
if [ ! -x "`which opkg`" ]
then
    echo `date`,"Waitting opt install opkg">>$AUTOSSH_LOGFILE
    wget -O - http://bin.entware.net/mipselsf-k3.4/installer/generic.sh | /bin/sh
fi
#autossh不存在时，就自动安装autossh
if [[ -x "`which opkg`" && ! -x "`which autossh`" ]]
then
    echo `date`,"start install autossh">>$AUTOSSH_LOGFILE
    opkg update
    opkg install autossh
    echo `date`,"autossh has been installed">>$AUTOSSH_LOGFILE
    if [ -f /opt/sbin/autossh ]
    then
        if [ ! -f /etc/storage/autossh ]
        then
            ln -s /opt/sbin/autossh /etc/storage/autossh
        fi
    fi
fi

#以下为自动安装ipv6中继(6relayd)
if [ $wanNicName != "ppp0" ] # 拨号路由器自动ipv6路由，不需要6relayd做ipv6中继了。
then
    if [ -x "`which 6relayd`" ]
    then
        if [ -n "$wanV6address" ] # 外网卡存在ipv6地址才处理
        then
            device=br0
            lanV6address=$(ip -6 addr list scope global $device | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | head -n 1)
            if [ -z "$lanV6address" ] # 内网卡没有ipv6地址
            then
                6relayd -d -A $wanNicName $device
                echo `date`,"start 6relayd for ipv6 in LAN.">>$AUTOSSH_LOGFILE
                firewallPassIpv6
            else
                relaydCount=`ps |grep 6relayd|grep -v grep -c`
                ipv4headercode=`curl -Is $testIpv4URL| head -1 | cut -d " " -f2`
                ipv6headercode=`curl -Is $testIpv6URL| head -1 | cut -d " " -f2`
                if [[ $relaydCount -lt 1 || $ipv4headercode == 200 -a $ipv6headercode != 200 ]]
                then #ipv6网络偶尔中断不通：存在ipv6地址，但v6中继功能失效，v4通而v6不通，此时就再启动中继
                    if [ $relaydCount -gt 1 ]  # >1时才kill
                    then
                        killall -9 6relayd
                        echo `date`,"killall -9 6relayd.(relaydCount=$relaydCount)">>$AUTOSSH_LOGFILE
                    fi
                    if [ $relaydCount -lt 1 ]
                    then
                        6relayd -d -A $wanNicName $device
                        echo `date`,"6relayd -d -A $wanNicName $device.since ipv6 disconnected.">>$AUTOSSH_LOGFILE
                        firewallPassIpv6
                    fi
                fi
            fi
        fi
    else #针对无tf卡opkg、autossh、6relayd在重启后丢失的情况，丢失后会重新安装一遍
        ipv6headercode=`curl -Is $testIpv6URL | head -1 | cut -d " " -f2`
        if [ "$ipv6headercode" = "200" ]  #ipv6网络畅通的情况下才启动opkg安装6relayd
        then
            if [[ -x "`which opkg`" && ! -x "`which 6relayd`" ]]
            then
                echo `date`,"start install 6relayd">>$AUTOSSH_LOGFILE
                opkg update
                opkg install 6relayd
                echo `date`,"6relayd has been installed">>$AUTOSSH_LOGFILE
            fi
        fi
    fi

    #"非pppoe拨号"情况下，路由器连光猫，光猫因某种原因重启 or 运营商间歇(可能每天)重置网络导致wan口ipv6地址变更
    #部分光猫端口bug:保持了旧的ipv6地址，也下发了新的ipv6地址，导致eth2.2/eth3上有多个ipv6地址，此时（持续1小时左右）需要手动去重。
    #通过类似于“curl 6.ipw.cn”的方法查找当前有效地址，使用“ifconfig eth2.2 del 240e:381:6a14:b300:2276:93ff:fe4f:db0d/64”删除过期的地址。
    if [ -n "$wanV6address" ]
    then
        validIpv6Addr=$(curl $testIpv6URL)
        if [ -n "$validIpv6Addr" ]
        then
            wanV6List=$(ip -6 addr list scope global $wanNicName | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:\/]\+\).*/\1/p') #output: 240e:381:6a1d:a400:2276:93ff:fe4f:db0d/64
            #wanV6List=$(ip -6 addr list scope global $wanNicName | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p') #output:240e:381:6a1d:a400:2276:93ff:fe4f:db0d
            listTotal=$(ip -6 addr list scope global $wanNicName | grep -v " fd" | sed -n 's/.*inet6 \([0-9a-f:]\+\).*/\1/p' | wc -l)
            delNumber=0
            if [ $listTotal -gt 1 ] #至少保留一个ipv6地址不删除
            then
                echo "Server return my current valid ipv6 address:$validIpv6Addr, global scope ipv6,total is:$listTotal">>$AUTOSSH_LOGFILE
                for line in $wanV6List; do
                    echo "handle line:$line"
                    if [ "$validIpv6Addr" != "${line%/*}" ]
                    then
                        delNumber=$((delNumber+1))
                        echo "find not equal: $validIpv6Addr != $line, delNumber=$delNumber"
                        echo `date`,"execute delete ipv6: ifconfig $wanNicName del $line">>$AUTOSSH_LOGFILE
                        ifconfig $wanNicName del $line
                        #确保仅有一个公网ipv6地址，对多余的进行删除
                    fi
                    if [ $((listTotal-delNumber)) -le 1 ]
                    then
                        echo "leave one ipv6, need break;"
                        break;
                    fi
                done
            fi
        fi
    fi
fi
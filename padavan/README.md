#Padavan路由器的VPN搭建
利用Padavan路由器搭建VPN的ipv6代理，启用ipv6中继模式，本目录的2个sh文件是自动启用ipv6中继并连接指定的私有服务器进行反向代理的过程。

##配置“老毛子Padavan”类的路由器（youku yk1、小米路由器3），操作步骤如下：
1.设备刷机的新系统，或者旧系统恢复出厂设置有2步，进入“系统管理 - 恢复/导出/上传设置”，按以下顺序“恢复出厂模式”：“路由器内部存储[脚本文件] (/etc/storage)”、“路由器设置 (NVRAM)”。

2.“系统管理 - 系统设置”修改这几项：设备名称、管理员账号、新密码; “应用本页设置”。

3.“系统管理 - 服务”，“启用 SSH 服务:”-->是,“允许远程端口转发 (GatewayPorts):”-->是。

4.“内部网络 (LAN) - 内网设置”，配置“IP 地址:”。

5.“外部网络 (WAN) - 外网设置”，启用“响应外部 Ping”

6.“外部网络 (WAN) - IPv6 设置”：
```
IPv6 连接类型:Native DHCPv6
IPv6 硬件加速：   Offload for LAN/WLAN
获取 IPv6 外网地址:   Stateless: RA
启用隐私扩展 (RFC 4941)   否 (*)
自动获取 IPv6 DNS: 是
通过 DHCPv6 获取内网 IPv6 地址: 是
启用 LAN 路由器通告: 是
启用 LAN DHCPv6 服务器: 否
```

7.“无线网络 - 通用设置 (2.4GHz)”，设置“无线 SSID:”、“WPA-PSK 密钥:”

8.“自定义设置 - 脚本”-->“在路由器启动后执行:”，在yk_1的7620上，是eth2.2，则改成如下：
```
#启动ipv6网络
modprobe ip6table_mangle
ebtables -t broute -A BROUTING -p ! ipv6 -j DROP -i eth2.2
#brctl addif br0 eth2.2   #本行要注释掉才能正常ping通ipv6地址，这是在yk1上的特殊情况。
#brctl delif br0 eth2.2
#6relayd -d -A eth2.2 br0 #通过脚本判断WAN有ipv6时，启动LAN穿透ipv6，已经改到myautossh.sh脚本中了。
```

##接下来是命令行安装
1.通过opkg安装autossh(使用myautossh.sh后，本段可忽略)
接下来是命令行安装opkg相关包的方法，如果没有tf卡，就不需要安装这些了，因为安装后重启就不见了。
老毛子(Padavan)路由器安装okpg: opkg.sh
wget -O - http://bin.entware.net/mipselsf-k3.4/installer/generic.sh | /bin/sh
升级opkg: opkg update
安装tmux: opkg install tmux
安装autossh：opkg install autossh
安装6relayd：opkg install 6relayd

2.链接autossh.(使用myautossh.sh后，本段可忽略)
```
# which autossh
/opt/sbin/autossh
ln -s /opt/sbin/autossh /etc/storage/autossh
```
找到这个autossh的安装路径，链接到/etc/storage下，也可以不链接，直接使用/opt/sbin/autossh。
对于无tf卡的情况，即使把autossh复制到/etc/storage下，重启也会无法启动，相关的依赖都会丢失。

3.复制文件到/etc/storage/
该目录下需要放入以下几个文件：
id_rsa 805
known_hosts 346
dynv6.sh
myautossh.sh
其中，id_rsa是利用dropbearkey生成的私钥；know_hosts是访问过服务器后，本地保存的服务端公钥；myautossh.sh这个是定时执行的检测脚本，进行连接和上报本地ipv6地址，启动ipv6中继“6relayd -d -A eth2.2 br0”；需要改成可执行程序。
[/etc/storage]# chmod +x myautossh.sh

4.在crontab加入myautossh.sh脚本。
[/etc/storage]# crontab -e
[/etc/storage]# crontab -l
```
*/2 * * * * /etc/storage/myautossh.sh
*/5 * * * * token=myToken_with_dynv6 /etc/storage/dynv6.sh myzone.v6.rocks eth2.2
```
作用分别是：维持ssh连接；更新对应域名的ipv4/ipv6的地址。
如果该路由器用作光猫拨号，它的eth2.2就没有ipv6地址，拨号时ipv6地址在ppp0这个接口名上，使用"ppp0"或者"br0"(LAN接口名)替代即可

5.在“系统管理 - 恢复/导出/上传设置”-->
“保存 /etc/storage/ 内容到闪存”、“保存 NVRAM 内容到闪存”-->2个都要“提交”，这样才能保存相应的脚本及可执行程序。对于无tf卡的，不需要点，否则因存储空间不够可能产生异常，丢失很多配置。

6.安装tf卡的注意事项，盘的卷标会影响路径名，一般设置卷标为U，就会mount到/media/U/;如果不设置卷标，默认的目录为“/media/AiCard_01/”。
如果tf卡为ntfs或者fat32，由会产生一个2g的映像文件存储/opt的内容，文件为/media/U/opt/o_p_t.img；
如果tf卡能在diskGenius下格式化为ext4，这种最合适，相关文件直接放在/media/U/opt/目录下，占用空间很小；
如果一张tf卡有几个分区，以卷标的字母顺序使用第一个分区的映像文件。


##IPv6与中继相关的配置
“外部网络 (WAN) - IPv6 设置”
“获取 IPv6 外网地址:   Stateless: RA”
---使用主从模式，这种情况路由器的WAN会获取到ipv6，但不会转到各设备上，需要启动6relayd进行ipv6中继；
“获取 IPv6 外网地址:   Stateful: DHCPv6 IA-NA”
---使用穿透模式，这种情况下路由器的WAN没有ipv6地址，直接把上级路由器的ipv6分发到各设备上，下层获取global的ipv6地址。
ipv4的中继设置很简单，只需要关闭DHCP v4功能，再将接入网线插入LAN口上即可。
关闭DHCP时请把路由器的ip固定到上层路由器网络中的一个内网ip上，同时上层的路由器上也给该MAC绑定该IP，这样后续要管理时，就可以直接访问了，如果有USB存储设备，也可以在同一层网络中被访问到。

##“VPN 客户端”设置时，此处是重点，否则无法使用：
使用客户端模式时，“VPN 服务器”必须先关闭，否则连接后无法上网；
限制来自于 VPN 服务器的访问:   否(站点到站点)，使用 NAT ；
从 VPN 服务器获取 DNS:    否 / 替换当前列表  这两项均可；



-----------------------------------------------------------
##常见问题：
###1.私钥创建问题
openwrt作为一个常用的Linux系统，常常在嵌入式Linux中被使用到，最常用的就是路由器环境，有时我们经常要通过openwrt远程连接其他的Linux系统，但是常规的openssh生成的私钥，无法被openwrt读取，会提示ssh: Exited: String too long
原因是openwrt所使用的ssh客户端是dropbear，这个ssh客户端属于轻量级ssh客户端，所需要的格式与openssh的私钥格式不同。
因此只能使用dropbear单独创建一个私钥，创建方法如下：
dropbearkey -t rsa -f .ssh/id_rsa > id_rsa.pub
当执行完这个命令后，只需要将id_rsa.pub内容复制到需要被登录的linux的$home/.ssh/authorized_keys中去即可。
登录的话可以直接使用命令：
ssh -i .ssh/id_rsa root@192.168.56.101
ssh -R 50733:localhost:22 -i /home/root/.ssh/id_rsa git@120.77.149.50
启动ssh反向代理  #ssh -R 50733:localhost:22 -i /etc/storage/id_rsa git@120.77.149.50
#ssh -R 50733:localhost:22 -i /media/AiCard_01/.ssh/id_rsa git@120.77.149.50
杀ssh反向代理进程
```
ps |grep "ssh"|grep "id_rsa"|awk '{print "kill -9 "$1}'|sh
```

###2.特殊情况下，/opt为中读，导致无法安装opkg的问题
```
Warning: Folder /opt exists!
mkdir: can't create directory '/opt/bin': Read-only file system
mkdir: can't create directory '/opt/etc': Read-only file system
mkdir: can't create directory '/opt/lib/': Read-only file system
mkdir: can't create directory '/opt/tmp': Read-only file system
mkdir: can't create directory '/opt/var/': Read-only file system
...
# mkdir /opt/bin
mkdir: can't create directory '/opt/bin': Read-only file system
```
使用newifi3折腾许久，无tf卡有fat32格式的U盘，最后使用了一个mount解决了：
```
# mount /dev/sda /media/U
# mkdir /media/U/opt
# mount /media/U/opt /opt
```

###3.挂载的磁盘是fat32分区格式，不支持链接
```
# opkg install autossh
Package autossh (1.4g-4) installed in root is up to date.
Configuring entware-opt.
ln: /opt/sbin/ifconfig: Operation not permitted
ln: /opt/sbin/route: Operation not permitted
```
解决方案，格式化fat32的U盘为ext4：
```
# fdisk /dev/sda
# mkfs.ext4 /dev/sda
```

-----------------------------------------------------------

《极路由之SSH反向代理》
https://spaces.ac.cn/archives/3604


https://www.right.com.cn/FORUM/thread-4112503-1-1.html
《老毛子padavan的IPV6设置教程》，该文参考性高，

[Padavan固件下载](https://opt.cn2qq.com/padavan/)
[breed下载](https://breed.hackpascal.net/)
-----------------------------------------------------------

# [RaspberryPi tips](https://github.com/lizpcarl/RaspberryPi-tips)
record some usage for RaspberryPi; For example,  Camera, motion, autossh, etc.

##Introduce
使用了多个openwrt路由器，包括 TP-LINK TL-WDR3500 v1(Atheros AR9344 rev 2 560MHz,128M ram,8M rom)、NEXX乐携 WT3020(MT7620N 580Mhz，64M RAM，8M rom)、路由宝1s(7620A 580MHz,128M DDR2,32M rom)、新路由3(newifi3 MediaTek MT7621A ver 1,CPU: 880MHz, DDR: 1066MHz，双核880MHz四线程, 512MB DDR3,32M rom)、Phicomm K2(MediaTek MT7620A ver 2 580MHz,64MB DDR2,8M rom)；

### 1.openWrt的常用命令
1. 查看当前ip分配情况：cat /tmp/dhcp.leases
2. 网卡搜索SSID：iwinfo wlan0(1) scan (Linux下是 sudo iw wlan0 scan)
3. 网卡信息查询：iw wlan0 info
3. wifidog状态查看：/etc/init.d/wifidog status


### TL-WDR3500上wifidog的安装包
1. opkg update && opkg install wifidog
2. 由于是AR9344的芯片，需要直接安装wifidog_1.3.0-1_ar71xx.ipk
3. 再安装auth模块：luci-mod-wifidogauth_0.12.ipk

### 代码修改对应
1. 配置文件：vi /etc/wifidog.conf
2. 登录页面：vi /usr/lib/lua/luci/view/wifidog/wdas_login.htm
3. 规则说明页：
http://192.168.9.1/luci-static/resources/res/agreements.html
-->
/www/luci-static/resources/res/agreements.html
4. 其htm页面位于/usr/lib/lua/luci/view/wifidog/文件夹下，CSS等资源文件位于/www/wifidog/文件夹


### 设置无线中继的方式
1. openwrt: 打开wireless菜单，scan上级SSID(最好为5G)，设置为wwan，client；再在2.4G的接口上创建Access Point；
2. 老毛子Padavan固件：无线网络 - 无线桥接 (5GHz)-->无线 AP 工作模式:	AP-Client+AP，角色：LAN bridge(相当于交换机)；搜寻上级SSID以及填入密码；“内部网络 (LAN) - DHCP 服务器”必需关闭；(下载地址：http://p4davan.80x86.io/)




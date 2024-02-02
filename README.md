# [RaspberryPi tips](https://github.com/lizpcarl/RaspberryPi-tips)
record some usage for RaspberryPi; For example,  Camera, motion, autossh, etc.

##Introduction
从2014年到现在买了5个不同型号的树莓派了，大部分用来安装motion后做远程摄像头使用。本project用来记录常用的一些命令和操作方法。

##Tips
### 1.树莓派重装后，需要安装的主要软件
##### 1. sudo apt-get install  vim autossh motion nodejs golang arduino fonts-inconsolata omxplayer vlc

##### 2. 安装好autossh之后，可以把本project的etc-initd目录修改到RaspberryPi上对应的/etc/init.d/autossh文件。

##### 3. 修改crontab -e的默认编辑器
update-alternatives --config editor
选择第3项vim.basic即可

##### 4. 取消ll项的注释，让ll生效 vim /home/pi/.bashrc

##### 5. 摄像头驱动配置
vim /etc/modules
bcm2835-v4l2
另外在配置中打开Camera:sudo raspi-config，在Interfacing options中置Camera为enable；

##### 6. sudo cp autossh /etc/init.d/.
修改/etc/init.d/autossh中的端口参数配置

##### 7. 修改motion配置文件,
sudo vim /etc/motion/motion.conf
修改daemon=on,设置rotate及width、height，brightness,contrast,saturation,hue, stream_localhost, lightswitch, 
target_dir /var/lib/motion --> /var/www/motion(先sudo mkdir -p /var/www/motion)

##### 8. 配置自启动项
sudo update-rc.d autossh defaults
sudo update-rc.d motion defaults

##### 9. 生成RTSP视频流
raspivid -o - -t 0 -w 800 -h 600 -fps 25|cvlc -vvv stream:///dev/stdin --sout '#standard{access=http,mux=ts,dst=:8081}' :demux=h264 http://mycam.xyzbuy.cn

### 2.常用的crontab任务列表，一台与openWrt路由器（带wifidog认证功能）直接相连的RaspberryPi，
*本地IP上报、默认路由选择（删除有线网卡的默认网关）、定时重连autossh、夜间关闭摄像头功能、定时清理录像文件释放空间*

```
pi@raspberrypi2B:~ $ crontab -l
0 * * * * curl -A "heartbeat from RaspberryPi2B+gitsource to test IP" -I http://xyzbuy.cn
#0 * * * * sudo route del default gw TPopenWrt.lan 
1 7 * * * /etc/init.d/autossh stop  
2 7 * * * /etc/init.d/autossh start
39 19 * * * sudo killall -9 motion
0 7-19 * * * /home/pi/restartmotion.sh
3 7 * * * find /var/www/motion -ctime +7|xargs sudo rm -rf
```
或者
```
0 * * * * curl -A "heartbeat from RaspberryPi3rs to test IP" -I http://xyzbuy.cn
39 6 * * * /etc/init.d/autossh start
39 19 * * * sudo killall -9 motion
0 7-19 * * * /home/pi/restartmotion.sh
3 7-17 * * * find /var/www/motion -ctime +7|xargs sudo rm -rf
#2 * * * * /etc/init.d/autossh restart
```
```
pi@raspberrypi3B:~ $ cat /home/pi/restartmotion.sh
sudo killall -9 motion
sleep 1
sudo motion
```

### 3.常用来做NAT穿越，设置socket5代理，以目的地IP做上网的代理中转；可躲僻一些服务对IP的封锁、远程登录家中路由器做一些常规配置。
```
ssh -L 56701:localhost:56701 git@xyzbuy.cn
ssh -D 1088 -p 56701 pi@localhost
```
然后在本地电脑浏览器上设置socket5代理端口1088即可访问远程。

### 4.国内电信运营商宽带无独立IP，共享的IP也是动态变化的，通过autossh + nginx反向代理，将树莓派上的端口通过域名直接访问。附上远程服务器上的nginx反向代理配置:
```
# cat /etc/nginx/conf.d/mycam.xyzbuy.cn.conf
server {
    listen 80;
    server_name mycam.xyzbuy.cn;
    access_log  /var/log/nginx/mycamera-access.log  main;

    location / {
        proxy_pass http://127.0.0.1:56781;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 5.查看网络命令，除了ifconfig、netstat -tulnp之外
###### 1. 主要使用iw相关命令：
1. iwconfig
2. iw wlan0 info
3. sudo iw wlan0 scan
或者
sudo iw wlan0 scan|grep "SSID\|signal\|freq:\|primary channel"

###### 2. 编辑raspberry Pi的无线网线连接
1. sudo vim /etc/wpa_supplicant/wpa_supplicant.conf


### 6.常用的系统更新命令
###### 1.更新源列表刷新
sudo apt-get update

###### 2. 更新软件
sudo apt-get upgrade

###### 3. 更新raspbian系统
sudo rpi-update
```
pi@raspberrypiZero:~ $ sudo rpi-update
 *** Raspberry Pi firmware updater by Hexxeh, enhanced by AndrewS and Dom
 *** Performing self-update
 !!! Failed to download update for rpi-update!
 !!! Make sure you have ca-certificates installed and that the time is set correctly
#默认方法
sudo apt-get install ca-certificates

#同步时间
sudo apt-get install ntpdate
sudo ntpdate -u ntp.ubuntu.com
#如果还不行，就直接跳过自更新
pi@raspberrypiZero:~ $ sudo UPDATE_SELF=0 rpi-update
```

### 7.GPIO
####安装gpio库:
sudo apt-get install python3-rpi.gpio python3-gpiozero
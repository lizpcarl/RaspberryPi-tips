# [RaspberryPi tips](https://github.com/lizpcarl/RaspberryPi-tips)
record some usage for RaspberryPi; For example,  Camera, motion, autossh, etc.

##Introduce
从2014年到现在买了5个不同型号的树莓派了，大部分用来安装motion后做远程摄像头使用。本project用来记录常用的一些命令和操作方法。

### 1.树莓派重装后，需要安装的主要软件
1. sudo apt-get install autossh  
motion, nodejs, golang, vim, arduino
ttf-inconsolata
omxplayer, vlc
2. 安装好autossh之后，可以把本project的etc-initd目录修改到RaspberryPi上对应的/etc/init.d/autossh文件。
3. 修改crontab -e的默认编辑器  
update-alternatives --config editor  
选择第3项vim.basic即可
4. vim ~/.bashrc. 
反注释，让ll生效;
5. 摄像头驱动配置
vim /etc/modules  
bcm2835-v4l2
另外在配置中打开Camera:sudo raspi-config，在Interfacing options中置Camera为enable；
6. sudo apt-get install autossh motion vim  
7. sudo cp autossh /etc/init.d/.  
修改/etc/init.d/autossh中的端口参数配置  
8. 修改motion配置文件,
sudo vim /etc/motion/motion.conf
修改daemon=on,设置rotate及width、height，brightness,contrast,saturation,hue, stream_localhost, lightswitch, 
target_dir /var/lib/motion --> /var/www/motion(先sudo mkdir -p /var/www/motion)
9. 生成RTSP视频流  
raspivid -o - -t 0 -w 800 -h 600 -fps 25|cvlc -vvv stream:///dev/stdin --sout  '#standard{access=http,mux=ts,dst=:8081}' :demux=h264
http://mycam.xyzbuy.cn


### 2.一台与openWrt路由器（带wifidog认证功能）直接相连的RaspberryPi，常用的crontab任务列表
*本地IP上报、默认路由选择、定时重连autossh、夜间关闭摄像头功能、定时清理录像文件释放空间*

```
pi@raspberrypi2B:~ $ crontab -l
0 * * * * curl -A "heartbeat from RaspberryPi2B+gitsource to test IP" -I http://xyzbuy.cn
0 * * * * sudo route del default gw TPopenWrt.lan 
1 7 * * * /etc/init.d/autossh stop  
2 7 * * * /etc/init.d/autossh start  
39 19 * * * sudo killall -9 motion  
3 7 * * * find /var/www/motion -ctime +7|xargs sudo rm -rf
```

### 3.常用来做NAT穿越，访问远程网络中，登录家中路由器
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

### 5.openWrt的常用命令
cat /tmp/dhcp.leases
iwinfo wlan0(1) scan



#在树莓派上开发arduino
<hr/>
##Arduino上的开发知识点
###Arduino浮点数转换为字符串
用标准avr-libc库提供的函数dtostrf()来替代sprintf函数. 
只需将sprintf()替换为dtostrf(), 并填好里面的参数即可.
```
dtostrf(floatVar, minStringWidthIncDecimalPoint, numVarsAfterDecimal, charBuf);
```

###Arduino读取串口的指令
```
if (Serial.available()>0)
{
	ab=Serial.read();
	Serial.println(ab);
	if (ab=='r'||ab=='R'){
	redOne();
}
digitalWrite(redPin,HIGH);
```
<hr/>
##树莓派上与Arduino的知识点
###python serial 模块使用方法
####导入pyserial模块
```
import serial
```
前提是安装了的pyserial库的：
pip install pyserial
####①选择设备
```
ser=serial.Serial("/dev/ttyUSB0",9600,timeout=0.5) #使用USB连接串行口
ser=serial.Serial("/dev/ttyAMA0",9600,timeout=0.5) #使用树莓派的GPIO口连接串行口
print ser.name#打印设备名称
print ser.port#打印设备名
//>>> ser
//Serial<id=0x769c28b0, open=True>(port='/dev/ttyUSB0', baudrate=9600, bytesize=8, parity='N', stopbits=1, timeout=0.5, xonxoff=False, rtscts=False, dsrdtr=False)
ser.open() #打开端口
s = ser.read(10)#从端口读10个字节
ser.readline()#读取一行
ser.readall()#读取当前缓冲区的全部内容
ser.write("hello")
ser.write("hello".encode())#向端口写数据
ser.close()#关闭端口
```

###arduino-mk的安装及配置使用
在树莓派上开发arduino。arduino是开发环境，而arduino-mk是在命令行下make文件时所需要的环境。毕竟99%的人都是使用SSH的方式链接上树莓派的，没有图形界面，此时使用arduino-mk就大为方便了。
sudo apt-get install arduino arduino-mk
安装完成后，找到/usr/share/arduino/Arduino.mk文件，该文件包含几乎所有需要的信息。
树莓派上一般是/dev/ttyACM0 端口 或者 /dev/ttyUSB0 端口;

```
ARDUINO_LIBS = Ethernet SPI
BOARD_TAG = uno
MONITOR_PORT = /dev/ttyUSB0
include /usr/share/arduino/Arduino.mk
```
####编译：
```
$ make
```
####如果编译通过没有出错，就可以烧入程序：
```
$ make upload
```
看到“Thank you”就代表成功烧入程序了。

####第三方库一般的位置：（方便管理）
mac下默认第三方库路径：\~/Documents/Arduino/libraries
windows下默认第三方库路径：My Documents\Arduino\libraries\
linux下一般是在你的sketchbook目录下，在～目录下新建一个sketchbook目录，在该目录下在创建一个libraries目录，然后将第三方库解压到libraries目录下。

注意：在libraries目录下，每个库应该在单独的文件夹里，并且要满足如下规则：比如你的库名字叫ArduinoParty，那么libraries目录下就要有ArduinoParty文件夹，并且该文件夹目录下必须有ArduinoParty.cpp和ArduinoParty.h文件，只能放在该目录下，不支持嵌套。(如果有example文件夹，则下面的例子IDE也能识别)。
　　在Makefile中设置USER_LIB_PATH变量，指定第三方库路径：
USER_LIB_PATH = /home/pi/sketchbook/libraries(必须是绝对路径，而且是完整的，不能用～等)
　　设置ARDUINO_LIBS变量，指定需要加载的库文件：　

ARDUINO_LIBS = Ethernet SPI yourlib

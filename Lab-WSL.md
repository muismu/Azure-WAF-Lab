# Windows WSL Kali Linux配置
## 安装WSL   
打开Windows开始菜单，搜索"Turn Windows features on or off"并打开，打开的窗口中选择勾选Hyper-V并确定
![Windows Programs](./images/TurnonWindowsFeature.png) 
在安装完成后需要重启机器  

## 安装Kali Linux
打开Microsoft Store(微软应用商店)搜索Kali Linux并安装，安装完成后打开设置用户名及密码:
![Kali Linux](./images/Kali-Linux.png)

## 安装Kali Linux Tools 
打开Windows Terminal并选择Kali Linux，执行如下命令:   
```
sudo apt update
sudo apt install -y kali-win-kex
sudo apt install -y kali-linux-large
```
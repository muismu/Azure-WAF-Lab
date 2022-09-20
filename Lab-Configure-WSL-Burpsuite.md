# 简介  
Windows Subsystem for Linux (WSL)可以使开发者在Windows上无需运行虚拟机或者采用双启动模式的情况下直接运行GNU/Linux环境，配合VS Code远程开发的功能提供更好的开发体验。由于目前Kali Linux目前在Azure Marketplace没有提供官方镜像，因此本实验通过利用WSL Kali Linux使用nikto工具进行侦察攻击，同时在本地安装Burp Suite对OWASP Juice Shop应用程序在直接发布和通过Application Gateway(启用WAF)发布两种情况下进行攻击测试，对比验证Azure WAF的有效性

# 前提条件  
通过[使用本地WSL](./Lab-Environment-Local-WSL.md)或者[使用Azure VM](./Lab-Environment-VM-WSL.md)完成Azure环境的准备

# 桌面环境配置
桌面配置针对Azure Windows VM或者本地Windows
## 1. 安装WSL   
打开Windows开始菜单，搜索"Turn Windows features on or off"并打开，打开的窗口中选择勾选Windows Subsystem for Linux并确定
![Windows Programs](./images/TurnonWindowsFeature.png)  
在安装完成后需要重启机器  

## 2. 安装Kali Linux
打开Microsoft Store(微软应用商店)搜索Kali Linux并安装，安装完成后打开设置用户名及密码:
![Kali Linux](./images/Kali-Linux.png)

## 3. 安装nikto
Kali Linux安装完后执行如下命令:  
```
sudo apt-get update
sudo apt install -y nikto
```

***注意事项***   
如果已经使用了WSL Debian或者WSL Ubuntu,则可通过如下命令方式安装nikto   
```
sudo echo "deb http://http.kali.org/kali kali-rolling main non-free contrib" >> /etc/apt/sources.list.d/kali.list
wget -q https://archive.kali.org/archive-key.asc
sudo apt-key add archive-key.asc
sudo apt-get update
sudo apt install -y nikto
```

### 4. 安装Burp Suite Community应用安全测试软件 
从Burp Suite官网下载并安装Burp Suite Community版本的软件,下载请点击[此处](https://portswigger.net/burp/releases/professional-community-2022-8-2?requestededition=community&requestedplatform=)


# [下一步](./Lab-Reconnaissance.md)
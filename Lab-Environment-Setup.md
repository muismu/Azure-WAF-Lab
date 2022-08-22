# 简介
整体实验环境如下图所示:
![Lab Environment](./images/WAF-Lab-Environment.png)
# Install Kali Tools in Debian   

```
apt-get update
apt-get install -y wget
echo "deb http://http.kali.org/kali kali-rolling main non-free contrib" > /etc/apt/sources.list.d/kali.list
wget https://archive.kali.org/archive-key.asc
apt-get install gnupg gnupg2
apt-key add archive-key.asc
apt-get update
sudo apt install -y kali-linux-default
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install xfce4
sudo apt install xfce4-session
sudo apt-get -y install xrdp
sudo systemctl enable xrdp
echo xfce4-session >~/.xsession
sudo service xrdp restart
```
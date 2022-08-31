```
sudo apt-get update
sudo apt install -y wget gnupg gnupg2 firefox xfce4 xfce4-session xrdp
sudo echo "deb http://http.kali.org/kali kali-rolling main non-free contrib" >> /etc/apt/sources.list.d/kali.list  
wget -q https://archive.kali.org/archive-key.asc
sudo apt-key add archive-key.asc
sudo apt-get update
sudo apt install -y nikto burpsuite
echo xfce4-session >~/.xsession
echo export BROWSER=/usr/bin/firefox >> .bashrc
sudo systemctl enable xrdp
sudo systemctl restart xrdp
``` 
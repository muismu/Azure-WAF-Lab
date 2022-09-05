#cloud-config
package_upgrade: true
packages:
  - ca-certificates
  - gnupg
  - gnupg2
  - lsb-release
  - curl
write_files:
  - owner: root:root
    path: /etc/apt/sources.list.d/docker.list
    content: |
      deb http://http.kali.org/kali kali-rolling main non-free contrib
runcmd:
  - sudo mkdir -p /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  - sudo apt-get update
  - sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
  - sudo systemctl enable docker
  - sudo systemctl restart docker
  - sudo docker run -p 80:3000 bkimminich/juice-shop:v14.1.1
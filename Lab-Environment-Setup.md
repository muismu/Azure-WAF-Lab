# 简介

如果对Azure非常熟悉，而且对Azure WAF、Application Gateway及Container Instance有一定了解，则可以点击[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com)直接部署。
整体实验环境如下图所示,Juice-shop应用将会通过Container Instance服务进行部署，为了尽可能保证环境的安全，该应用不会通过互联网暴露，将通过Kali Subnet中的虚拟机模拟攻击者从Container Instance的内部IP和Internal Application Gateway进行访问。
![Lab Environment](./images/WAF-Lab-Environment.png)

# 环境部署  
## 部署基础环境
## 部署Application Gateway
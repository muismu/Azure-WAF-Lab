# 简介  
本测试环境使用本地桌面利用WSL Kali Linux及Burp Suite Community版本对Azure WAF的OWASP 3.2规则集进行验证，本部分主要包含Azure环境的准备，本地桌面的配置参考[WSL配置及Burp Suite安装](./Lab-Configure-WSL-Burpsuite.md)

在该环境下，整个环境如下图所示:
![Local-WSL](./images/Arch/Local-Arc.png)

***注意事项***   
该测试环境仅用作演示用途，请不要在生产环境或者测试环境中进行测试，如需该种类型测试，请在有安全控制措施的私有网络环境下测试并及时删除包含漏洞的应用。在Azure中测试中请设置合理的隔离措施，禁止分配Identity给Container instance。

# 部署Azure测试环境  
本实验提供自动部署和手动部署两个选项，如果对Azure非常熟悉且有过Application Gateway及Container Instance相关使用经验可以使用自动部署部署测试环境，否则建议通过手动部署的方式了解相关服务的配置。
## 自动部署
自动部署通过使用ARM Template实现，可以直接点击如下按钮或者复制[template文件](https://raw.githubusercontent.com/muismu/Azure-WAF-Lab/main/bicep/main-wsl.json)通过Azure portal进行部署, 所有参数保持默认即可，无需修改.
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmuismu%2FAzure-WAF-Lab%2Fmain%2Fbicep%2Fmain-wsl.json)
## 手动部署   
### 1. 创建Virtual Network
Application Gateway需要部署在虚拟网络的专有子网中，该子网只能用于部署一个或者多个Application Gateway，不能用于其它用途，同时为了对比验证，需要将JuiceShop-A部署在虚拟网络中，因此需要创建ApplicationGatewaySubnet和Workload两个子网,具体创建步骤如下：  
(1). 在Azure Portal中点击`+ Create a resource`, 搜索`Virtual network`，点击`Create`进行创建  

(2). 配置Virtual Network的Baiscs设置  

![VNET-Basics](./images/Local-WSL/WSL-1-VNET-Basics.png)     

(3). `Security`部分保持默认配置，在IP addresses配置时删除default子网并创建两个子网   

![DeleteDefault](./images/Local-WSL/WSL-2-VNET-Delete-Default-Subnet.png)   

![ApplicationGatewaySubnet](./images/Local-WSL/WSL-3-VNET-Create-ApplicationGatewaySubnet.png)  

![WorkloadSubnet](./images/Local-WSL/WSL-4-VNET-Create-WorkloadSubnet.png)   

(4). 其它配置保持默认配置,点击`Review + Create`查看没有问题后点击`Create`创建  

### 2. 创建WAF Policy
(1). 在Azure Portal顶部的搜索栏中输入`Web Application Firewall policies`并选择创建对应资源      

![SearchWAFPolicy](./images/Local-WSL/WSL-5-VNET-Create-WAF-Policy.png)   

(2). 在Web Application Firewall policies界面上点击创建并按照如下图所示配置Baiscs部分  

![WAF-Policy-Basics](./images/Local-WSL/WSL-6-VNET-Create-WAF-Policy-basics.png)  

(3). 在配置Managed Rules时选择OWASP 3.2规则集 
![WAF-Rules](./images/Local-WSL/WSL-7-VNET-Create-WAF-Policy-Rules.png)  

(4). 其它所有配置保持默认配置，点击`Review + create`即可

### 3. 创建JuiceShop-A实例
(1). 在Azure Portal首页,点击`+ Create a resource`, 搜索`Container Instances`，点击`Create`  

(2). 在Basics配置页面，按照如下配置参数进行配置:  
* Image Source: `Other Registry`
* Image Type: `Public`
* Image: `bkimminich/juice-shop:v14.1.1`
* OS Type: `Linux`
* Size: 2 vCPUs, 4GiB memory, 0 gpus  

![juiceshop-a-basics](./images/Local-WSL/WSL-8-VNET-Create-juiceshop-a.png)

(3). 在Networking配置部分，按照如下参数进行配置:  
* Networking Type: `Private`
* Virtual Network: 选择[步骤1](#1-创建virtual-network)中创建的VNet  
* Subnet: 选择[步骤1](#1-创建virtual-network)中创建的Workload子网  
* Ports: 使用tcp/3000端口   

![juiceshop-a-networking](./images/Local-WSL/WSL-9-VNET-Juiceshop-Networking.png)  

(4). 其它配置保持不变，直接点击`Review + create`开始创建资源

### 4. 创建Application Gateway
(1). 在Azure Portal中,点击`+ Create a resource`, 搜索`Application Gateway`，点击`Create`  

(2). 在Baiscs配置部分，按照如下参数进行配置:  
* Tier: `WAF V2`
* WAF Policy: 选择[步骤2](#2-创建waf-policy)中创建的WAF Policy   
* Virtual Network: 选择[步骤1](#1-创建virtual-network)中创建的VNet 
* Subnet: 选择[步骤1](#1-创建virtual-network)中创建的ApplicationGateway子网   

![appgw-basics](./images/Local-WSL/WSL-10-VNET-Juiceshop-appgw-basics.png)  

(3). 在Frontends部分，按照如下参数进行配置:  
* Frontend IP address type: `Public`
* Public IP address: `Add new`    

![Frontend](./images/Local-WSL/WSL-11-VNET-Juiceshop-appgw-frontend.png)  

(4). 在Backends部分选择`Add a backend pool`, 该backend pool的target为[步骤3](#3-创建juiceshop-a实例)中创建的JuiceShop-A实例Private IP地址  

![BackendPool](./images/Local-WSL/WSL-12-VNET-Juiceshop-appgw-backendpool.png)  

(5). 在Configuration配置部分,点击`Add a routing rule`添加一条路由规则,规则的配置如下:  
* Rule name: `juiceshop-a`
* Priority: `1000`

Listener部分配置如下:  
* Listener name: `juiceshop-a`
* Front IP: `Public`
* Protocol: `HTTP` 
* Port: `80`
* Listener type: `Basic`
* Error page url: `No`  

![Listener](./images/Local-WSL/WSL-13-VNET-Juiceshop-appgw-listener.png)

在配置Backend targets时Target type选择`Backend pool`，Backend target选择步骤(4)所创建的Backend Pool,Backend settings选择`Add new`进行创建  

![backendstarget](./images/Local-WSL/WSL-14-VNET-Juiceshop-appgw-backendtargets.png) 

在Backend settings部分，主要配置如下:  
* Backend settings name: `juiceshop-a`
* Backend protocol: `HTTP` 
* Backend port: `3000`

其余配置保持不变即可  

![backendsetting](./images/Local-WSL/WSL-15-VNET-Juiceshop-appgw-backendsettings.png)

(5). 其余配置保持不变，点击`Review + create`进行创建

### 5. 验证Application Gateway正常工作
在资源创建完成后使用浏览器访问`http://<Application Gateway Public IP>`确认可以正常访问juice shop应用
![juiceshop](./images/Local-WSL/WSL-16-VNET-Juiceshop-appgw-verification.png)

### 6. 创建JuiceShop-B实例
(1). 在Azure Portal首页,点击`+ Create a resource`, 搜索`Container Instances`，点击`Create`  

(2). 在Basics配置页面，按照如下配置参数进行配置:  
* Image Source: `Other Registry`
* Image Type: `Public`
* Image: `bkimminich/juice-shop:v14.1.1`
* OS Type: `Linux`
* Size: 2 vCPUs, 4GiB memory, 0 gpus  

![juiceshop-a-basics](./images/Local-WSL/WSL-8-VNET-Create-juiceshop-a.png)

(3). 在Networking配置部分，按照如下参数进行配置:  
* Networking Type: `Public` 
* Ports: 使用tcp/3000端口   

![juiceshop-b-networking](./images/Local-WSL/WSL-17-VNET-Juiceshop-b-networking.png)  

(4). 其它配置保持不变，直接点击`Review + create`开始创建资源

### 7. 验证JuiceShop-B实例正常工作
在资源创建完成后使用浏览器访问`http://<Contianer Instance Public IP>:3000`确认可以正常访问juice shop应用
![juiceshop](./images/Local-WSL/WSL-18-VNET-Juiceshop-b-verification.png)

### 8. 创建Log Analytics Workspace  
(1). 在Azure Portal首页,搜索`Log Analytics workspaces`, 然后点击`Create`

(2). 在Baiscs配置页面，输入workspace的名字及选择对应的区域  

![workspace](./images/Vm/workspace-1-advanced.png)

(3). 其它配置保持默认即可，点击`Review + create`创建资源  

### 9. 配置Application Gateway的诊断日志 
(1). 选择[步骤5](#5-创建application-gateway)所创建的Application Gateway  
(2). 打开Application Gateway的`Diagnostic settings`

![AppGWDiagnostic](./images/appgw/appgw-7-appgw-diagnostics.png)

(3). 点击`Add diagnostic setting`新增配置,按如下配置将Application Gateway Firewall Log发送到[步骤9](#9-创建log-analytics-workspace)中

![配置diagnostic](./images/appgw/appgw-9-appgw-logs.png)

### 10. 创建WAF Workbook  
点击下面部署按钮部署Azure WAF workbook

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmuismu%2FAzure-WAF-Lab%2Fmain%2Fbicep%2Fworkbooks.json)

# [下一步](./Lab-Configure-WSL-Burpsuite.md)
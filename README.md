# 简介  
Azure WAF Hands-on实验旨在演示Azure Web Application Firewall在识别、检测和保护Web应用免受恶意和潜在应用层攻击。本实验目标如下：  

* 配置测试环境测试Azure WAF对Web应用的防护能力  
* 通过详细的指导模拟恶意用户对Web应用进行攻击
* 通过Azure Monitor Workbook for WAF理解WAF针对本实验中使用的攻击模式的检测和处理逻辑  

本实验通过在无WAF的情况下模拟直接攻击[OWASP Juice Shop](https://owasp.org/www-project-juice-shop/) Web应用及在使用Azure WAF的情况下进行攻击来演示Azure WAF on Application Gateway上的有效性。

本实验以探索Azure WAF的OWASP防护规则集和日志记录能力为主，不包含高级的应用安全概念，同时也当作应用安全测试的参考，应用安全的范围远远超过本实验所演示的范围。  


# 环境配置   
本部分内容包含了部署和创建演示环境所需的Azure资源。

如果对Azure非常熟悉，而且对Azure WAF、Application Gateway及Container Instance有一定了解，则可以点击[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com)直接部署。

同时也可通过[设置Azure WAF攻击测试环境](./Lab-Environment-Setup.md)按照手册一步一步部署资源。  

# 环境嗅探
嗅探活动允许攻击者获取目标Web应用的漏洞相关信息以便后续利用，在该部分将会利用Azure WAF检测一些常见和通用的攻击工具的嗅探行为。  

详细步骤参考[通过Azure WAF检测恶意嗅探](./Lab-Reconnaissance.md)

# 漏洞利用  
利用前述步骤中发现的漏洞攻击应用并获取特权，在本次模拟中，会针对应用进行跨站脚本攻击，可以观测到Azure WAF的 **Cross Site Scripting(XSS)** 规则被触发 

详细步骤参考[攻击测试](./Lab-Attack.md)

# 数据窃取  
经过前一个阶段的攻击，攻击者已经获取了对应用后端的访问权限并试图窃取敏感数据。本阶段会模拟 **SQL Injection(SQLi)** 攻击对Azure WAF的SQLi能力进行测试。  

详细步骤参考[SQL注入攻击](./Lab-Data-Exfiltration.md)

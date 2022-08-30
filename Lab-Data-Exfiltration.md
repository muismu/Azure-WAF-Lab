# 简介  
通过漏洞进行数据窃取是本实验的第四部分，本实验的目的是演示Azure WAF在识别针对Web应用的可疑活动和恶意攻击及保护Web应用方面的能力。本部分内容主要测试Azure WAF针对SQL注入攻击(SQL Injection)的防护能力及日志记录相关的功能。

本部分实验主要包含如下内容:  
* 模拟针对OWASP Juice Shop实例的直接SQL注入攻击   
* 模拟针对通过Application Gateway(启用WAF)发布的Juice Shop应用的SQL注入攻击  
* 对比在两种场景下的区别  
* 通过Azure Monitor Workbook for WAF监控检测到的攻击活动    

# 前提条件   

1. 通过[设置Azure WAF攻击测试环境](./Lab-Local.md)完成实验环境的准备
2. 完成[侦察攻击](./Lab-Reconnaissance-Local.md)部分的相关实验  
3. 完成[XSS注入攻击](./Lab-Attack-Local.md)部分相关实验
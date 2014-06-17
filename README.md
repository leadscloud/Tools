Tools
=====

##服务器及前端工具合集##


###addftpmysql.sh###

LNMP/LNMPA服务器下的自动添加FTP账号及MYSQL账号的shell脚本。此脚本有以下需求：

1. 使用lnmp.org上的一键安装包
2. FTP服务使用的是pureftpd
3. 默认网站根目录是`/home/wwwroot`

###lnmpa.backup.sh###

lnmpa的备份脚本，在linux下使用`crontab -e`设置定时任务，可以定时备份你的服务器，包括所有网站目录，所有MYSQL数据库，所有网站信息。`0 3 */3 * * /root/backup.sh` 代表每3天备份一次，备份时间是凌晨3点。

###resource.md###

一些优质学习资源



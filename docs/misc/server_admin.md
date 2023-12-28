服主小技巧
=====================

本文件夹下的 calcDailyLogin.sh 是统计日活的脚本，可以将其设为定时任务。

注意时不时备份数据库。数据库只是单个sqlite文件而已，直接cp即可。

使用sqlite命令行之前可以使用.mode markdown命令将sqlite输出设为markdown格式，方便复制粘贴到配置中。

常用sql语句
-----------------

```sql
-- 统计某个模式胜率前20名的玩家
SELECT * FROM playerWinRate WHERE mode="m_1v2_mode" AND total > 400 ORDER BY winRate DESC LIMIT 20;

-- 统计某个模式胜率前20名的武将
SELECT * FROM generalWinRate WHERE mode="m_1v2_mode" AND total > 400 ORDER BY winRate DESC LIMIT 20;

-- 统计游玩时长排行
SELECT usergameinfo.id, totalGameTime AS 'Time (sec)', round(totalGameTime/3600.0, 2)||" h" AS ' ', name AS Name FROM usergameinfo, userinfo WHERE userinfo.id = usergameinfo.id GROUP BY usergameinfo.id ORDER BY totalGameTime DESC LIMIT 10;
```


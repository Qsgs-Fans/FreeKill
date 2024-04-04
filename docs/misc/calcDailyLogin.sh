#!/bin/bash
# 用于统计新月杀日活的脚本，可以写入定时任务。

# 我自己是把数据库文件在这个目录创了符号链接，总之确保这里存在那个数据库，可以手动cd
# cd ~

SQLITE_CMD="sqlite3 users.db -readonly -list -batch -bail -cmd "
SEL_REG="SELECT count() FROM usergameinfo WHERE date(registerTime, 'unixepoch', 'localtime') >= date('now', 'localtime', 'start of day') AND date(registerTime, 'unixepoch', 'localtime') < date('now', 'localtime', 'start of day', '+1 days');"
SEL_LOG="SELECT count() FROM usergameinfo WHERE date(lastLoginTime, 'unixepoch', 'localtime') >= date('now', 'localtime', 'start of day') AND date(lastLoginTime, 'unixepoch', 'localtime') < date('now', 'localtime', 'start of day', '+1 days');"

i=0
# 数据库可能被锁定，需要循环
false # 令$?为1，不知道怎么写do while循环
while [ 0 -ne $? ]; do
  sleep 0.3
  i=$[i+1]
  if [ $i -ge 30 ]; then exit; fi
  REG_COUNT=$($SQLITE_CMD "$SEL_REG" < /dev/null)
done

false
while [ 0 -ne $? ]; do
  sleep 0.3
  i=$[i+1]
  if [ $i -ge 30 ]; then exit; fi
  LOG_COUNT=$($SQLITE_CMD "$SEL_LOG" < /dev/null)
done

echo "$(date +'%Y-%m-%d'),${REG_COUNT},${LOG_COUNT}" >> loginInfo.csv

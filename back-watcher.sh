#!/system/bin/sh
# 主空间 root watchdog：轮询微信区的触发文件，收到就切回主用户；
# 另外切过去 5 秒后会自动把 SELinux 恢复成 enforcing（切换时临时关过）。
export PATH=/system/bin:/system/xbin:/debug_ramdisk:$PATH
TRIG=/data/media/10/Android/data/org.wechatfence.userswitch/files/back
LOG=/sdcard/Download/DSH-Go/watcher.log
rm -f "$TRIG"
echo "watchdog start $(date)" >> "$LOG"
i=0
while true; do
  if [ -f "$TRIG" ]; then
    echo "trigger at $(date)" >> "$LOG"
    setenforce 0 2>/dev/null
    am switch-user 0 2>/dev/null
    setenforce 1 2>/dev/null
    rm -f "$TRIG"
    echo "switched back, enforce=$(cat /sys/fs/selinux/enforce 2>/dev/null)" >> "$LOG"
    exit 0
  fi
  i=$((i+1))
  if [ "$i" -eq 5 ]; then
    setenforce 1 2>/dev/null
    echo "enforce restored to $(cat /sys/fs/selinux/enforce 2>/dev/null)" >> "$LOG"
  fi
  sleep 1
done

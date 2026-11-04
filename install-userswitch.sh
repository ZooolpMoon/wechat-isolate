#!/system/bin/sh
# 安装「用户切换」App（以及它需要的 watchdog 脚本）
# 用法： su -c 'sh /path/to/install-userswitch.sh'
# 前提：已用 wechat-isolate.sh 创建好「微信区」用户
export PATH=/system/bin:/system/xbin:/vendor/bin:/sbin:/debug_ramdisk:$PATH
DIR=$(cd "$(dirname "$0")" && pwd)
PKG=org.wechatfence.userswitch
NAME=微信区
say() { echo "$@"; }

[ "$(id -u)" = "0" ] || { say "需要 root：su -c 'sh $0'"; exit 1; }

ENF=$(cat /sys/fs/selinux/enforce 2>/dev/null)
trap "setenforce $ENF 2>/dev/null" EXIT
setenforce 0 2>/dev/null

TARGET=$(pm list users 2>/dev/null | grep "$NAME" | sed -n 's/.*UserInfo{\([0-9][0-9]*\):.*/\1/p')
[ -n "$TARGET" ] || { say "没找到「$NAME」用户，先跑 wechat-isolate.sh"; exit 1; }
say "微信区 user id = $TARGET"

# App 里写死了 watchdog 路径，这里复制过去
mkdir -p /sdcard/Download/DSH-Go 2>/dev/null
cp "$DIR/back-watcher.sh" /sdcard/Download/DSH-Go/back-watcher.sh
chmod 644 /sdcard/Download/DSH-Go/back-watcher.sh 2>/dev/null
say "watchdog 已放到 /sdcard/Download/DSH-Go/back-watcher.sh"

say "安装 App ..."
pm install -r "$DIR/userswitch/userswitch.apk" 2>&1
pm install-existing --user "$TARGET" "$PKG" 2>&1
say ""
say "完成。主空间和微信区的桌面都会有「用户切换」。"
say "第一次在主空间点按钮时，Magisk 会弹一次 root 授权，点允许即可。"

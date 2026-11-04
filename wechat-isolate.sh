#!/system/bin/sh
# wechat-isolate.sh v2.0
# 用 Android 多用户把微信隔离到独立空间「微信区」。
# 微信区有自己独立的 /data/user/<id> 和 /storage/emulated/<id>，
# 主空间的照片、文件、通讯录、其他应用数据它都看不到。
#
# 用法（需要 root shell）：
#   创建并安装:      su -c 'sh /path/to/wechat-isolate.sh'
#   切换到微信区:    su -c 'sh /path/to/wechat-isolate.sh --switch'
#   切回主空间:      su -c 'sh /path/to/wechat-isolate.sh --back'
#   主空间卸掉微信:  su -c 'sh /path/to/wechat-isolate.sh --uninstall-main'
#   删除微信区:      su -c 'sh /path/to/wechat-isolate.sh --remove'

export PATH=/system/bin:/system/xbin:/vendor/bin:/sbin:/debug_ramdisk:$PATH
NAME=微信区
MODE=${1:-apply}
say() { echo "$@"; }

[ "$(id -u)" = "0" ] || { say "需要 root：su -c 'sh $0'"; exit 1; }

get_id() {
  pm list users 2>/dev/null | grep "$NAME" | sed -n 's/.*UserInfo{\([0-9][0-9]*\):.*/\1/p'
}

has_wechat() {
  pm list packages --user "$1" 2>/dev/null | grep -q '^package:com\.tencent\.mm$'
}

ID=$(get_id)

case "$MODE" in
  --switch)
    [ -n "$ID" ] || { say "还没有创建「$NAME」，先跑一次：su -c 'sh $0'"; exit 1; }
    say "切换到用户 $ID（微信区）..."
    am switch-user "$ID" 2>&1
    ;;
  --back)
    say "切回主空间..."
    am switch-user 0 2>&1
    ;;
  --remove)
    [ -n "$ID" ] || { say "没有找到「$NAME」用户"; exit 0; }
    say "删除用户 $ID（微信区和里面的微信数据会一起删掉，主空间不受影响）"
    pm remove-user "$ID" 2>&1 && say "已删除"
    ;;
  --uninstall-main)
    say "从主空间卸载微信（主空间的微信聊天记录会丢，先确认已备份/迁移）"
    pm uninstall --user 0 com.tencent.mm 2>&1 && say "主空间微信已卸载"
    ;;
  *)
    if [ -z "$ID" ]; then
      say "创建独立用户「$NAME」..."
      pm create-user "$NAME" 2>&1
      ID=$(get_id)
    else
      say "「$NAME」已存在，id = $ID"
    fi
    if [ -z "$ID" ]; then
      say "!! 创建用户失败：这个 ROM 可能关闭了多用户（fw.max_users=1）。"
      exit 1
    fi

    say "把微信装进用户 $ID ..."
    if has_wechat "$ID"; then
      say "微信已经在微信区里了"
    else
      pm install-existing --user "$ID" com.tencent.mm 2>&1 \
        || cmd package install-existing --user "$ID" com.tencent.mm 2>&1
      if has_wechat "$ID"; then
        say "微信已安装到微信区"
      else
        say "!! 自动安装失败。可以切到微信区后用应用商店手动安装微信。"
      fi
    fi

    say ""
    say "下一步："
    say "  1) 切换过去:   su -c 'sh $0 --switch'"
    say "  2) 在微信区里登录微信（新的用户环境，需要重新登录）"
    say "  3) 聊天记录迁移：先在主空间微信里用电脑备份，再到微信区微信里恢复"
    say "  4) 确认能用后可选: su -c 'sh $0 --uninstall-main' 把主空间的微信也卸掉"
    say "  5) 切回来:     su -c 'sh $0 --back'"
    say "  删除微信区:    su -c 'sh $0 --remove'"
    ;;
esac

# 微信真隔离 wechat-isolate

用 Android 多用户把微信关进独立空间「微信区」：它有自己独立的
`/data/user/<id>` 和 `/storage/emulated/<id>`，主空间的照片、文件、通讯录、
其他应用数据它都看不到。

> 为什么不用权限回收或系统自带的「应用分身」？
> 回收权限在系统设置里就能做，挡不住间接访问；应用分身（ColorOS 的 MultiApp，
> 用户 999）和主空间共享媒体、共享通讯录，本质上不是隔离。真正把微信和数据隔开，
> 只能靠 Android 的用户隔离——这也是本项目唯一做的事。

## 要求

- **root shell**（Magisk / KernelSU / APatch 等）——创建用户需要 `MANAGE_USERS`
- Android 10+（在 Android 16 / ColorOS 16 上实测）
- 部分 ROM 关闭了多用户（`fw.max_users=1` 或直接拒绝），脚本会报错

## 用法

```sh
# 创建「微信区」并把微信装进去
su -c 'sh /path/to/wechat-isolate.sh'

# 切换到微信区（第一次要等系统初始化）
su -c 'sh /path/to/wechat-isolate.sh --switch'

# 切回主空间
su -c 'sh /path/to/wechat-isolate.sh --back'

# 可选：确认微信区能用后，把主空间的微信卸掉
su -c 'sh /path/to/wechat-isolate.sh --uninstall-main'

# 删除微信区（连同里面的微信数据，主空间不受影响）
su -c 'sh /path/to/wechat-isolate.sh --remove'
```

## 切回主空间

切到微信区之后，主空间的 Termux / 助手都停了，不能再用 `--back`，所以脚本会顺便把
系统自带的多用户切换入口打开（`settings put global user_switcher_enabled 1`）：

1. 下拉**快捷设置面板**（或者锁屏）→ 右上角的**用户头像** → 选「机主」
2. 也可以在微信区里装一个终端（Termux），执行 `su -c 'am switch-user 0'`

> 建议切过去之前先确认快捷设置里能看到用户头像；看不到就先别切。

## 隔离了什么

| | 主空间 | 微信区 |
| --- | --- | --- |
| 内部存储 | `/data/user/0` | `/data/user/<id>` |
| 共享存储 | `/storage/emulated/0` | `/storage/emulated/<id>` |
| 照片 / 文件 | 主空间的 | 微信区独立的（初始为空） |
| 通讯录 | 主空间的 | 微信区独立的（初始为空） |
| 其他 App 数据 | 互不可见 | 互不可见 |

微信只能看到「微信区」里的数据，主空间的照片、文件、通讯录它都碰不到。

## 没隔离的

- 微信仍然联网，聊天内容仍然经过腾讯服务器（本工具不管服务端）。
- 系统级能力（拨号、通知栏、剪贴板等）由 Android 统一提供，不按用户隔离。
- 微信区里自己产生的照片/文件，微信当然能看（那个空间是给它用的，初始为空）。

## 聊天记录怎么办

旧微信的记录不会自动带过去。可行做法：

1. **电脑版微信**：主空间微信 → 备份到电脑；切到微信区 → 从电脑恢复。
2. 微信自带的「聊天记录迁移」要求两台设备同网，切用户期间主空间不在线，同一台手机上用不了。

## 代价

- 用微信要切用户，切过去后主空间的其他 App 暂停（数据不会丢）。
- 微信只在「微信区」是当前用户时在线，消息、语音/视频通话会漏。
- 第一次切换要等系统初始化，可能要简单设置一下新用户。

## 兼容性 / 已知问题

- **SELinux（实测 ColorOS + Magisk）**：root shell 处于 `u:r:magisk:s0` 时，
  调用 `pm` / `cmd` / `am` 会报 `Failure calling service ... Failed transaction`。
  脚本会临时 `setenforce 0`，完成操作后自动恢复原来的状态。
- **ColorOS 应用分身（user 999, `profile.CLONE`）**：和主空间共享媒体与通讯录，
  不是隔离空间，本项目不使用。
- 有些 ROM 直接关闭多用户（`Max users: 1`），此时只能换方案。

实测环境：一加 Turbo 6X Pro（PYR110）· ColorOS 16（Android 16）· Magisk。

## FAQ

- **创建失败？** 看输出：`Max users` 已满或 ROM 禁用多用户时无法创建。
- **微信装不进微信区？** 重试 `pm install-existing --user <id> com.tencent.mm`，或在微信区里用应用商店安装。
- **想恢复原样？** `--remove` 删掉用户即可，主空间数据一直都在。
- **为什么没有权限收紧脚本？** 回收权限在系统设置里就能做，而且挡不住间接访问；真隔离只能靠独立用户。

## License

[MIT](LICENSE)

---

[![](https://img.shields.io/badge/powered_by-dsh-4D6BFE?style=flat-square&logo=deepseek&logoColor=white)](https://github.com/deepseek-ai/deepseek-harness)

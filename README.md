# 微信真隔离 wechat-isolate

用 Android 多用户把微信关进独立空间「微信区」：它有独立的数据分区和存储，
主空间的照片、文件、通讯录、其他应用数据它都看不到。再配一个「用户切换」App，一键往返。

> 为什么不用权限回收或系统自带的「应用分身」？
>
> - 回收权限在系统设置里就能做，挡不住间接访问；
> - ColorOS 应用分身（user 999，`profile.CLONE`）和主空间**共享媒体、共享通讯录**
>   （`mMediaSharedWithParent=true`），本质上不是隔离。
>
> 真正把微信和数据隔开，只能靠 Android 的用户隔离。

## 原理

1. `pm create-user` 建一个独立用户「微信区」（独立 `/data/user/<id>`、独立 `/storage/emulated/<id>`）
2. `pm install-existing --user <id>` 把微信安装进去（复用已有 APK，不用重新下载）
3. ColorOS 把系统自带的用户切换 UI 删了，所以配一个「用户切换」App：
   - **主空间点按钮**：先拉起一个 root watchdog，再 `am switch-user` 切过去
   - **微信区点按钮**：不需要 root，只写一个触发文件；主空间的 watchdog 收到后切回
   - 实测 Android 16 上 root 进程能跨用户存活，所以 watchdog 方案成立
4. Magisk 开机脚本兜底：重启后自动切回主用户

## 实测环境

一加 Turbo 6X Pro（PYR110）· ColorOS 16 / Android 16 · Magisk 30.7 · 微信 8.0.79

## 文件

| 文件 | 说明 |
| --- | --- |
| `wechat-isolate.sh` | 创建「微信区」、安装微信，以及切换/删除命令 |
| `back-watcher.sh` | 主空间的 root watchdog（轮询触发文件，收到就切回） |
| `install-userswitch.sh` | 安装「用户切换」App |
| `userswitch/` | App 源码 + 预编译 APK |

## 使用步骤

把文件放到 `/sdcard/Download/DSH-Go/`（App 里写死了 watchdog 路径），然后：

```sh
# 1. 创建微信区并把微信装进去（期间会临时 permissive，结束自动恢复）
su -c 'sh /sdcard/Download/DSH-Go/wechat-isolate.sh'

# 2. 安装「用户切换」App
su -c 'sh /sdcard/Download/DSH-Go/install-userswitch.sh'

# 3. 主空间打开「用户切换」→ 切到微信区
# 4. 在微信区登录微信；要回来就点「切回机主」
```

兜底：切过去以后如果 App 没反应，直接**重启手机**，开机脚本会切回主用户。

其他命令：

```sh
su -c 'sh .../wechat-isolate.sh --switch'        # 切到微信区
su -c 'sh .../wechat-isolate.sh --back'          # 切回主空间
su -c 'sh .../wechat-isolate.sh --remove'        # 删除微信区
su -c 'sh .../wechat-isolate.sh --uninstall-main'# 主空间卸载微信
```

首次切过去需要完成新用户的系统初始化；微信要重新登录。

## 已知限制

- **SELinux**：部分 ROM 的 root shell（Magisk 域）在 enforcing 下调用 `pm` / `am` 会被拦
  （`Failure calling service ... Failed transaction`）。脚本会临时 `setenforce 0`，结束后恢复；
  watchdog 也会在切换完成 5 秒后自动恢复 enforcing。
- **ColorOS 应用分身不是隔离**：user 999 是 `profile.CLONE`，和主空间共享媒体与通讯录。
- **没有系统用户切换 UI**：ColorOS 删掉了 `user_switcher_enabled` 对应的快捷入口，
  所以用「App + watchdog」补上。
- 微信区只在是当前用户时在线，消息、语音/视频通话会漏。
- 旧聊天记录不会跟过去：先在主空间用电脑版微信备份，切过去后恢复。
- 微信区里的 App 都是全新安装，需要重新登录（本工具不迁移应用数据）。

## 构建 App

`userswitch/build.sh` 在 Ubuntu / proot 里用 JDK + `aapt` + `dx` + `apksigner` 打包。
需要自己把 API 33 的 `android.jar` 放到 `userswitch/android.jar`（脚本不负责下载）。

```sh
cd userswitch
sh build.sh
# 产物：build/userswitch.apk
```

## License

[MIT](LICENSE)

---

[![](https://img.shields.io/badge/powered_by-dsh-4D6BFE?style=flat-square&logo=deepseek&logoColor=white)](https://github.com/deepseek-ai/deepseek-harness)

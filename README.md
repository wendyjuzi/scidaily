# 科研日报 SciDaily

## 成员 A 已完成范围

- 项目基础：统一配置、HTTP 请求封装、全局异常对象、本地登录态初始化、网络权限、SDK 6.1.0 构建配置。
- 用户账号：登录、注册、退出、token 会话、本地 Preferences 持久化、游客访问拦截、资料编辑、密码重置。
- 个人中心：个人主页、统计卡片、我的发布、我的收藏、我的点赞、浏览记录、账号安全、隐私设置、消息设置。
- 后端接口：FastAPI 用户表、会话表、设置表、个人中心四类数据表，覆盖注册/登录/退出、用户 CRUD、个人资料、密码、统计和列表接口。

## 成员 C 已完成范围

- 社区互动：在日报详情页接入点赞、收藏、互动计数、评论发布、评论回复、评论删除、最新/热门评论切换。
- 科研统计看板：新增 `科研数据看板` 页面，支持今日/本周/本月切换，展示日报数量、实验记录数量、文献学习数量与柱状趋势。
- 消息通知：新增 `消息通知` 页面，支持点赞、评论、系统通知列表，包含未读提示、单条已读、全部已读和清空。
- 后端接口：新增评论表、通知表和科研统计聚合接口，覆盖 `/api/v1/news/{news_id}/comments`、`/api/v1/news/{news_id}/interactions`、`/api/v1/users/me/research-stats`、`/api/v1/users/me/notifications`。

## 前端演示账号

- 用户名：`demo`
- 密码：`123456`

进入底部 `我的` 标签页后点击 `登录 / 注册` 登录，即可查看个人中心闭环。

## 不通过命令行运行

可以，前后端都能直接用 IDE 点运行。

### 1. PyCharm 启动后端

用 PyCharm 打开 `E:\project2\scidaily\backend`，第一次打开时先在右下角或 `Settings > Project > Python Interpreter` 配好 Python 解释器。然后打开 `requirements.txt`，如果 PyCharm 提示安装依赖，直接点安装即可。

这个后端当前默认不再强依赖 `scikit-learn`，所以直接安装 `requirements.txt` 就能跑登录、注册、个人中心这些核心接口；那类离线科研筛选功能是可选模块。

后端代码和默认依赖已按 Python 3.8 兼容处理，PyCharm 里使用 Python 3.8 虚拟环境也可以直接运行。

后端入口已经写在 `backend/main.py` 末尾，可以直接右键 `main.py`，选择 `Run 'main'`。启动成功后，在浏览器访问：

```text
http://127.0.0.1:8000/docs
```

能看到 FastAPI 接口文档，就说明后端已经跑起来了。

### 2. DevEco Studio 启动鸿蒙 APP

用 DevEco Studio 打开 `E:\project2\scidaily`，选择 `entry`，选择模拟器，然后点击顶部绿色运行按钮。

如果 APP 登录时连不上 PyCharm 后端，需要把前端接口地址从 `127.0.0.1` 改成电脑的局域网 IPv4：

```ts
// entry/src/main/ets/config/AppConfig.ets
export const API_BASE_URL: string = 'http://你的电脑IP:8000/api/v1';
```

例如电脑 IPv4 是 `192.168.1.23`，就改成：

```ts
export const API_BASE_URL: string = 'http://192.168.1.23:8000/api/v1';
```

如果仍然连不上，检查 Windows 防火墙是否允许 PyCharm/Python 访问 `8000` 端口。

## 完整前后端运行

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

后端核心新增接口位于 `/api/v1/auth/*`、`/api/v1/users/*`。

如果 APP 运行在模拟器或真机上，`127.0.0.1` 通常指设备自己，不一定是 Windows 电脑。需要把前端配置里的地址改成电脑局域网 IP：

```ts
// entry/src/main/ets/config/AppConfig.ets
export const API_BASE_URL: string = 'http://你的电脑IP:8000/api/v1';
```

电脑 IP 可在 PowerShell 执行：

```powershell
ipconfig
```

找到当前 Wi-Fi 或以太网下的 IPv4 地址，例如 `192.168.1.23`，则配置为：

```ts
export const API_BASE_URL: string = 'http://192.168.1.23:8000/api/v1';
```

然后用 DevEco Studio 运行 `entry`。此时登录、注册、个人资料、密码、设置和个人中心列表会优先访问后端，后端不可用时才回退到本地演示数据。

## 鸿蒙构建

本项目已按本机 HarmonyOS SDK 6.1.0(23) 调整：

- `build-profile.json5`
- `oh-package.json5`
- `hvigor/hvigor-config.json5`

可使用 DevEco Studio 6.1.1 Beta1 打开工程，或使用项目独立缓存目录构建。

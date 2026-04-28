# Nebula App Market / 星云应用市场

一个面向国内安卓应用商店场景的可交互原型：Android 客户端使用 Flutter，后端服务使用 Go 标准库实现。

## 项目亮点

- 精致的应用商店 UI：首页、分类、排行、详情、我的页面完整可交互
- 固定搜索栏、分类筛选、榜单切换、应用详情、截图预览
- 用户中心原型：登录弹窗、应用更新、下载管理、隐私权限、收藏预约、设置
- Go 后端提供应用列表、搜索、分类、排行、详情等只读 API
- Android 已设置正式应用名、包名和自定义启动图标

## 正式命名

- 中文名：`星云应用市场`
- 英文名：`Nebula App Market`
- Flutter 包名：`nebula_app_market`
- Android applicationId：`com.nebula.appmarket`
- 建议 GitHub 仓库名：`nebula-app-market`

## 项目结构

```text
nebula-app-market/
├── assets/   # 图标源文件等项目资产
├── mobile/   # Flutter Android 客户端
└── server/   # Go API 服务
```

## 启动后端

```bash
cd server
go run .
```

默认监听 `http://127.0.0.1:8080`，主要接口：

- `GET /api/health`
- `GET /api/apps`
- `GET /api/apps?q=英语`
- `GET /api/apps?category=工具`
- `GET /api/apps/{应用名}`
- `GET /api/categories`
- `GET /api/rankings?type=popular|rating|new`

## 启动 Android 客户端

```bash
cd mobile
flutter run
```

Android 模拟器访问宿主机服务使用 `http://10.0.2.2:8080`。如果后端没启动，客户端会自动使用内置离线数据。

## 构建 APK

```bash
cd mobile
flutter build apk --debug
```

构建产物位于：

```text
mobile/build/app/outputs/flutter-apk/app-debug.apk
```

## 当前功能

- 首页：固定搜索、分类快捷入口、精品 Banner、今日推荐、热门应用
- 分类：分类卡片、分类应用列表
- 排行：热门榜、新品榜、飙升榜、游戏榜横向切换
- 详情：评分、下载量、截图预览、介绍展开、安全检测
- 我的：登录、应用更新、下载管理、隐私权限、收藏预约、设置
- 后端：应用列表、搜索、分类、排行、详情、健康检查

## 后续可完善

- SQLite/PostgreSQL 数据库持久化
- 手机号验证码登录、Token、用户信息接口
- 收藏/预约/设置同步到后端
- 下载任务、更新任务真实接口
- APK 下载地址、包名、签名、SHA256、安全检测报告
- 评论评分、版本历史、权限清单、开发者后台

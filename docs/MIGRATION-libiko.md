# 改名迁移说明：ACGNhub → libiko

本次将项目由 `ACGNhub`/`acgnhub` 改名为 `libiko`（显示名 `Libiko`）。以下是对**已有安装/部署**有影响、需要人工处理的点。

## 后端（server/）
- 环境变量改名：`ACGHUB_DB_PATH` → `LIBIKO_DB_PATH`，`ACGHUB_JWT_SECRET` → `LIBIKO_JWT_SECRET`。
  - `LIBIKO_JWT_SECRET` 未设置时服务会直接退出。
- 默认数据库文件名：`acgnhub.db` → `libiko.db`（Docker `VOLUME /data`）。
- 升级旧部署时：更新 compose/k8s/`.env` 里的变量名，并把 `acgnhub.db` 重命名为 `libiko.db`（或设置 `LIBIKO_DB_PATH` 指向旧文件），否则会打开一个空库。

## Android
- `applicationId` 由 `com.acgnhub.acgnhub` 改为 `com.libiko.libiko`，是**新的应用标识**：旧安装无法覆盖升级，需重新安装，且本地数据不随包迁移。

## 客户端
- 图片缓存键由 `acgnhub_cache` 改为 `libiko_cache`：已有图片缓存失效（会重新下载）。
- 漫画 JS 源引擎内部全局名 `__acgnhub_*` → `__libiko_*`（仅运行时内部，无持久化影响）。

## 未改动
- 历史设计/计划文档 `docs/superpowers/**`、`opendesign/**` 保留原名。
- 远程仓库名与本地文件夹名不在本次改动内。

<p align="center">
  <img src="assets/branding/app_icon.png" width="150" alt="Libiko">
</p>

<h1 align="center">Libiko</h1>

<p align="center">一个把动漫、漫画、轻小说和 galgame 都塞进同一个窗口的聚合阅读器。</p>

---

## 这是个啥

追番开一个 App、看漫画开另一个、啃轻小说又得换第三个、找 galgame 还得在网页里翻来翻去——烦不烦？

Libiko 想干的事很简单：**一个 App，四种快乐**。不用来回切软件，不用记一堆网址，打开就能看。桌面端（Windows）和手机端（Android）都能跑。

## 四大快乐

### 动漫

- 聚合多个动漫源（内置 gimy、七色番、baimao、moonci、MXdm、xfdmneo、sorani），同一部番有多条线路，总有一条能播。
- 元数据来自 Bangumi / AniList / Jikan，评分、简介、角色、关联作品自动补齐。
- 搜索、追番、观看历史一条龙。
- 自带播放器：双击快进、长按倍速、横向拖拽调进度、滚轮翻页（桌面端翻页模式）、自由选集。
- 特意**没有弹幕**——只想安安静静看片。

### 漫画

- 兼容 Venera 的源脚本，内置 9 个源：再漫画、包子漫画、Komiic、MangaDex、漫画柜、拷贝漫画、Picacg、禁漫天堂、ehentai。
- 部分源支持登录，登录后解锁对应内容。
- 翻页 / 连续两种阅读模式，右侧进度条随手拖。
- 长图做了尺寸缓存与解码限宽，翻再长的条漫也不心疼内存。

### 轻小说

- 数据来自轻小说文库（linovelib）与轻之国度（lknovel）。
- 浏览、排行、搜索、分卷目录，找书不迷路。
- 阅读器支持插图、字号 / 行距调整、跟随系统深浅色，右侧进度条随时定位。

### 游戏

- 汇聚 NekoGAL、GalgameZywz 的 galgame 资源。
- 主页把封面、简介、截图、标签、发布日期一次摆好，点一下就能去原站。

## 顺手的细节

- 深浅色主题，白天黑夜都不刺眼。
- 追番 / 收藏 / 历史，配合自带的同步服务端（`server/`），换台设备也能接着看。
- 源可以自己导入、删除、排序——不满意就换。
- 桌面端和移动端同一套代码，界面各自适配。

## 跑起来

需要 Flutter 3.35+。

```bash
flutter pub get
flutter run -d windows     # 或 flutter run -d <android-device>
```

打包：

```powershell
# Windows 免安装压缩包 -> dist/
powershell -ExecutionPolicy Bypass -File tool\build_release.ps1

# Android 通用 APK -> dist/
powershell -ExecutionPolicy Bypass -File tool\build_android.ps1
```

## 技术栈

Flutter + Riverpod 写界面与状态；播放用 media_kit；源解析用 flutter_inappwebview 无头浏览器加 flutter_qjs；账号同步是一个自带的 Dart 服务端（见 `server/`）。

## 免责声明

Libiko 只做资源聚合，本身不存储任何内容。所有内容的版权归原网站与作者所有，请支持正版。

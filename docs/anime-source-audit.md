# 动漫源检查记录

检查日期：2026-11-02。以下为本机网络下的单次 HTTP 抽样，并非持续可用性或播放成功率统计。

后续用户播放反馈：七色番第一条线路无法播放。规则 1.5 已恢复之前的筛选方式，排除第一条线路，保留原来的后续线路；下面关于规则 1.4 的内容仅为当时检查记录。

所有请求使用 12～15 秒上限，没有绕过登录、验证码或访问限制。搜索词为“鬼灭”。

| 内置源 | 搜索 | 抽样剧集 | 观察 |
| --- | --- | --- | --- |
| 七色番 | HTTP 200，服务端 HTML 有结果 | `/voddetail/29232.html`，存在两条真实播放线路 | 原规则无条件排除第一条线路；规则 1.4 改为保留全部线路，仅提取 `/vodplay/` 链接 |
| moonci | HTTP 200，服务端 HTML 有结果 | `/anime/1937.html`，存在剧集列表 | 当前 `/play/` 子串选择器可匹配 `/anime/1937/play/1-1.html` |
| xfdmneo | HTTP 200，服务端 HTML 有结果 | `/bangumi/2176.html`，存在多条线路 | 搜索及 `anthology-list-play` 剧集结构仍与规则一致 |
| sorani | API HTTP 200，`data.records` 有结果 | 视频 ID 287，返回 26 集 | `episodeLabel`、`episodeOrder` 字段符合规则 |
| xfdmnext | API HTTP 200，数组有结果 | 视频 ID 3170，返回 1 条源、1 个剧场版条目 | `sources[].episodes[]` 与剧集 ID 字段符合规则 |

五个搜索请求在本次并行抽样中各约 1.5～2.3 秒完成；这不含 WebView 启动、排队和页面附属资源加载，不能当作客户端端到端耗时。

七色番抽样第一线路播放页 HTTP 200，其播放器数据指向嵌套页面 `https://www.lmm85.com/play/6429_1_1.html`；第二线路数据指向 MP4 地址。保留第一线路是恢复实际存在的候选，并不代表它已验证能在原生播放器播放。

本次验证到搜索、剧集及上述播放页数据，没有完成所有源的原生播放器首帧验证。不要据此将这五个源全部标为“播放可用”。后续应记录真实首帧成功、错误类型与各阶段耗时，再决定源排序或是否需要新增规则。

已用最小 XPath 文档验证七色番新规则保留两条线路，且排除 `javascript:` 展开按钮。仓库的规则加载测试可继续验证 JSON 解析兼容性。

## 2026-11-03 实际播放验证与修复

已增加独立 Windows 实播工具，不读取应用账号、数据库或个人历史。每个样本从搜索与获取剧集开始，使用新的原生 Player 和 VideoController；通过条件是首帧已渲染、视频尺寸有效、实际进度与观察时间均达到 10 秒、无起播错误。拖动结果独立记录，不将地址解析成功视为播放成功。

执行了五源十样本全量检查，以及七色番隔离复测、修复后的五源连续复测。下表为多轮抽测的实际覆盖，不代表每个源所有作品都可播放；网络和源站资源存在波动。

| 源 | 已验证播放的作品 | 仍未通过的样本或限制 |
| --- | --- | --- |
| 七色番 | 《鬼灭之刃 柱训练篇》《葬送的芙莉莲》；1080P、持续播放和拖动通过 | 全量检查末尾曾出现本机组件异常；隔离与后续连续检查可正常播放。仍保留用户要求的单线路筛选 |
| moonci | 《鬼灭之刃》及前轮抽测的《无限城篇 第一章》；1080P、持续播放和拖动通过 | 《葬送的芙莉莲》第一季／第二季样本未通过解析或起播 |
| xfdmnext | 《无限城篇 第一章》；1080P、持续播放和拖动通过 | 《葬送的芙莉莲》第一季／第二季样本未通过解析或起播 |
| sorani | 本轮无通过样本 | 两作品未解析出地址；《鬼灭之刃》的源站公开元数据标注 `level=3`、`levelText=登录可见`、`free=false`，未尝试绕过登录 |
| xfdmneo | 本轮无通过样本 | 两作品的已发现候选在原生播放器打开失败，不能因搜索和剧集接口正常就标记可播放 |

原始本机报告位于忽略目录 `dist/playback-audit/`：`initial`、`verified`、`final` 为全量检查，`7sefun-isolated` 为隔离检查，`recovery-check` 为修复实例复用问题后的连续检查。每轮有 `report.json`、`report.md`，包括规则版本／SHA256、阶段耗时、画面尺寸、进度与拖动证据；不包含媒体完整地址和签名参数。

### 已处理的本机故障与后续播放流程

- 抓取发生异常后，淘汰浏览器实例；原生组件异常只在同一总期限内用新实例重试一次。解析器也不再回收失败的导航实例供下一个源使用。
- 初轮日志出现过 Windows `CO_E_NOTINITIALIZED`。新增平台线程上的 STA 状态检查与缺失时恢复保护，已用原生测试验证连续十次初始化／释放、无引用累积和拒绝改变已存在的 MTA。实际连续复测的恢复计数为 0，不能据此声称已定位所有第三方组件故障。
- 平台要求依据：[CoGetApartmentType](https://learn.microsoft.com/en-us/windows/win32/api/combaseapi/nf-combaseapi-cogetapartmenttype)、[CoInitializeEx](https://learn.microsoft.com/en-us/windows/win32/api/combaseapi/nf-combaseapi-coinitializeex)。
- 播放器内候选、重新解析与同源换线失败后，可尝试最多两个其他已高置信匹配的源；只按唯一集标识继续，并保留实际进度，不按列表下标猜集。
- 下一集预解析延迟到稳定播放五秒后，单任务去重；暂停、缓冲、后台和恢复时取消。诊断保留阶段、耗时与恢复结果并脱敏，播放器样式保持原样。

### 复现命令

```powershell
# 默认五源、两作品。检查后自动恢复正常应用构建。
& ./tool/test_playback_sources.ps1 -TestSeek

# 仅复测七色番。
& ./tool/test_playback_sources.ps1 -Sources @('七色番') -TestSeek

# 原生运行时保护测试。
cmake -S tool/native_webview_test -B build/native-webview-test -A x64
cmake --build build/native-webview-test --config Release
& ./build/native-webview-test/Release/webview_runtime_test.exe
```

工具目前验证 Windows、本机网络和所列样本；未验证 Android 真机，也未完成整集或长时间稳定性测试。

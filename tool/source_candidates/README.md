# 待验证源

此目录不在 Flutter 资源清单中，不会加入用户的默认源列表。

`mgnacg.json` 基于 https://github.com/Predidit/KazumiRules/blob/main/mgnacg.json （MIT，许可见同目录），补充本项目 API 搜索的 `sourceTemplate`。当前仅验证搜索和剧集提取，不能标记可播放。复测时将候选复制至 `assets/source_rules/`，运行 `tool/test_playback_sources.ps1 -Sources @('mgnacg') -TestSeek`，结束后移回，避免把实验规则随应用发布。

详细结果见 `docs/anime-source-audit.md`。

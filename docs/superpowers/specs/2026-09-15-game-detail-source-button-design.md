# 游戏详情页「在原站打开」按钮位置与样式设计

日期：2026-09-15
状态：已与用户确认

## 背景

游戏详情页的「在原站打开」目前是顶栏的一个 `IconButton`（`Icons.open_in_new_rounded`）。用户希望把它移到信息卡里封面旁边（标签下方），并改成与其他页面收藏按钮一致的样式。

## 目标

- 移除顶栏的「在原站打开」按钮。
- 在信息卡封面右侧列、**标签下方**，加入 `FilledButton.icon`「在原站打开」，样式对齐收藏按钮。
- 点击用系统浏览器打开源站详情页；加载中（`sourceUrl` 为空）禁用。

## 非目标

- 不改其它页面；不改详情页其它布局；不新增收藏功能。

## 设计

### `lib/modules/game/game_detail_page.dart`

1. `_header`：移除「在原站打开」`IconButton`；签名去掉 `GameDetail? detail` 参数；`build` 中调用改为 `_header(context)`。

2. `_infoCard`：在右侧列的 `Wrap(tags)` 之后加入（`const SizedBox(height: 10)` + 按钮）：

```dart
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: detail.sourceUrl.isEmpty
                        ? null
                        : () => _openSource(detail.sourceUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('在原站打开',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
```

- `_openSource(String url)` 不变（`launchUrl(uri, mode: LaunchMode.externalApplication)`）。
- 加载态传入的合成 `GameDetail(sourceUrl: '')` 使按钮禁用。

### 测试

- `test/modules/game/game_detail_page_test.dart`：把 `expect(find.byTooltip('在原站打开'), findsOneWidget);` 改为 `expect(find.text('在原站打开'), findsOneWidget);`。

## 错误处理

- `sourceUrl` 为空（加载中）→ 按钮 `onPressed` 为 `null`（禁用）。
- `launchUrl` 失败不改变 UI（与现状一致）。

## 后续迭代（不在本版）

- 若将来加入游戏收藏，可在同一位置并列「收藏」按钮。

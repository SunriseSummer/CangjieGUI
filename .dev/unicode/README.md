# Unicode 字素数据

排版和文本编辑共享 Unicode 17.0.0 的扩展字素规则（[UAX #29 revision 47](https://www.unicode.org/reports/tr29/tr29-47.html)）。旧版 General Category Mark 近似表已移除。

`sources.json` 固定 GraphemeBreakProperty、Extended_Pictographic、Emoji／Emoji_Presentation、Indic_Conjunct_Break 数据及官方测试文件的 URL 和 SHA-256。`generate.py` 将属性合并为 913 个不重叠区间；Hangul LV/LVT 按公式计算，避免大量重复区间。生成的五个常量表及状态机统一位于 CangjieSDL 的 `src/text/`，供字体后备、CangjieGUI 排版与编辑共享；运行时不保留两份 Unicode 表。

```powershell
python .dev/unicode/generate.py
# 按项目 cangjie-format.toml 对生成的五个 .cj 文件运行 cjfmt。
cjpm test src/core --filter "unicode17OfficialGraphemeBreakConformance"
```

默认从 `target/dev/text-quality/unicode` 复用下载文件，缺失时下载并验证摘要；可用 `--cache` 指向预先准备的目录。`--output` 可写入临时目录以核对再现结果。仅主动升级 Unicode 时使用 `--record` 更新摘要。

仓库保留原始 `GraphemeBreakTest.txt` 的 766 组样本，单元测试直接读取并逐例断言，缺失时失败，不静默跳过。数据许可见 [LICENSE.txt](LICENSE.txt)。

生成入口委托相邻 CangjieSDL 仓库的维护工具，并同步本仓库的测试数据、来源清单和许可。需要两个仓库均存在；不会重新生成 CUI 内部的重复属性表。

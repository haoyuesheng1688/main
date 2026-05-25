# 全局 Skill 和知识库索引

更新时间: 2026-05-14

## 正式全局 Skill

这些位于 `skills/`，适合作为跨项目的优先入口。

| Skill | 路径 | 用途 |
| --- | --- | --- |
| `aspen-spray-dryer-reader` | `skills/aspen-spray-dryer-reader/` | 连接已打开的 Aspen Plus，读取喷雾干燥相关界面数据。 |
| `eplan-io-closed-loop` | `skills/eplan-io-closed-loop/` | 连接 EPLAN Electric P8，导出 PLC IO 点表并形成闭环摘要。 |
| `excel-psychrometric-tool` | `skills/excel-psychrometric-tool/` | 创建或刷新湿空气 Excel 计算工具。 |
| `tia-openness-bag-pulse` | `skills/tia-openness-bag-pulse/` | TIA Portal V17 Openness、PLC/HMI 标签、画面、脚本、袋脉冲逻辑等闭环自动化。 |

## 软件/领域发布仓库

这些目录按软件或工具拆分，适合独立发布、安装或继续维护。

| 目录 | 主要 Skill | 备注 |
| --- | --- | --- |
| `1stOpt-V11/` | `1stopt-verify` | 1stOpt V11 本地窗口验证。 |
| `200smart-V28/` | `s7-200smart` | STEP 7-Micro/WIN SMART V2.8 工作流。 |
| `200SMART-V30/` | `s7-200smart` | STEP 7-Micro/WIN SMART V3 工作流，当前位于 `.codex/skills/`。 |
| `Aspen-Exchanger-V11/` | `aspen-edr-shell-tube-verify` | Aspen EDR shell-and-tube 验证。 |
| `AutoCAD-2026/` | `autocad-mechanical-2026` | AutoCAD Mechanical 2026 COM 绘图验证。 |
| `Eplan-V29/` | `eplan-io-closed-loop` | EPLAN IO 闭环导出仓库。 |
| `Hmismart-V5/` | `wincc-flexible-smart-v5` | WinCC flexible SMART V5 标签和界面读取。 |
| `office-repo/` | `office-desktop-assistant`, `excel-psychrometric-tool` | Word/Excel 桌面自动化和湿空气工具。 |
| `Photoshop-2024/` | `photoshop-cutout` | Photoshop 主体抠图和导出。 |
| `SolidWorks-2024-publish/` | `solidworks-geometry-airflow` | SOLIDWORKS 几何面积、风量和动压计算。 |
| `TIA-V17-repo/` | `tia-openness-bag-pulse` | TIA V17 发布仓库，含 `knowledge/` 和 skill references。 |
| `Ubuntu/` | `wsl-ubuntu-control` | Windows 上通过 WSL 控制 Ubuntu。 |
| `Wps/` | `wps-excel-case`, `wps-word-insert-text`, `wps-word-weather` | WPS 表格/文字自动化。 |

## 知识库位置

| 位置 | 内容 | 维护建议 |
| --- | --- | --- |
| `docs/` | 全局说明、TIA 操作手册、项目索引。 | 项目级说明放这里。 |
| `TIA-V17-repo/knowledge/` | TIA V17 HMI 高级对象等专题知识。 | 与 TIA 发布仓库同步维护。 |
| `skills/*/references/` | skill 专属参考资料。 | 只放触发该 skill 时有用的材料。 |
| `TIA-V17-repo/skills/tia-openness-bag-pulse/references/` | TIA skill 发布版参考资料。 | 与全局 `skills/tia-openness-bag-pulse/references/` 定期对齐。 |
| `_research/` | 原始研究、截图 OCR、临时分析材料。 | 需要沉淀时再整理进 `docs/` 或 `references/`。 |
| `tia_*_learning/`, `tia_exports/`, `tia_hmi_knowledge/` | TIA 学习、导出、验证材料。 | 有结论的内容沉淀到 TIA skill references 或 `TIA-V17-repo/knowledge/`。 |

## 清理结果

2026-05-14 已将根目录中的截图、dump、探针文本、松散工程文件和一次性测试目录移动到:

`_archive/2026-05-14-cleanup/`

归档后根目录只保留项目入口目录和少量尚需人工确认的摘要文件，后续新增证据请直接放入新的 `_archive/<date>-<topic>/`。

## 后续规范

- 新 skill: 放在独立发布 repo 的 `skills/<skill-name>/`，成熟后可复制或同步到全局 `skills/`。
- 新知识库: 优先放到 `docs/` 或对应 skill 的 `references/`。
- 新验证证据: 放到 `_archive/<date>-<topic>/proof/`，不要散落在项目根目录。
- 新临时脚本: 一次性脚本归档；可复用脚本进入 `scripts/` 或对应 skill 的 `scripts/`。

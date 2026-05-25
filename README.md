# Global Codex Skill and Knowledge Workspace

本目录是本机 Codex 可复用工作流的全局项目区，主要保存已经验证过的 skill、软件自动化 repo、知识库材料和运行证据归档。

## 目录边界

- `skills/`: 全局汇总 skill 区。这里放跨项目可直接复用的 skill，优先保持精简、可安装、可验证。
- `*-repo/` 或按软件命名的目录: 面向单个软件或工具的发布仓库，例如 `TIA-V17-repo/`、`office-repo/`、`Wps/`、`200smart-V28/`。
- `docs/`: 项目级说明、操作手册、全局索引和知识库导航。
- `scripts/`: 项目级辅助脚本。具体 skill 的脚本应优先放在对应 skill 的 `scripts/` 下。
- `_research/`: 原始调研材料，未必都是正式知识库。
- `_archive/`: 清理出的截图、dump、探针文件、一次性测试目录和历史证据。归档内容默认不参与正式维护。

## 使用入口

- 全局 skill 和知识库索引: `docs/GLOBAL_SKILL_KB_INDEX.md`
- 汇总 skill 维护规则: `skills/README.md`
- 最近清理归档说明: `_archive/2026-05-14-cleanup/README.md`

## 维护原则

1. 正式 skill 必须有 `SKILL.md`，并尽量包含 `references/`、`scripts/`、`assets/` 等清晰边界。
2. 一次性截图、探针、dump、临时导出文件不要放在根目录；需要保留时放入 `_archive/<date>-<topic>/`。
3. 知识库材料优先放在 `docs/`、repo 内 `knowledge/` 或 skill 内 `references/`，不要散落在根目录。
4. 发布型 repo 保留自己的 `README.md`，全局索引只负责导航，不复制大段内容。

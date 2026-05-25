# Global Skills

这里是当前全局项目的汇总 skill 区。放在这里的 skill 应当已经经过至少一次真实工作流验证，并且可以被 Codex 直接按 `SKILL.md` 使用。

## 当前 Skill

| Skill | 主要用途 |
| --- | --- |
| `aspen-spray-dryer-reader` | 已打开 Aspen Plus 会话的数据读取。 |
| `eplan-io-closed-loop` | EPLAN IO 点表导出和闭环摘要。 |
| `excel-psychrometric-tool` | 湿空气 Excel 计算工具生成或刷新。 |
| `tia-openness-bag-pulse` | TIA Portal V17 Openness、袋脉冲逻辑、HMI 标签/画面/脚本闭环。 |

## 维护规则

1. 每个 skill 必须包含 `SKILL.md`，并保持 frontmatter 的 `name` 和 `description` 清晰可触发。
2. `SKILL.md` 只保留核心流程；长说明、案例、故障表放进 `references/`。
3. 自动化代码放进 skill 自己的 `scripts/`，不要散落到项目根目录。
4. 验证截图、临时导出和 proof 文件放入 `_archive/`，不要放在 skill 根目录。
5. 与发布 repo 重复的 skill，要在 `docs/GLOBAL_SKILL_KB_INDEX.md` 标注主维护位置，避免两边长期漂移。

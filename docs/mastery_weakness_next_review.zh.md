# Mastery、Weakness、Next Review 指标说明（V1）

本文档描述 iOS 客户端 **听写记忆模型 V1** 中三个用户可见指标的计算方式与界面展示规则。实现入口：`WordMasteryUpdater.applyAttempt`（`ios/Motifly/Services/WordMasteryUpdater.swift`），在每次听写提交并成功写入 `DictationAttemptLog` 后，对对应 `seedNumber` 的 `DictationWordStats` 就地更新。

---

## 一、数据前提

- 所有数值都挂在 **`DictationWordStats`**（按词条 `seedNumber` 唯一）上。
- 每次提交会传入 **按 `submittedAt` 升序排列** 的近期 `DictationAttemptLog` 列表（含本次新记录）。滑动窗口取 **最近 10 条**：`recentWindow = 10`。
- **Weakness 的计数**仅对 **拼写家族** 错题递增（见下文「Weakness」）；`listening` / `other` 会记在单条 log 上，**不增加**五个拼写子桶。

---

## 二、Mastery（掌握度）

### 2.1 算法含义

**Mastery** 展示的是综合分 **`overallMastery`**（0–100，四舍五入为整数百分比），由多个「技能分」加权得到；未测量的能力用中性分 **70** 占位，避免在功能上线前把总分拉极端。

### 2.2 滑动窗口内先算四个技能分（均在 0–100 内裁剪）

记窗口长度为 \(W = \max(1, \text{窗口条数})\)。

| 技能分 | 含义 | 公式要点 |
|--------|------|----------|
| **dictationScore** | 近期听写正确率 | \(\text{窗口内正确条数} / W \times 100\) |
| **spellingScore** | 拼写清洁度 | 窗口内每条 log 若 `errorType` 属于拼写家族（含历史 `spelling` / `accent` / `article` 等），计 1 次拼写失误；\(\text{spellingScore} = 100 - (\text{拼写失误数}/W)\times 100\) |
| **listeningScore** | 少重听 | 窗口内 `replayCount` 之和为 \(R\)，平均 \(\bar r = R/W\)；\(\text{listeningScore} = 100 - \min(\bar r, 4)\times 20\)（重听越多分越低，平均 4 次及以上时该项趋近 0） |
| **meaningScore** | 少用翻译提示 | 窗口内 `usedHint == true` 的条数占比为 hint 率；\(\text{meaningScore} = 100 - \text{hint率}\times 100\) |

另：**difficulty**（0–10，存在模型里但词卡三 chip 不直接展示）为  
\(\text{difficulty} = \text{clamp}(0, 10,\ 10 \times (1 - \text{终身正确率}))\)，  
终身正确率 = `correctCount / max(1, attemptCount)`（全历史，非仅窗口）。

**meaningBlend**（参与总分的「语义」混合）：

\[
\text{meaningBlend} = (\text{meaningScore} + 70) / 2
\]

### 2.3 overallMastery 加权合成

令中性分 `neutral = 70`：

\[
\begin{aligned}
\text{overallMastery} = \text{clamp}_{0}^{100}\big(
&0.20 \times 70 \\
&+ 0.25 \times \text{listeningScore} \\
&+ 0.25 \times \text{dictationScore} \\
&+ 0.15 \times \text{spellingScore} \\
&+ 0.10 \times \text{meaningBlend} \\
&+ 0.05 \times 70
\big)
\end{aligned}
\]

以上系数为当前代码固定权重；写入 `DictationWordStats.overallMastery`。

### 2.4 界面「Mastery」实际显示什么

| 场景 | 显示 |
|------|------|
| 有 `DictationWordStats` 且 `overallMastery != nil` | `NN%`（`overallMastery` 四舍五入） |
| 有统计行、`overallMastery == nil` 但 `attemptCount > 0`（例如旧数据尚未重算） | `NN%`（**终身** `correctCount/attemptCount` 四舍五入，作为回退） |
| 无统计行，或 `attemptCount == 0` | `—` |

实现：`WordMasteryHeader`（词卡顶部三 chip）；复习列表里同一套百分比的展示逻辑见 `DictationReviewView.masteryPercent`（优先 `overallMastery`，否则历史正确率）。

---

## 三、Weakness（主要薄弱点）

### 3.1 算法含义

**Weakness** 来自 **`mainWeakness`**：在五个 **拼写子类型** 的累计计数中选 **计数最大** 的那一类；若五类全为 0，则为 `nil`。

五个桶与存储的 raw 值对应关系：

| 存储值 (`mainWeakness`) | 统计字段 |
|-------------------------|----------|
| `spelling_extra` | `spellingExtraCount` |
| `spelling_missing` | `spellingMissingCount` |
| `spelling_vowel` | `spellingVowelCount` |
| `spelling_consonant` | `spellingConsonantCount` |
| `spelling_mixed` | `spellingMixedCount` |

每次提交时，根据本次错题的 **`DictationErrorKind`**（由 `DictationErrorClassifier` 结合输入、期望词形、重听次数等判定）调用 `bumpErrorBucket`：**仅**上述五类会 `+1` 对应桶，并增加总拼写错题计数 `spellingErrorCount`。  
**`listening` / `other` / `none` 不增加任何拼写桶**，因此不会单独成为 `mainWeakness`（`mainWeakness` 始终是五种 `spelling_*` 之一或空）。

平局时：`max` 取到的「最大」那一项（实现上为 `buckets.max` 的稳定结果）。

### 3.2 界面「Weakness」显示字段

| `mainWeakness` | 用户可见文案（中文语境下 app 为英文标签） |
|----------------|------------------------------------------|
| `nil`（五桶均为 0） | **On track**（chip 为绿色强调） |
| `spelling_extra` | Extra letter |
| `spelling_missing` | Missing letter |
| `spelling_vowel` | Vowel spelling |
| `spelling_consonant` | Consonant spelling |
| `spelling_mixed` | Mixed spelling |

无 `DictationWordStats` 行时：显示 **`—`**（与 On track 不同）。

映射函数：`DictationErrorKind.weaknessDisplayName(forStored:)`。若将来库里出现旧 raw（如 `spelling` / `accent` / `article`），会有对应友好名（Spelling / Accent / Article）。

**复习列表**：在 mastery 列下方，若有 `mainWeakness`，会以 **橙色胶囊** 显示同一套 `weaknessDisplayName` 文案。

---

## 四、Next Review（下次复习）

### 4.1 算法含义

每次在 `applyAttempt` 末尾根据 **本条提交** 的结果更新 **`nextReviewDate`** 与 **`lastIntervalDays`**（并写 `lastReviewedAt = now`）。规则为简化间隔重复，**非 FSRS**：

记 `prior = previousIntervalDays ?? 1`（单位：天）。

| 条件 | 新间隔（天） |
|------|----------------|
| 本次 **错误** (`!isCorrect`) | `1` |
| 本次 **正确**，但 **用了 hint** 或 **耗时 > 8000 ms** | `2` |
| 本次 **正确**，且未 hint、耗时 ≤ 8000 ms | `max(2, prior × 1.7)` |

最后：**间隔上限 30 天**：`interval = min(计算值, 30)`。  
**下次复习时刻**：`nextReviewDate = now + interval × 86400` 秒。

### 4.2 界面「Next review」显示字段

基于 `nextReviewDate` 与 **当天日历日** 的差值（按起算日 `startOfDay`）：

| 条件 | 显示 |
|------|------|
| 无 `nextReviewDate` | `—` |
| 日期早于今天 | **Overdue** |
| 今天 | **Today** |
| 明天 | **Tomorrow** |
| 更晚 | **In Nd**（N 为相差整天数） |

chip 标题为 **Next review**，文案为英文（与当前 `WordMasteryHeader` 一致）。

---

## 五、词卡三 chip 小结（用户可见）

| Chip 标题 | 主要数据来源 | 典型显示 |
|-----------|----------------|----------|
| **Mastery** | `overallMastery` → 回退终身正确率 | `NN%` 或 `—` |
| **Weakness** | `mainWeakness` → `weaknessDisplayName` | On track / 五类拼写文案 / `—` |
| **Next review** | `nextReviewDate` | Overdue / Today / Tomorrow / In Nd / `—` |

颜色提示：`Weakness` 在 **无 mainWeakness** 时为绿色 tint，**有薄弱类型** 时为橙色 tint；`Mastery` 蓝色、`Next review` 绿色（见 `WordMasteryHeader`）。

---

## 六、相关代码与扩展阅读

- 核心更新：`ios/Motifly/Services/WordMasteryUpdater.swift`
- 错题类型与展示名：`ios/Motifly/Services/DictationErrorClassifier.swift`（`DictationErrorKind`、`DictationErrorClassifier`）
- 持久化模型：`ios/Motifly/Models/DictationWordStats.swift`
- 词卡顶部 UI：`ios/Motifly/Views/WordMasteryHeader.swift`
- 复习列表 mastery + weakness 列：`ios/Motifly/Views/DictationReviewView.swift`
- 设计长文：`docs/french_dictation_memory_model.md`（与代码注释中的 § 引用一致）

---

*文档与仓库实现同步；若后续调整权重或窗口长度，以 `WordMasteryUpdater` 为准并更新本节。*

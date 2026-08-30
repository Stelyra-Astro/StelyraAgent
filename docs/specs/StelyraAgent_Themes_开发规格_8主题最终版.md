# StelyraAgent Themes 功能开发规格（8 主题最终版）

> 本文在原《StelyraAgent Themes 功能完整设计》及 AI Contract 补全版基础上更新。
>
> 本版以 8 个一级 Theme 为唯一产品组织方式：
>
> `Love & Relationships / Career & Purpose / Money & Growth / Family & Home / Self & Wellbeing / Creativity & Expression / Learning & Exploration / Life Direction`
>
> 本次更新重点：
>
> 1. 将原来的 Love & Dating、Relationship、Family、Career、Money、Year Ahead 等入口重新收敛到上述 8 个 Theme；
> 2. `Love & Relationships` 同时支持“单人爱情状态”和“具体双人关系”两种分析模式；
> 3. `Family & Home` 同时支持“家庭/居所阶段”与“Primary + 0–3 位家庭成员”的一对多分析；
> 4. 02–17 合盘子盘目前均已具备调用能力，但 Theme Planner 只按产品语义调用真正需要的盘，不因“能算”而全部加入一次分析；
> 5. 轮盘 Renderer 已另行开发，本规格不要求重新实现轮盘绘制；
> 6. 现代/古典/特殊预设参数设置不属于本文开发范围，Themes 直接调用已经确定好的计算能力；
> 7. 补全 8 个 Theme 的 Chart Recipe、传给 AI 的 deterministic Evidence、用户参数、Prompt Module、输出 JSON 和验收规则。

---

# 1. 功能定位

新增一级功能 **Themes**。

Themes 不是让用户先理解并选择某一种专业盘，而是：

> 用户先选择现实生活主题，填写人物、时间、地点和少量背景信息；系统再自动决定需要调用哪些已存在的盘型，完成确定性计算，并将这些事实组织成一份综合 Theme Analysis。

产品层级：

```text
Today
当前天象、近期事件、日常提醒

Charts
按专业盘型查看轮盘和单盘内容

Themes
围绕现实生活主题进行多盘综合分析

Ask
针对一个具体问题进行 Horary / Timing 分析

Profile
账户、人物、订阅、设置
```

底部一级导航：

```text
Today    Charts    Themes    Ask    Profile
```

Themes 核心流程：

```text
选择 Theme
    ↓
填写现实参数
    ↓
Analyze · 2 Credits
    ↓
Theme Planner 生成 Chart Recipe
    ↓
调用现有计算能力
    ↓
得到确定性 Chart Facts / Chart Artifacts
    ↓
结果页立即可查看已完成轮盘
    ↓
ThemeFactsBuilder 聚合事实
    ↓
Relay 生成一份统一 Theme Report
    ↓
保存 ThemeAnalysis
```

用户不需要知道“为什么这次用了组合次限对比盘而不是时空三限盘”。

**Theme Planner 负责盘型选择，用户负责描述自己想分析什么。**

---

# 2. 第一版 Theme 类型

第一版固定为以下 8 个一级 Theme，**名称和入口结构以此为准**：

| Theme | 人数结构 | 核心用途 |
|---|---:|---|
| **Love & Relationships** | 单人 / 双人 | 自己的恋爱模式、当前爱情阶段，或与某个具体人的关系结构和关系阶段 |
| **Career & Purpose** | 单人 | 职业路径、工作阶段、贡献方式、方向与机会 |
| **Money & Growth** | 单人 | 资源、安全感、收入/支出主题、扩张与成长阶段 |
| **Family & Home** | 单人 / 一对多 | 家庭、居所、归属与根基；可附加自己与 1–3 位家庭成员的关系 |
| **Self & Wellbeing** | 单人 | 当前内在状态、情绪节奏、能量、自我关系、压力与恢复 |
| **Creativity & Expression** | 单人 | 创造力、自我表达、个人项目、灵感与输出节奏 |
| **Learning & Exploration** | 单人 | 学习、技能、知识拓展、旅行、探索与新视角 |
| **Life Direction** | 单人 | 当前人生章节、身份变化、长期方向与未来重点 |

第一版不再设置独立：

```text
Love & Dating
Relationship
Family
Career
Money
Year Ahead
```

其中原 `Relationship` 的深度双人能力并未删除，而是并入：

```text
Love & Relationships
└── Analysis Mode = Specific Relationship
```

原 `Family` 并入：

```text
Family & Home
└── Optional Family Members = 0...3
```

原 `Year Ahead` 不再作为一级 Theme；用户在任一适用 Theme 中选择 `1 Year` 时，由该 Theme 自己调用 Solar Return / Secondary / Solar Arc / Transit 等年度证据。

---

# 3. Theme 与 Charts / Ask 的边界

## Charts

用户以“盘”为入口：

```text
Natal
Transit
Secondary Progression
Tertiary Progression
Solar Arc
Solar Return
Lunar Return
Synastry
Composite
...
```

核心问题：

> 我想看这张盘。

## Themes

用户以现实生活领域为入口：

```text
我的职业和人生目标现在处于什么阶段？
我和 Amy 这段关系最近在发生什么变化？
我现在的内在状态和恢复节奏怎样？
我接下来适合把学习和探索重点放在哪里？
```

核心问题：

> 我关心这个生活主题，系统替我决定应该调用哪些盘。

## Ask

处理一个具体问题：

```text
我会拿到这个 Offer 吗？
他会联系我吗？
我们什么时候可能再次见面？
```

Themes 不应演化成 Horary/Yes-No，也不要求用户必须输入一个具体事件问题。

---

# 4. 当前合盘能力在 Themes 中的使用原则

`5-合盘.zip` 中按 01–17 编号组织。

当前状态：

- **01 合盘总览**是入口/总览，不作为独立计算 Evidence；
- **02–17 共 16 个具体合盘子盘型目前都已经可以调用**；
- Themes 只负责 orchestration，不重新实现其中任何一个算法；
- “全部可用”不等于“一次 Theme 全部调用”。

关系盘默认只在以下场景进入 Theme Planner：

```text
Love & Relationships
└── Specific Relationship

Family & Home
└── Optional Family Members
```

其他 6 个单人 Theme 默认不调用 02–17。

---

# 5. 合盘 02–17 的 Themes 分级

| 编号 | 盘型 | Theme 中的定位 |
|---:|---|---|
| 02 | 对比盘A / Synastry A | **双人关系核心 Evidence** |
| 03 | 对比盘B / Synastry B | **双人关系核心 Evidence** |
| 04 | 组合盘 / Composite | **Specific Relationship Foundation 核心** |
| 05 | 组合行运盘 | **Specific Relationship Timing 核心** |
| 06 | 组合次限盘 | 08 的支持/依赖盘；默认不与 08 重复进入 AI |
| 07 | 组合三限盘 | 09 的支持/依赖盘；默认不与 09 重复进入 AI |
| 08 | 组合次限对比盘 | **Specific Relationship 中长期 Timing 核心** |
| 09 | 组合三限对比盘 | **Specific Relationship 短周期条件使用** |
| 10 | 时空盘 | 已可用；**高级可选，不进入第一版默认 Recipe** |
| 11 | 时空行运盘 | 已可用；高级可选 |
| 12 | 时空次限盘 | 已可用；高级可选 |
| 13 | 时空三限盘 | 已可用；高级可选 |
| 14 | 马盘A | 已可用；主观体验类高级可选 |
| 15 | 马盘B | 已可用；主观体验类高级可选 |
| 16 | 马盘次限 | 已可用；主观体验时间演变高级可选 |
| 17 | 马盘三限 | 已可用；主观体验短期演变高级可选 |

### 默认关系 Evidence Tier

```text
Tier 1 — Foundation
02 + 03 merged Synastry
04 Composite

Tier 2 — Timing
05 Composite Transit
08 Composite Secondary Compare

Tier 3 — Short-term Detail
09 Composite Tertiary Compare

Available but not default
10–17
```

### 06/07 与 08/09

如果 08/09 已完整表达：

```text
原 Composite
vs
推进后的 Composite
```

则：

```text
08 → includeInAIFacts = true
06 → dependency / artifact only

09 → includeInAIFacts = true
07 → dependency / artifact only
```

不要把同一推进事实重复喂给 AI。

### 10–17

02–17 现在全部可以用，所以底层能力不得删除或降级。

但第一版默认 Theme Recipe 不因为“已经开发好了”就加入 10–17。原因是它们会显著增加平行证据、解释冲突和 token 密度。

未来如果产品新增：

```text
Advanced Relationship
How We Experience Each Other
Davison / Midpoint Layer
```

只需扩展 Planner / ThemeDefinition，不需要再开发这些 Chart 算法。

---

# 6. Theme 通用输入模型

所有 Themes 使用同一个 `ThemeSetupView`，由 `ThemeDefinition` 决定字段。

建议模型：

```swift
enum ThemeKind {
    case loveRelationships
    case careerPurpose
    case moneyGrowth
    case familyHome
    case selfWellbeing
    case creativityExpression
    case learningExploration
    case lifeDirection
}
```

以及：

```text
ThemeDefinition
ThemeFieldDefinition
ThemeInput
ThemeRequest
ThemeChartRecipe
ThemeChartTask
ThemeAnalysis
```

不要为 8 个 Theme 复制 8 套完整 Setup View。

建议：

```text
ThemeSetupView
      ↓
ThemeDefinition
      ↓
动态生成字段
```

---

# 7. 通用时间周期

8 个 Theme 共用：

```text
Now
3 Months
6 Months
1 Year
```

内部：

```swift
enum ThemeHorizon {
    case now
    case threeMonths
    case sixMonths
    case oneYear
}
```

用户不填写“次限推进到哪一天”“三限目标日是哪一天”。

Theme Planner 根据 Horizon 解析：

```text
targetDate
DateInterval
Transit scan range / anchors
```

---

# 8. 单人 Theme 的基础时间盘策略

单人类 Theme 主要复用：

```text
Natal
Transit
Tertiary Progression
Secondary Progression
Solar Arc
Lunar Return
Solar Return
```

推荐基础矩阵：

| Horizon | 基础盘 |
|---|---|
| Now | Natal + Transit + Tertiary；短周期敏感主题可再加 Lunar Return |
| 3 Months | Natal + Transit + Tertiary + Secondary |
| 6 Months | Natal + Transit + Secondary + Solar Arc |
| 1 Year | Natal + Transit + Secondary + Solar Arc + Solar Return |

是否在 `Now` 使用 Lunar Return，由 Theme 自己决定。

Relationship-specific 模式不使用这套个人 Timing 作为主线，而优先使用关系自身的 Composite Timing。

---

# 9. Love & Relationships

这是一个一级 Theme，但内部有两种分析模式。

## 9.1 Analysis Mode

```text
My Love Life
A Specific Relationship
```

### My Love Life

单人分析：

> 我的恋爱模式、情感需求、当前爱情阶段、未来一段时间爱情主题如何变化？

### A Specific Relationship

双人分析：

> 我和一个具体人的关系结构是什么？这段关系现在/未来处于什么阶段？

不要再把它们拆成两个一级 Theme。

---

## 9.2 输入

通用：

```text
Person
默认自己

Analysis Mode
- My Love Life
- A Specific Relationship

Time Period
Now / 3 Months / 6 Months / 1 Year

Current Location

Optional Context
```

### My Love Life 附加字段

```text
Relationship Status
- Single
- Dating
- In a relationship
- It's complicated
- Prefer not to say

Focus
- Overall
- Meeting someone
- Emotional patterns
- Attraction & connection
- Commitment
- Boundaries & reciprocity
```

### A Specific Relationship 附加字段

```text
Other Person
Saved People / New Person

Relationship Type
- Romantic
- Dating
- Friendship
- Ex-partner
- Other

Focus
- Overall
- Emotional connection
- Communication
- Attraction & intimacy
- Stability & tension
- Current phase
```

`Relationship Status / Relationship Type / Focus / Optional Context` 只影响报告语境，不改变 deterministic calculation。

---

# 10. Love & Relationships — My Love Life Chart Recipe

## Now

```text
Natal
Transit
Tertiary Progression
Lunar Return
```

## 3 Months

```text
Natal
Transit
Tertiary Progression
Secondary Progression
```

## 6 Months

```text
Natal
Transit
Secondary Progression
Solar Arc
```

## 1 Year

```text
Natal
Transit
Secondary Progression
Solar Arc
Solar Return
```

该模式不调用 02–17。

即使用户状态为 `In a relationship`，只要没有选择 `A Specific Relationship` + 第二个人，就不得自动进入合盘逻辑。

---

# 11. Love & Relationships — A Specific Relationship Chart Recipe

时间维度分析的是：

> **这段关系本身怎样发展。**

不以：

```text
A 的 Secondary
+
B 的 Secondary
```

作为主 Timing Evidence。

### Foundation：所有 Horizon 固定

```text
02 对比盘A
03 对比盘B
04 组合盘
```

在 Theme Facts 层：

```text
02 + 03
→ one merged Synastry Evidence Group

04
→ Composite Foundation
```

### Now

```text
02
03
04
05 组合行运
09 组合三限对比
```

### 3 Months

```text
02
03
04
05 组合行运
08 组合次限对比
09 组合三限对比
```

### 6 Months

```text
02
03
04
05 组合行运
08 组合次限对比
```

### 1 Year

```text
02
03
04
05 组合行运
08 组合次限对比
```

06/07 如果为 08/09 计算依赖，可内部生成并保存，但默认不作为独立 AI Evidence。

---

# 12. Specific Relationship 的时间范围处理

不能用“一张今天的组合行运盘”代表 3/6/12 个月。

`ThemeChartTask` 应支持：

```swift
struct ThemeChartTask {
    let chartKind: ChartKind
    let evidenceRole: ThemeEvidenceRole
    let participants: [PersonSnapshot]
    let targetDate: Date?
    let range: DateInterval?
    let includeInAIFacts: Bool
    let displayInResult: Bool
}
```

规则：

- `Now`：05 以 now 为 target；
- `3/6/12 Months`：08/09 以 Horizon 对应目标日/现有推进规则计算；
- 05 如果已有 range/event scanner，扫描整个 period 内主要 Composite activations；
- 如果当前只支持单点，Theme Planner 至少生成合理 anchors，不能静默拿 today 代替整个未来区间；
- 不在 Themes 中重新开发天文算法，复用现有 range/event 能力。

---

# 13. Specific Relationship 的高级合盘

以下盘现在都可以调用，但第一版默认关闭：

```text
10 时空盘
11 时空行运
12 时空次限
13 时空三限

14 马盘A
15 马盘B
16 马盘次限
17 马盘三限
```

`ThemePlanner` 可以预留：

```swift
case advancedRelationshipStructure
case subjectiveRelationshipExperience
```

第一版：

```text
UI 不显示
Planner 不自动触发
AI Prompt 不期待这些 Evidence
```

如果未来启用，必须作为明确的 Evidence Layer 加入，而不是无条件混入现有 Composite 体系。

---

# 14. Career & Purpose

## 输入

```text
Person

Current Stage
- Working
- Job searching
- Changing direction
- Studying
- Self-employed
- Other

Time Period

Current Location

Focus
- Overall
- Career direction
- Purpose & contribution
- Change
- Opportunity
- Leadership
- Work environment

Optional Context
```

## Chart Recipe

```text
Now
Natal + Transit + Tertiary

3 Months
Natal + Transit + Tertiary + Secondary

6 Months
Natal + Transit + Secondary + Solar Arc

1 Year
Natal + Transit + Secondary + Solar Arc + Solar Return
```

默认不调用 02–17。

---

# 15. Money & Growth

## 输入

```text
Person

Time Period

Current Location

Focus
- Overall
- Income & work
- Financial stability
- Spending & resources
- Growth & opportunity
- Long-term priorities

Optional Context
```

不要求填写真实：

```text
收入
资产
债务
投资金额
```

## Chart Recipe

```text
Now
Natal + Transit + Tertiary

3 Months
Natal + Transit + Tertiary + Secondary

6 Months
Natal + Transit + Secondary + Solar Arc

1 Year
Natal + Transit + Secondary + Solar Arc + Solar Return
```

Money & Growth 讨论：

```text
resources
security
earning / spending themes
growth
pressure
priorities
```

不得做：

```text
具体证券/基金/币种推荐
贷款决策
确定性财富预测
保证某一笔收益或损失
```

默认不调用 02–17。

---

# 16. Family & Home

`Family & Home` 不是只有“多人合盘”。

它必须允许：

```text
0 位 Family Member
→ 分析我自己的家庭/居所/根基阶段

1–3 位 Family Members
→ 在上述基础上，再分析我与这些成员的关系
```

## 输入

```text
Primary Person
默认自己

Family Members
0–3 人，可选

每位成员 Relationship Role
- Mother
- Father
- Parent
- Child
- Sibling
- Partner / Spouse
- Relative
- Other

Time Period

Current Location

Focus
- Overall
- Family relationships
- Home & roots
- Belonging
- Communication & boundaries
- Care & responsibility
- Changes at home

Optional Context
```

### Primary Chart Recipe

```text
Now
Natal + Transit + Tertiary + Lunar Return

3 Months
Natal + Transit + Tertiary + Secondary

6 Months
Natal + Transit + Secondary + Solar Arc

1 Year
Natal + Transit + Secondary + Solar Arc + Solar Return
```

### Family Member Relationship Recipe

每位成员默认：

```text
02 对比盘A
03 对比盘B
```

即：

```text
Primary ↔ Member
→ one merged Synastry Evidence Group
```

不计算成员彼此关系。

第一版不为每一位成员默认加入：

```text
04–17
```

避免 3 位成员迅速产生十几张关系盘。

---

# 17. Self & Wellbeing

## 输入

```text
Person

Time Period

Current Location

Focus
- Overall
- Emotional balance
- Energy & routines
- Self-confidence
- Stress & recovery
- Inner needs

Optional Context
```

## Chart Recipe

```text
Now
Natal + Transit + Tertiary + Lunar Return

3 Months
Natal + Transit + Tertiary + Secondary

6 Months
Natal + Transit + Secondary + Solar Arc

1 Year
Natal + Transit + Secondary + Solar Arc + Solar Return
```

默认不调用 02–17。

产品边界：

> `Wellbeing` 解释的是内在状态、情绪节奏、能量、压力、休息与自我照顾主题，不做医学诊断、疾病判断或治疗建议。

---

# 18. Creativity & Expression

## 输入

```text
Person

Time Period

Current Location

Focus
- Overall
- Creative work
- Self-expression
- Personal project
- Visibility
- Motivation & momentum

Optional Context
```

## Chart Recipe

```text
Now
Natal + Transit + Tertiary

3 Months
Natal + Transit + Tertiary + Secondary

6 Months
Natal + Transit + Secondary + Solar Arc

1 Year
Natal + Transit + Secondary + Solar Arc + Solar Return
```

默认不调用 02–17。

---

# 19. Learning & Exploration

## 输入

```text
Person

Time Period

Current Location

Focus
- Overall
- Learning
- Study
- New skills
- Travel & exploration
- New perspectives

Optional Context
```

## Chart Recipe

```text
Now
Natal + Transit + Tertiary

3 Months
Natal + Transit + Tertiary + Secondary

6 Months
Natal + Transit + Secondary + Solar Arc

1 Year
Natal + Transit + Secondary + Solar Arc + Solar Return
```

默认不调用 02–17。

---

# 20. Life Direction

## 输入

```text
Person

Time Period

Current Location

Focus
- Overall
- Identity
- Relationships
- Home & family
- Work & purpose
- Personal growth

Optional Context
```

## Chart Recipe

```text
Now
Natal + Transit + Tertiary

3 Months
Natal + Transit + Tertiary + Secondary

6 Months
Natal + Transit + Secondary + Solar Arc

1 Year
Natal + Transit + Secondary + Solar Arc + Solar Return
```

Life Direction 强调：

> 整个人生阶段的整合，而不是某一个单独领域。

默认不调用 02–17。

---

# 21. 8 个 Theme 的最终 Chart Recipe 矩阵

| Theme | Foundation | Timing / Development | 关系盘 02–17 |
|---|---|---|---|
| Love & Relationships — My Love Life | Natal | Transit / Tertiary / Secondary / Solar Arc / Lunar or Solar Return | 不调用 |
| Love & Relationships — Specific Relationship | 02+03 merged Synastry + 04 Composite | 05 + 08；Now/3M 条件加入 09 | **02/03/04/05/08；短期 09** |
| Career & Purpose | Natal | Transit / Tertiary / Secondary / Solar Arc / Solar Return | 不调用 |
| Money & Growth | Natal | Transit / Tertiary / Secondary / Solar Arc / Solar Return | 不调用 |
| Family & Home | Primary Natal；可选 member Synastry | Primary Timing | 每位成员只用 **02/03** |
| Self & Wellbeing | Natal | Transit / Tertiary / Secondary / Solar Arc / Lunar/Solar Return | 不调用 |
| Creativity & Expression | Natal | Transit / Tertiary / Secondary / Solar Arc / Solar Return | 不调用 |
| Learning & Exploration | Natal | Transit / Tertiary / Secondary / Solar Arc / Solar Return | 不调用 |
| Life Direction | Natal | Transit / Tertiary / Secondary / Solar Arc / Solar Return | 不调用 |

这是第一版 `ThemePlanner` 的权威矩阵。

---

# 22. 各 Theme 的 Evidence 角色

统一：

```text
foundation
timingExternal
timingInternal
shortTermDetail
memberRelationship
dependency
```

示例：

### Love & Relationships — Specific Relationship

```text
02/03
role = foundation

04
role = foundation

05
role = timingExternal

08
role = timingInternal

09
role = shortTermDetail

06/07
role = dependency
```

### Family & Home

```text
Primary Natal
role = foundation

Primary Transit / Progression / Solar Arc / Return
role = timing

Primary ↔ Member 02/03
role = memberRelationship
```

其他单人 Theme：

```text
Natal
role = foundation

Transit
role = timingExternal

Secondary / Tertiary / Solar Arc / Return
role = timingInternal / timingPeriod
```

---

# 23. Theme Inputs 与 Chart Recipe 的边界

以下字段可以决定：

```text
报告语境
ThemeEvidenceSelector 的筛选重点
是否启用 Specific Relationship
是否加入 Family Member Synastry
```

例如：

```text
analysisMode
focus
relationshipType
relationshipStatus
careerStage
familyRole
```

但自由文本 `Optional Context` 默认不能直接改变 Chart Recipe。

第一版不要实现：

> 用户在 note 里写“我想知道他怎么想”，于是自动启用 14–17 马盘。

如果未来需要按结构化 Focus 启用高级关系盘，再由 `ThemeDefinition + ThemePlanner` 明确设计。

---

# 24. 1 Year 不再需要独立 Year Ahead Theme

年度分析现在是 Horizon，而不是一级 Theme。

例如：

```text
Career & Purpose + 1 Year
→ Natal + Transit + Secondary + Solar Arc + Solar Return

Self & Wellbeing + 1 Year
→ Natal + Transit + Secondary + Solar Arc + Solar Return

Life Direction + 1 Year
→ Natal + Transit + Secondary + Solar Arc + Solar Return
```

区别来自：

```text
ThemeEvidenceSelector
+
Theme-specific Prompt
+
Report Sections
```

而不是创建一个额外的 `Year Ahead` 一级入口。

---

# 25. ThemeDefinition

将产品规则数据化。

概念结构：

```swift
struct ThemeDefinition {
    let kind: ThemeKind
    let title: String
    let subtitle: String
    let fields: [ThemeFieldDefinition]
    let reportSections: [ThemeReportSectionDefinition]
    let minPeople: Int
    let maxPeople: Int
}
```

示例：

```text
loveRelationships
    people = 1
    supportsSpecificRelationship = true
    specificRelationshipPeople = 2
    requiresHorizon = true

familyHome
    primary = 1
    familyMembers = 0...3
    requiresFamilyRoleWhenMemberExists = true
    requiresHorizon = true

careerPurpose
    people = 1
    requiresCareerStage = true

selfWellbeing / creativityExpression /
learningExploration / lifeDirection
    people = 1
    requiresHorizon = true
```

UI 读取定义，不在每个页面 hardcode 一套字段。

---

# 26. Theme Planner

独立组件：

```text
ThemePlanner
```

唯一核心职责：

```text
ThemeInput
    ↓
Theme Planner
    ↓
ThemeChartRecipe
```

它不负责：

```text
UI
Relay API
Credits 扣费
报告文案
历史存储
轮盘绘制
```

建议 Recipe 不只返回 `[ChartKind]`，还应包含用途：

```swift
struct ThemeChartTask {
    let id: UUID
    let chartKind: ChartKind
    let evidenceRole: ThemeEvidenceRole
    let participants: [PersonSnapshot]
    let targetDate: Date?
    let range: DateInterval?
    let includeInAIFacts: Bool
    let displayInResult: Bool
}
```

例如 Love & Relationships · Specific Relationship · 6 Months：

```text
02 Synastry A
role = foundation
AI = true
Display = true

03 Synastry B
role = foundation
AI = true
Display = true

04 Composite
role = foundation
AI = true
Display = true

05 Composite Transit
role = timingExternal
AI = true
Display = true

08 Composite Secondary Compare
role = timingInternal
AI = true
Display = true
```

如果 08 内部依赖 06：

```text
06 Composite Secondary
role = dependency
AI = false
Display = optional / false
```

---

# 27. 不重新实现 Astrology Calculation

Themes 是 **Orchestration Layer**。

必须复用现有：

```text
ChartKind / ChartType
Calculation Service
Facts
Chart Snapshot / Artifact
已开发的 Wheel Renderer
```

禁止在 Themes 里重新写：

```text
Composite 算法
Synastry 算法
Progression 算法
Transit 算法
时空/马盘算法
```

同一人物、时间、地点下：

> Charts 页面与 Themes 调用同一 ChartKind 得到的确定性结果必须一致。

---

# 28. 轮盘开发边界

**轮盘 Renderer 已另行开发，本规格不包含轮盘绘制实现。**

Themes 只需要完成：

```text
1. 保存 ThemeChartTask 对应的 Chart Artifact；
2. Result 页面提供 chart selector；
3. 将选中的 artifact 交给现有 Wheel Renderer；
4. 提供盘型标题、用途说明、View chart details 导航。
```

不要在 Themes 下重新做一个新的 astrology renderer。

仍然遵守：

> Theme Planner 明确请求并计算出来、且 `displayInResult = true` 的盘，都应该允许用户查看轮盘。

但内部依赖 artifact（例如仅为 08 服务的 06）不必因为内部计算过就强制成为顶层结果 Tab。

---

# 29. Theme AI 数据契约

这一节定义：

1. 计算完成以后，哪些数据可以进入 AI；
2. 每种盘应该向 AI 提供哪些确定性事实；
3. 哪些数据必须留在本地；
4. `ThemeFactsBuilder` 如何把多个 Chart Artifact 变成一个统一、可解释、可去重的 `ThemeAIPayload`。

核心原则：

> **App 负责计算“发生了什么”，AI 只负责解释“这些事实放在一起意味着什么”。**

AI 不接收需要它重新做天文/占星计算才能理解的原始数据。

禁止把以下责任交给 AI：

```text
根据经度重新判断星座
根据两颗星的度数自己算相位
根据宫头自己判断落宫
根据 29°xx' 自己判断即将换座
根据两个日期自己计算次限/三限
根据原始 Composite 与 Progressed Composite 自己重建对比关系
根据出生时间和经纬度重新算盘
```

这些都必须在本地 deterministic calculation / facts 层完成。

---

## 29.1 ThemeAIPayload 总体结构

建议所有 Theme 使用统一最外层 schema：

```json
{
  "schema_version": 1,
  "analysis": {},
  "people": [],
  "user_context": {},
  "evidence": {},
  "requested_output": {}
}
```

概念模型可抽象为：

```swift
struct ThemeAIPayload: Codable {
    let schemaVersion: Int
    let analysis: ThemeAIAnalysisContext
    let people: [ThemeAIPerson]
    let userContext: ThemeAIUserContext?
    let evidence: ThemeAIEvidence
    let requestedOutput: ThemeAIRequestedOutput
}
```

不要为 8 个 Theme 分别设计 7 套完全不同的 Relay 请求协议。

Theme 间不同的部分放在：

```text
analysis.theme
analysis.theme-specific metadata
evidence
requested_output.sections
```

---

## 29.2 analysis：这次分析的语境

`analysis` 只描述“这是什么分析”，不包含占星结论。

Love & Relationships · Specific Relationship 示例：

```json
{
  "analysis": {
    "theme": "love_relationships",
    "analysis_mode": "specific_relationship",
    "analysis_date": "2026-08-28",
    "period": {
      "label": "6_months",
      "start": "2026-08-28",
      "end": "2027-02-28"
    },
    "relationship_type": "romantic"
  }
}
```

Career & Purpose 示例：

```json
{
  "analysis": {
    "theme": "career_purpose",
    "analysis_date": "2026-08-28",
    "period": {
      "label": "6_months",
      "start": "2026-08-28",
      "end": "2027-02-28"
    },
    "career_stage": "working",
    "focus": "career_direction"
  }
}
```

必须区分：

```text
analysis_date
= 本次报告观察/生成基准日

period.start / period.end
= 用户选择的实际分析区间
```

不要只向 AI 传：

```text
"period": "6 months"
```

应同时传实际起止日期，避免模型自己猜时间范围。

---

## 29.3 people：只传报告需要的人物身份

AI 只需要知道报告中“谁是谁”。

Love & Relationships · Specific Relationship：

```json
{
  "people": [
    {
      "ref": "primary",
      "name": "Darryl",
      "role": "self"
    },
    {
      "ref": "person_b",
      "name": "Amy",
      "role": "partner"
    }
  ]
}
```

Family & Home：

```json
{
  "people": [
    {
      "ref": "primary",
      "name": "Darryl",
      "role": "self"
    },
    {
      "ref": "member_1",
      "name": "Linda",
      "role": "mother"
    },
    {
      "ref": "member_2",
      "name": "Michael",
      "role": "father"
    }
  ]
}
```

### 默认不发送 AI 的原始个人资料

本地已经完成计算后，以下内容默认不进入 Theme AI 请求：

```text
出生年月日
准确出生时间
出生地点
经纬度
timezone ID
原始 UserProfile
```

这些信息的作用是计算 Chart；AI 已经拿到计算后的事实，就不应再收到原始出生数据。

Location 处理规则：

- 计算必须继续使用本地所需地点；
- 默认不把经纬度、timezone 传给 AI；
- 如果某个 1 Year 分析或其他产品文案确实需要出现 “Tokyo” 这样的地点语境，可以只传用户可见的 `place_label`；
- 不因为报告生成而额外上传精确坐标。

---

## 29.4 user_context：用户输入必须与占星 Evidence 分离

统一结构：

```json
{
  "user_context": {
    "focus": "communication",
    "note": "We've felt more distant recently."
  }
}
```

还可以包含 Theme 本身允许的结构化输入，例如：

```text
analysis_mode
relationship_type
career_stage
relationship_status
family_role
focus
```

但必须明确：

> **`user_context` 是解释背景，不是 astrology evidence。**

用户说：

```text
"I think he doesn't love me anymore."
```

不能在报告里转写成：

```text
"The chart confirms he no longer loves you."
```

只有当已有 deterministic Evidence 支持某个“沟通压力、距离感、边界变化”等主题时，AI 才可以将用户背景与该 Evidence 联系起来。

---

## 29.5 evidence：统一 Evidence 分层

建议顶层统一为：

```text
evidence
├── foundation
├── timing
└── member_relationships?   // Family & Home only
```

其中：

### foundation

回答：

> 长期/基础结构是什么？

例如：

```text
Natal
Synastry
Composite
Solar Return（1 Year Horizon 中可作为年度/周期 framework）
```

### timing

回答：

> 在用户要求的时间范围里，什么正在被激活、推进或改变？

例如：

```text
Transit → Natal
Secondary → Natal
Tertiary → Natal
Solar Arc → Natal
Composite Transit
Composite Secondary Compare
Composite Tertiary Compare
```

### member_relationships

仅 Family 使用：

```text
Primary ↔ Mother
Primary ↔ Father
Primary ↔ Child
```

不能包含成员彼此关系。

---

## 29.6 通用 Evidence Record

不同盘最终应尽量归一成少数几种 Fact 类型。

推荐通用类型：

```text
placement
angle
house_emphasis
aspect
cross_aspect
house_overlay
activation
timing_event
derived_fact
```

每条 Evidence 至少保留来源：

```json
{
  "id": "e_032",
  "source_chart": "composite_transit",
  "evidence_role": "timing_external",
  "fact_type": "activation",
  "data": {}
}
```

如果现有 deterministic facts 层已经有：

```text
priority
strength
applying / separating
exact date
active window
tags
```

应直接透传。

不要由 Theme AI 自己重新生成这些属性。

---

## 29.7 单盘类：Natal / Composite / Solar Return / Lunar Return 应传什么

单盘结构型 Evidence 可以共用：

```json
{
  "placements": [
    {
      "body": "sun",
      "sign": "leo",
      "house": 7,
      "retrograde": false
    }
  ],
  "angles": {
    "ascendant": {
      "sign": "capricorn"
    },
    "midheaven": {
      "sign": "libra"
    }
  },
  "major_aspects": [
    {
      "body_a": "sun",
      "body_b": "saturn",
      "aspect": "square",
      "orb": 1.2
    }
  ],
  "house_emphasis": []
}
```

### 不需要默认把所有精确黄经传给 AI

例如：

```text
Sun = 18°24' Leo
Moon = 3°17' Scorpio
```

如果 AI 已经拿到：

```text
Sun in Leo
Sun in 7th
Sun square Saturn
orb 1.2°
```

就没有必要再给原始 longitude。

原因：

> 不给模型机会再做一次自己的相位/换座/宫位推导。

如果产品需要“即将换座”这种结论，应由本地生成：

```json
{
  "type": "sign_ingress",
  "body": "venus",
  "from": "leo",
  "to": "virgo",
  "date": "2026-10-14"
}
```

而不是让 AI 根据 29°xx' 自己推断。

---

## 29.8 Aspect / Activation 必须优先传 phase 与时间窗口

如果现有计算已经提供：

```text
applying
exact
separating
```

Timing Evidence 一定保留。

推荐：

```json
{
  "from": "transit_saturn",
  "to": "natal_midheaven",
  "aspect": "square",
  "orb": 0.84,
  "phase": "applying",
  "exact_at": "2026-11-03",
  "active_window": {
    "start": "2026-10-21",
    "end": "2026-11-17"
  }
}
```

对于 Theme 的时间分析：

```text
有没有相位
```

只是第一层信息；

```text
是否入相
何时精确
在哪个区间最活跃
```

通常比单纯相位名称更有价值。

AI 不得自己从日期或度数推算这些信息。

---

## 29.9 02/03 Synastry：必须合并为一个双向 Evidence Group

02 / 03 是同一段关系的两个方向，不应发送成两份完整重复报告素材。

推荐：

```json
{
  "synastry": {
    "cross_aspects": [
      {
        "person_a": "primary",
        "body_a": "venus",
        "person_b": "person_b",
        "body_b": "saturn",
        "aspect": "square",
        "orb": 0.9
      }
    ],
    "a_to_b": {
      "house_overlays": [
        {
          "body": "venus",
          "house": 7
        }
      ]
    },
    "b_to_a": {
      "house_overlays": [
        {
          "body": "sun",
          "house": 5
        }
      ]
    },
    "angle_contacts": []
  }
}
```

规则：

```text
shared cross_aspects
→ 只保留一次

A → B house overlays
→ 保留方向

B → A house overlays
→ 保留方向
```

不要：

```text
02 完整 Facts
+
03 完整 Facts
```

把同一跨盘相位重复两次。

Relationship 与 Family 都使用这一合并方式。

---

## 29.10 04 Composite：只承担 Relationship Foundation

Composite Evidence 建议包含：

```text
核心 placements
ASC / MC
重要内部 aspects
关系重点 houses / house emphasis
已有 deterministic derived facts
```

概念：

```json
{
  "composite": {
    "placements": [],
    "angles": {},
    "major_aspects": [],
    "house_emphasis": []
  }
}
```

04 的职责：

> 描述这段关系作为一个共同系统的基础结构。

不要把 Current / Timing 内容混进 Composite Foundation。

---

## 29.11 05 Composite Transit：重点传“行运对关系基盘的激活”

05 不需要把整张 sky chart 原封不动发给 AI。

优先发送：

```text
Transit planet
→ Composite body / angle
```

例如：

```json
{
  "composite_transit": {
    "events": [
      {
        "transiting_body": "saturn",
        "composite_body": "venus",
        "aspect": "square",
        "orb": 0.4,
        "phase": "applying",
        "exact_at": "2026-11-03"
      }
    ]
  }
}
```

默认不要把：

```text
Transit Jupiter ↔ Transit Saturn
```

这种纯天空内部相位作为 Relationship Evidence。

Relationship 关注的是：

> Sky → Relationship structure

不是：

> Sky → Sky。

---

## 29.12 08 Composite Secondary Compare：重点传“推进后的关系如何改变原始关系结构”

08 是 Relationship 中长期 Timing 核心。

推荐：

```json
{
  "composite_secondary_compare": {
    "target_date": "2027-02-28",
    "cross_aspects": [
      {
        "progressed_body": "moon",
        "base_body": "venus",
        "aspect": "conjunction",
        "orb": 0.6,
        "phase": "applying"
      }
    ],
    "key_progressed_facts": []
  }
}
```

如果 08 已经完整包含：

```text
Base Composite
vs
Progressed Composite
```

需要解释的对比事实，则：

```text
08 → AI Evidence
06 → dependency / artifact only
```

不要再把 06 的同一套推进 placements/aspects 完整重复发给 AI。

---

## 29.13 09 Composite Tertiary Compare：作为短周期细节

结构与 08 相同：

```json
{
  "composite_tertiary_compare": {
    "target_date": "2026-11-28",
    "cross_aspects": [],
    "key_progressed_facts": []
  }
}
```

Evidence 权重：

```text
Foundation
> Secondary relationship development
> Tertiary short-term detail
```

09 用于：

```text
Now
3 Months
```

默认不用于：

```text
6 Months
1 Year
```

且不能因为某一个三限信号很显眼，就覆盖长期 Foundation 或组合次限的主线。

---

## 29.14 单人 Theme 的 Timing：优先传“推运/行运对 Foundation 的激活”

例如 Career 6 Months 计算：

```text
Natal
Transit
Secondary
Solar Arc
```

不要只发四张彼此孤立的完整盘，让 AI 自己寻找关系。

优先组织成：

```text
foundation
└── natal

timing
├── transit_to_natal
├── secondary_to_natal
└── solar_arc_to_natal
```

例如：

```json
{
  "timing": {
    "transit_to_natal": [
      {
        "moving_body": "saturn",
        "base_point": "midheaven",
        "aspect": "square",
        "phase": "applying",
        "exact_at": "2026-11-03"
      }
    ],
    "secondary_to_natal": [],
    "solar_arc_to_natal": []
  }
}
```

原因：

```text
Transit Saturn in Pisces
```

本身只是背景；

```text
Transit Saturn square Natal MC
```

才是与 Career 直接相关的确定性激活 Evidence。

如果现有 Facts 层已经生成对应的 `transitAspects / progressedAspects / solarArc contacts`，直接复用，不在 Themes 重新计算。

---

## 29.15 ThemeEvidenceSelector：8 个 Theme 的 Evidence 筛选

Themes 不把完整 Chart Facts 无差别全部发给 AI。

统一：

```text
完整 deterministic Chart Facts
        ↓
ThemeEvidenceSelector
        ↓
与当前 Theme 相关的 Evidence
        ↓
ThemeAIPayload
```

Selector 只筛选已有事实，不补算。

### Love & Relationships — My Love Life

优先：

```text
Venus
Moon
Mars
Sun
ASC / DSC

5th house
7th house
8th house

已有 relationship / attraction / intimacy / reciprocity tags
与以上点形成的重要 aspects / activations
```

Timing 优先保留：

```text
Transit → Natal
Tertiary → Natal
Secondary → Natal
Solar Arc → Natal
Lunar/Solar Return 与 Natal 的已有 contacts
```

### Love & Relationships — Specific Relationship

不使用单人 Natal 事实替代关系 Evidence。

固定结构：

```text
foundation
├── merged Synastry 02/03
└── Composite 04

timing
├── Composite Transit 05
├── Composite Secondary Compare 08
└── Composite Tertiary Compare 09?  // Now / 3 Months
```

Synastry 中：

```text
shared cross aspects
A → B house overlays
B → A house overlays
angle contacts
```

必须合并去重。

### Career & Purpose

优先：

```text
MC
10th house
6th house
2nd house

Sun
Saturn
Jupiter
Mercury

已有 career / vocation / responsibility / contribution tags
与以上点形成的重要 aspects / activations
```

如果现有 Facts 已明确提供与 9th / 11th house 等相关的 purpose / contribution evidence，可以保留；Selector 不自己新增新规则。

### Money & Growth

优先：

```text
2nd house
8th house

Venus
Jupiter
Saturn

已有 resources / income / shared resources / security /
growth / pressure tags
相关 major aspects / activations
```

不要因为 Theme 名称含 `Growth` 就自动把所有 Jupiter 或 Pluto Facts 提升为主结论。

### Family & Home

Primary Foundation 优先：

```text
Moon
IC / 4th house
ASC
与 home / roots / belonging / family /
care / boundaries 相关的已有 deterministic tags
```

Primary Timing：

```text
Transit / Progression / Solar Arc / Return
→ 与上述 Foundation 相关的 activations
```

若选择 Family Members：

```text
每位 Primary ↔ Member
→ merged Synastry 02/03
```

Family member Evidence 优先保留：

```text
major cross aspects
directional house overlays
Moon / Mercury / Saturn / Venus 等涉及情绪、
沟通、责任、支持的已有关系事实
```

但不得从成员角色名称反推出不存在的 astrology facts。

### Self & Wellbeing

优先：

```text
Sun
Moon
ASC / 1st house
Mercury
6th / 12th house 仅在现有 Facts 可被解释为
routine / rest / pressure / recovery 时使用

已有 emotional / vitality / stress /
rest / self-relationship tags
```

禁止将任何 Evidence 解释为：

```text
医学诊断
疾病结论
精神疾病诊断
治疗建议
```

### Creativity & Expression

优先：

```text
5th house
Sun
Venus
Mercury
Neptune
Mars

已有 creativity / expression / visibility /
project / imagination / motivation tags
相关 major aspects / activations
```

必要时可保留 3rd / 11th house 的现有表达、传播、社群/受众类 Facts，但 Selector 不自行创造新占星规则。

### Learning & Exploration

优先：

```text
3rd house
9th house
Mercury
Jupiter
Uranus

已有 learning / study / travel /
exploration / worldview / skill tags
相关 major aspects / activations
```

Travel 只解释探索、移动、新环境和视野变化，不对具体旅行安全或现实结果作确定性保证。

### Life Direction

这是范围最宽的 Theme。

优先：

```text
Sun
Moon
ASC
MC

1 / 4 / 7 / 10 axis
核心 house emphasis
主要行星 aspects
已有 identity / direction / transition /
purpose / growth tags
主要 timing activations
```

如果 1 Year 中存在 Solar Return：

```text
Solar Return
→ 作为该年度在 Life Direction 中的重要 period framework
```

但不会因此恢复独立的 Year Ahead Theme。

## 29.16 ThemeEvidenceSelector 只“筛选已有事实”，不新造占星算法

`ThemeEvidenceSelector` 可以：

```text
按 Theme 过滤 body / house / tag
按现有 deterministic priority 排序
保留 major / active / exact signals
控制 payload 大小
```

但不允许：

```text
重新判断相位
重新计算宫主
重新计算强弱
重新生成新的 astrology score
因为 Theme 名称而创造不存在的占星规则
```

如果现有 Facts 层没有某项事实，ThemeEvidenceSelector 不能补算。

---

## 29.17 默认不要发送给 AI 的数据

除前面的人物原始出生数据外，还包括：

```text
完整 Wheel 图片
ChartRenderer 输出
SVG / Canvas path
所有行星的 raw longitude
所有宫头 raw degree
计算中间缓存
06/07 与 08/09 重复的 Evidence
display-only metadata
本地 UUID（除 Relay 幂等 ID 外）
Commerce / credits 数据
```

AI 只拿到：

> 为这次 Theme Report 真正需要的 deterministic evidence + 必要的报告上下文。

---

## 29.18 Love & Relationships · Specific Relationship 完整 Payload 示例

字段名可以根据现有 Codable 模型调整，但语义建议保持：

```json
{
  "schema_version": 1,

  "analysis": {
    "theme": "love_relationships",
    "analysis_mode": "specific_relationship",
    "analysis_date": "2026-08-28",
    "period": {
      "label": "6_months",
      "start": "2026-08-28",
      "end": "2027-02-28"
    },
    "relationship_type": "romantic"
  },

  "people": [
    {
      "ref": "primary",
      "name": "Darryl",
      "role": "self"
    },
    {
      "ref": "person_b",
      "name": "Amy",
      "role": "partner"
    }
  ],

  "user_context": {
    "focus": "overall",
    "note": "We've felt more distant recently."
  },

  "evidence": {
    "foundation": {
      "synastry": {
        "cross_aspects": [],
        "a_to_b_house_overlays": [],
        "b_to_a_house_overlays": [],
        "angle_contacts": []
      },

      "composite": {
        "placements": [],
        "angles": {},
        "major_aspects": [],
        "house_emphasis": []
      }
    },

    "timing": {
      "composite_transit": {
        "events": []
      },

      "composite_secondary_compare": {
        "target_date": "2027-02-28",
        "cross_aspects": [],
        "key_progressed_facts": []
      }
    }
  },

  "requested_output": {
    "language": "en",
    "sections": [
      "core_dynamic",
      "emotional_connection",
      "communication",
      "attraction_intimacy",
      "stability_tension",
      "current_phase",
      "what_is_changing",
      "period_ahead"
    ]
  }
}
```

---

## 29.19 Family & Home Payload 结构

Family & Home 不把 3 个人拼成一个大型 Synastry 网络。

推荐：

```json
{
  "analysis": {
    "theme": "family_home",
    "analysis_date": "2026-08-28",
    "period": {
      "label": "6_months",
      "start": "2026-08-28",
      "end": "2027-02-28"
    }
  },

  "people": [
    {
      "ref": "primary",
      "name": "Darryl",
      "role": "self"
    },
    {
      "ref": "member_1",
      "name": "Linda",
      "role": "mother"
    },
    {
      "ref": "member_2",
      "name": "Michael",
      "role": "father"
    }
  ],

  "user_context": {
    "focus": "overall",
    "note": "Things have felt tense at home recently."
  },

  "evidence": {
    "foundation": {
      "primary": {}
    },

    "timing": {
      "primary": {}
    },

    "member_relationships": [
      {
        "member_ref": "member_1",
        "synastry": {}
      },
      {
        "member_ref": "member_2",
        "synastry": {}
      }
    ]
  }
}
```

严格禁止出现：

```text
member_1 ↔ member_2
```

除非未来明确新增对应计算。

---

# 30. Facts 去重、归一与分组规则

`ThemeFactsBuilder` 不只是“把几个 JSON 拼起来”。

建议固定四步：

```text
Chart Artifacts
      ↓
1. Normalize
不同盘转成统一 Fact 类型
      ↓
2. Deduplicate
删除重复 Evidence
      ↓
3. Select
按 Theme 选择相关 Evidence
      ↓
4. Group
Foundation / Timing / Member-specific
      ↓
ThemeAIPayload
```

---

## 30.1 06 / 08 去重

如果 08 已完整表达：

```text
Base Composite
vs
Composite Secondary
```

则：

```text
08 → includeInAIFacts = true
06 → includeInAIFacts = false
```

06 仍可以：

```text
保存 artifact
作为 08 的 calculation dependency
必要时用于 UI / technical detail
```

但不重复进入 AI。

---

## 30.2 07 / 09 去重

同理：

```text
09 → AI
07 → dependency only
```

---

## 30.3 02 / 03 不能简单删除其中一个

因为方向性 house overlay 不同。

正确处理：

```text
02 + 03
      ↓
merged Synastry group
      ├── cross_aspects       // deduplicated
      ├── A → B overlays
      └── B → A overlays
```

AI 不应该看到：

```text
Synastry Report A
Synastry Report B
```

而是看到：

> 一段关系的双向 deterministic evidence。

---

## 30.4 同一个 Fact 多来源时

如果同一个事实因为内部数据结构在多个 artifact 中重复出现：

```text
同一 source/target
同一 aspect
同一 target date/window
```

应只保留一份。

如果两个不同 Technique 独立指向同一个现实主题，例如：

```text
Composite foundation 中有一组稳定/压力结构
+
Composite Secondary Timing 又激活同一组点
```

这不是重复数据，应保留为：

```text
Foundation Evidence
+
Timing Evidence
```

由 AI 用于“基础主题 + 当前激活”的综合判断。

---

# 31. Optional Context / 用户参数进入 AI 的规则

用户可以输入：

```text
We've been arguing lately.

I'm considering changing jobs.

I'm worried about money recently.
```

这些内容只允许：

```text
决定报告优先回答什么
帮助模型使用更自然的现实语言
在已有 Evidence 支持时连接用户背景
```

不得用于：

```text
改变天文计算
改变 Chart Recipe 的 deterministic 结果
改变相位/宫位/推运事实
替代缺失 Evidence
制造新 astrology facts
```

第一版除非 `ThemeDefinition` 明确配置，不根据自由文本自动启用 10–17 的高级合盘。

---

## 31.1 结构化参数与自由文本分开

例如 Relationship：

```json
{
  "relationship_type": "romantic",
  "focus": "communication",
  "note": "We've felt more distant recently."
}
```

其中：

```text
relationship_type / focus
= structured context

note
= free-form context
```

都不是 astrology evidence。

---

## 31.2 AI 可以怎样引用 user_context

允许：

```text
"You mentioned that communication has felt more distant recently.
The timing evidence also shows stronger pressure around communication..."
```

前提：

> 后半句必须确实有 supplied Evidence 支持。

不允许：

```text
"You said the relationship is failing, and the chart confirms it."
```

用户的判断不能被模型“洗成”占星事实。

---

# 32. Theme Report 结构

Theme Report 不按盘型逐章写。

禁止：

```text
Natal Analysis
Transit Analysis
Synastry Analysis
Composite Analysis
Progression Analysis
```

应该围绕现实主题综合多个 Evidence。

## Love & Relationships — My Love Life

```text
Your Relationship Pattern
Emotional Needs
Attraction & Connection
Communication & Reciprocity
Current Romantic Climate
What Is Changing
The Period Ahead
```

## Love & Relationships — Specific Relationship

```text
The Core Dynamic
Emotional Connection
Communication
Attraction & Intimacy
Stability & Tension
Current Phase
What Is Changing
The Period Ahead
```

## Career & Purpose

```text
Your Work & Purpose Pattern
Where You Are Now
Strengths & Contribution
Pressure & Friction
Direction & Opportunity
What Is Changing
The Period Ahead
Practical Focus
```

## Money & Growth

```text
Your Relationship With Resources
Current Resource Climate
Growth & Opportunity
Security & Pressure
Priorities & Trade-offs
What Is Changing
The Period Ahead
```

## Family & Home

```text
Your Family & Home Pattern
Belonging & Roots
Emotional Climate
Communication & Boundaries
Home & Stability
[Member sections when selected]
What Is Changing
The Period Ahead
```

成员章节只在用户选择成员时动态生成。

## Self & Wellbeing

```text
Your Inner Climate
Emotional Needs
Energy & Vitality
Stress & Recovery
Your Relationship With Yourself
What Is Changing
The Period Ahead
```

这里的 `Vitality / Wellbeing` 只能作一般性的占星解释，不能写成医学健康判断。

## Creativity & Expression

```text
Your Creative Signature
Voice & Expression
Current Spark
Projects & Momentum
Blocks & Pressure
What Is Changing
The Period Ahead
```

## Learning & Exploration

```text
How You Learn & Explore
Current Curiosity
Study & Skill Growth
Travel & New Perspectives
Momentum & Friction
What Is Changing
The Period Ahead
```

## Life Direction

```text
Your Current Chapter
Identity & Inner Direction
What Is Changing
Areas of Growth
Pressure & Transition
What Deserves Attention
The Period Ahead
```

---

# 33. AI 综合证据规则

所有 Theme 统一：

> 综合多个盘时，优先寻找重复、强化、互补或彼此冲突的 Evidence；不得因为一张盘中一个孤立信号，就直接提升成 Theme 的主要结论。

### 单人 Theme

推荐逻辑：

```text
Natal / Foundation
+
至少一个 Timing Technique 对同一主题形成激活
→ 可以提升为当前主要主题
```

如果：

```text
Natal 倾向明显
但当前 Timing 没有明显激活
```

应描述为：

> 长期倾向 / 背景主题

而不是：

> 现在一定正在发生。

### Love & Relationships — Specific Relationship

```text
Tier 1 Foundation
Synastry A/B
Composite

Tier 2 Timing
Composite Transit
Composite Secondary Compare

Tier 3 Short-term Detail
Composite Tertiary Compare
```

Foundation + Timing 同时支持同一主题时，才优先提升为关系当前主线。

09 的短周期信号不能轻易覆盖 04/08 的更稳定证据。

### Family & Home

Family-level conclusion 应来自：

1. Primary 自己的 Foundation/Timing；或
2. 多个 Primary ↔ Member Synastry 中重复出现的模式。

不能根据未计算的成员关系写：

```text
Mother ↔ Father
Father ↔ Child
```

---

# 34. 8 个 Theme 的特殊 Prompt 边界

### Love & Relationships

如果 `analysis_mode = my_love_life`：

```text
不能推断某个具体他人的想法、动机、行为
```

如果 `analysis_mode = specific_relationship`：

```text
只能解释 supplied Synastry / Composite / Timing Evidence
```

不得确定性预测：

```text
结婚
分手
复合
出轨
怀孕
某人一定会联系
```

### Career & Purpose

不得将盘面写成：

```text
一定升职
一定被裁
一定拿到 Offer
```

### Money & Growth

不得给具体投资、交易、贷款等金融决策。

### Family & Home

不得补算/推断成员彼此关系。

### Self & Wellbeing

不得提供医学诊断、疾病判断、治疗建议，也不得把占星语言伪装成临床心理诊断。

### Creativity & Expression

不得将“创造力阶段”写成保证商业成功、爆红或作品一定被认可。

### Learning & Exploration

不得保证录取、考试结果、签证、旅行安全或某一现实结果。

### Life Direction

不得把阶段性倾向写成唯一命运路线。

---

# 35. Themes 首页

```text
┌─────────────────────────────────────┐
│ Themes                              │
│ Explore what matters in your life  │
│                                     │
│ ┌──────────────┐ ┌──────────────┐  │
│ │ Love &       │ │ Career &     │  │
│ │ Relationships│ │ Purpose      │  │
│ └──────────────┘ └──────────────┘  │
│                                     │
│ ┌──────────────┐ ┌──────────────┐  │
│ │ Money &      │ │ Family &     │  │
│ │ Growth       │ │ Home         │  │
│ └──────────────┘ └──────────────┘  │
│                                     │
│ ┌──────────────┐ ┌──────────────┐  │
│ │ Self &       │ │ Creativity & │  │
│ │ Wellbeing    │ │ Expression   │  │
│ └──────────────┘ └──────────────┘  │
│                                     │
│ ┌──────────────┐ ┌──────────────┐  │
│ │ Learning &   │ │ Life         │  │
│ │ Exploration  │ │ Direction    │  │
│ └──────────────┘ └──────────────┘  │
│                                     │
│ Recent Analyses                     │
│ Love & Relationships · Amy      ›  │
│ Family & Home · 2 members       ›  │
│ Career & Purpose · 6 Months     ›  │
│                                     │
├─────────────────────────────────────┤
│ Today   Charts   Themes   Ask Profile│
└─────────────────────────────────────┘
```

Recent Analyses 必须保留。

---

# 36. Love & Relationships Setup 页面

统一一个 Theme 入口，先选择分析模式。

```text
┌─────────────────────────────────────┐
│ ‹ Themes                            │
│ Love & Relationships                │
│                                     │
│ ANALYSIS                            │
│ [ My Love Life ] [ Relationship ]  │
│                                     │
│ YOU                                 │
│ [ Darryl                         › ]│
│                                     │
│ // specific relationship 时显示    │
│ OTHER PERSON                        │
│ [ Amy                            › ]│
│                                     │
│ RELATIONSHIP TYPE                   │
│ [ Romantic                       › ]│
│                                     │
│ TIME PERIOD                         │
│ [Now] [3 mo.] [6 mo.] [1 yr]       │
│                                     │
│ CURRENT LOCATION                    │
│ [ Tokyo, Japan                   › ]│
│                                     │
│ FOCUS                               │
│ [ Overall                        › ]│
│                                     │
│ OPTIONAL                            │
│ [ We've felt more distant...      ]│
│                                     │
│ Your note guides the interpretation│
│ but does not change chart data.    │
│                                     │
│ [       Analyze · 2 Credits       ] │
└─────────────────────────────────────┘
```

如果 `My Love Life`：

```text
Other Person
Relationship Type
```

隐藏，改为显示 `Relationship Status`。

---

# 37. Family & Home Setup 页面

```text
┌─────────────────────────────────────┐
│ ‹ Themes                            │
│ Family & Home                       │
│                                     │
│ YOU                                 │
│ [ Darryl                         › ]│
│                                     │
│ FAMILY MEMBERS (OPTIONAL)           │
│ [ Linda · Mother                 › ]│
│ [ Michael · Father              › ]│
│ [ + Add family member             ]│
│ Up to 3 family members              │
│                                     │
│ TIME PERIOD                         │
│ [Now] [3 mo.] [6 mo.] [1 yr]       │
│                                     │
│ CURRENT LOCATION                    │
│ [ Tokyo, Japan                   › ]│
│                                     │
│ FOCUS                               │
│ [ Overall                        › ]│
│                                     │
│ OPTIONAL                            │
│ [ Things have felt tense...       ]│
│                                     │
│ [       Analyze · 2 Credits       ] │
└─────────────────────────────────────┘
```

Family Members 可以是 0。

0 人时：

> 仍然可以分析用户自己的家庭、居所、归属与根基阶段。

# 38. Analyze 行为

统一按钮：

```text
Analyze · 2 Credits
```

不要拆成：

```text
Calculate Charts
Generate Report
```

一次点击代表一次完整 Theme Analysis。

流程：

```text
Validate ThemeInput
        ↓
Create analysisID
        ↓
ThemePlanner.recipe(for: input)
        ↓
ThemeCalculationCoordinator
        ↓
Charts Ready
        ↓
进入 Result，可以查看轮盘
        ↓
ThemeFactsBuilder
        ↓
ThemeReportService → Relay
        ↓
completed
```

---

# 39. Credits 规则

固定：

```text
新 Theme Analysis                     2 Credits
打开历史 Analysis                     0
切换/查看已经生成的轮盘                0
View chart details                    0
退出后重新打开                         0
使用新 analysisID 重新生成完整分析      2 Credits
修改核心输入后重新 Analyze              2 Credits
```

Family 选 3 个成员仍是 2 Credits。

Love & Relationships 的 Specific Relationship 因 Horizon 调用了 5–6 个盘仍是 2 Credits。

不要按轮盘数量拆价。

---

# 40. Relay / 幂等性

服务端根据：

```text
reportType = theme
```

决定成本：

```text
theme = 2 credits
```

使用：

```text
analysisID / idempotencyKey
```

同一个 analysisID 的网络 Retry 不得重复扣费。

---

# 41. 失败语义

## Local Calculation Failure

```text
We couldn't calculate all required charts.
No credits were used.
```

不进入 AI 请求。

## AI / Relay Failure

已成功计算的盘仍保留。

```text
Your charts are ready,
but the written analysis could not be generated.
```

提供：

```text
Retry Analysis
```

Retry 复用原 analysisID，不能再次扣费。

用户最终没有拿到报告，不应最终损失 Credits。

---

# 42. Result 页面结构

统一：

```text
Header
↓
Summary
↓
Key Themes
↓
Charts
↓
Detailed Analysis
↓
Disclaimer
```

Love & Relationships · Specific Relationship 示例：

```text
┌─────────────────────────────────────┐
│ ‹ Themes                         •••│
│ Love & Relationships                │
│ Darryl & Amy                       │
│ Aug 28 — Feb 28                    │
│                                     │
│ YOUR RELATIONSHIP                   │
│ Summary...                          │
│                                     │
│ KEY THEMES                          │
│ • ...                               │
│ • ...                               │
│ • ...                               │
│                                     │
│ CHARTS                              │
│ FOUNDATION                          │
│ [Synastry] [Composite]             │
│              [ WHEEL ]              │
│                                     │
│ TIMING                              │
│ [Current Influence]                │
│ [Long-term Change]                  │
│ [Short-term Change]*                │
│              [ WHEEL ]              │
│                                     │
│ DETAILED ANALYSIS                   │
│ The Core Dynamic                ›   │
│ Emotional Connection           ›   │
│ Communication                  ›   │
│ Attraction & Intimacy          ›   │
│ Stability & Tension            ›   │
│ Current Phase                  ›   │
│ What Is Changing               ›   │
│ The Period Ahead               ›   │
└─────────────────────────────────────┘
```

底层：

```text
Synastry             → 02 / 03 merged
Composite            → 04
Current Influence    → 05
Long-term Change     → 08
Short-term Change    → 09
```

`Short-term Change` 只在 09 被 Recipe 选中时显示。

其他单人 Theme 使用同一 Result Shell，只替换：

```text
title
summary label
chart selectors
report sections
```

# 43. Family & Home Result 页面

```text
┌─────────────────────────────────────┐
│ Family & Home                       │
│ You + 3 family members              │
│                                     │
│ YOUR FAMILY & HOME                │
│ Overall summary...                  │
│                                     │
│ KEY THEMES                          │
│ • Emotional responsibility         │
│ • Communication differences        │
│ • Changing boundaries              │
│                                     │
│ FAMILY MEMBERS                      │
│                                     │
│ [ Mother ] [ Father ] [ Child ]    │
│                                     │
│ Mother                              │
│ Short member-specific summary      │
│                                     │
│ [ A → B ] [ B → A ]                │
│                                     │
│              [ WHEEL ]              │
│                                     │
│ YOUR CURRENT PHASE                  │
│                                     │
│ [Transit][Progression][Solar Arc]  │
│                                     │
│              [ WHEEL ]              │
│                                     │
│ DETAILED ANALYSIS                   │
│ Your Role in the Family         ›   │
│ Shared Family Patterns          ›   │
│ Communication & Boundaries      ›   │
│ Mother                          ›   │
│ Father                          ›   │
│ Child                           ›   │
│ What Is Changing               ›   │
│ The Period Ahead               ›   │
└─────────────────────────────────────┘
```

Family 第一层是整体家庭模式，第二层才是与每个成员分别的关系。

---

# 44. AI 生成中的 Result

不要用空白 Loading Screen。

只要 Theme 需要的本地盘已完成：

```text
✓ Charts calculated
```

立即进入 Result，让用户先看 Chart。

AI 区域显示：

```text
Preparing your analysis...

Combining your relationship and timing charts.
```

---

# 45. ThemeAnalysis 持久化

Theme Analysis 是 immutable artifact。

至少保存：

```text
analysisID
ThemeKind
themeMode / analysisMode（如适用）
createdAt
participants snapshot
ThemeInput snapshot
horizon
location snapshot
chartRecipe
chartArtifacts / stable references
summary
keyThemes
reportSections
status
generation metadata
```

用户以后修改 Saved Person 出生信息，历史 Theme Analysis 不应偷偷变化。

重新 Analyze 才生成新的 analysisID。

---

# 46. 不绑定 App 当前 Chart 状态

ThemeAnalysis 不得依赖：

```text
appModel.selectedChart
appModel.synastryPartnerID
```

历史 Theme 必须自包含。

Theme 内打开 Chart Detail 也不得改变 Charts 一级页面当前默认盘型。

---

# 47. Recent Analyses

Themes 首页展示：

```text
Love & Relationships
Darryl & Amy
Aug 28, 2026
                    >

Family & Home
You + 2 members
Aug 25, 2026
                    >

Career & Purpose
6 Months
Aug 20, 2026
                    >
```

点击直接恢复 Result。

不重新 AI，不重新扣费。

---

# 48. ThemeReportService / Relay AI Contract

`ThemeReportService` 的职责：

```text
ThemeAIPayload
      ↓
PromptBuilder
      ↓
Relay
      ↓
Structured Theme Report JSON
      ↓
Validate / Parse
      ↓
ThemeAnalysis
```

它不负责：

```text
重新计算 Chart
重新筛选原始天文数据
重新构建 Synastry / Composite
扣费规则本身
UI 排版
```

输入必须已经是 `ThemeFactsBuilder` 完成：

```text
Normalize
Deduplicate
Select
Group
```

之后的结果。

---

## 48.1 Prompt 由三层组合，不维护 8 份重复大 Prompt

统一：

```text
BASE SYSTEM / DEVELOPER PROMPT
        +
THEME MODULE
        +
OUTPUT CONTRACT
```

例如：

```text
Love & Relationships
= Base
+ Love & Relationships Module
+ Output Contract
```

```text
Career & Purpose
= Base
+ Career & Purpose Module
+ Output Contract
```

这样以后修改：

```text
不得重新计算
不得确定性预测
user_context 不是 Evidence
```

只改 Base，不需要同步维护 7 份重复 Prompt。

---

## 48.2 请求结构

Relay 接收：

```text
analysisID
reportType = theme
themeKind
ThemeAIPayload
language
```

其中 `analysisID` 同时用于：

```text
请求幂等
失败重试
Credits 防重复扣费
日志关联
```

不要把 Prompt 文本和 Chart 原始数据散落在多个请求中。

一次 Theme Report 应使用一个完整 payload。

---

## 48.3 AI 输出必须是结构化 JSON

不要让 AI 返回一整块 Markdown。

统一建议：

```json
{
  "summary": "string",
  "keyThemes": [
    {
      "title": "string",
      "summary": "string"
    }
  ],
  "sections": [
    {
      "id": "core_dynamic",
      "title": "The Core Dynamic",
      "body": "string"
    }
  ],
  "evidenceConfidence": "strong"
}
```

其中：

```text
evidenceConfidence
= strong | mixed | limited
```

含义：

```text
strong
多个相关 Evidence 相互强化

mixed
支持与压力/冲突同时明显

limited
与该 Theme 直接相关的 Evidence 较少
```

它不是：

```text
“占星预测准确率”
“事情发生概率”
```

第一版可以保存但不一定直接展示给用户。

---

## 48.4 Key Themes 数量

固定：

```text
3–5 条
```

Prompt 约束：

> 每个 Key Theme 原则上应由两个以上相关 Evidence 支持；除非 supplied facts 中存在明确标记为 dominant / high-priority 的 deterministic signal。

避免 AI 输出十几条零散主题。

---

## 48.5 Summary 与 Section 长度

建议英语基准：

```text
summary
80–140 words

每个 section
约 100–180 words
```

其他语言不按英文 word count 硬截，应由产品现有语言长度策略调整。

核心要求：

```text
先结论
后解释 Evidence
避免技术术语堆砌
不要重复同一事实
```

---

## 48.6 输出 section id 由客户端指定

AI 不自行发明 section ID。

`requested_output.sections` 决定允许返回的章节。

例如 Relationship：

```json
[
  "core_dynamic",
  "emotional_connection",
  "communication",
  "attraction_intimacy",
  "stability_tension",
  "current_phase",
  "what_is_changing",
  "period_ahead"
]
```

AI 返回：

```text
section.id
```

必须属于请求中的白名单。

标题可以根据 output language 本地化/由服务端固定，但不要让任意标题破坏 UI。

---

## 48.7 JSON 验证

客户端/Relay 至少验证：

```text
summary 非空
keyThemes = 3...5
sections 不缺 required id
section id 不重复
body 非空
evidenceConfidence 枚举合法
```

如果模型返回无效 JSON：

```text
优先服务端做一次 schema repair / constrained retry
```

不要：

```text
客户端直接把坏 JSON 当 Markdown 展示
```

仍使用同一 `analysisID`，不得因为 schema retry 重复扣 Credits。

---

# 49. Theme Prompt 完整设计

以下 Prompt 是第一版建议模板。

实现时可以存成：

```text
ThemePromptBuilder
├── basePrompt
├── relationshipModule
├── familyModule
├── loveDatingModule
├── careerModule
├── moneyModule
├── lifeDirectionModule
├── yearAheadModule
└── outputContract
```

可以根据现有 Relay prompt infrastructure 调整文件位置，但语义边界不要削弱。

---

## 49.1 Base Prompt

建议使用英文固定 Prompt，输出语言由 `requested_output.language` 控制。

```text
You are a careful, restrained and professional astrology interpreter for StelyraAgent.

You must interpret only the deterministic astrology facts explicitly provided in the request.

The supplied astrology facts are authoritative. Do not recalculate, infer, reconstruct or invent planetary positions, signs, houses, aspects, orbs, applying/separating states, chart rulers, progressions, returns, timing events, strengths, distributions, scores or any other astrology facts that are not explicitly provided.

Do not use raw dates, degrees, locations or birth data to perform your own astrology calculations.

Treat user_context only as contextual information about what the user wants to understand. It is not astrology evidence. Never convert a user's belief, fear, hope, assumption or description into a chart fact.

Distinguish structural evidence from timing evidence:
- foundation describes longer-term patterns or the underlying structure.
- timing describes what is currently activated, changing or emphasized during the requested period.

When synthesizing multiple charts, prioritize conclusions supported by multiple relevant facts. Repeated, reinforcing or complementary evidence may support a major theme. A single isolated fact should normally remain a secondary observation.

When evidence conflicts, preserve the tension. Do not force conflicting evidence into one confident conclusion.

Do not treat astrology as fate or certainty. Describe tendencies, needs, dynamics, pressures, opportunities and periods of emphasis. Do not claim that a specific major event will definitely happen.

Do not provide medical, legal or financial decisions. For money-related themes, discuss resource patterns, priorities, pressures and tendencies without recommending specific investments, trades, loans or financial actions.

Write for a general consumer with no astrology training. Lead with the conclusion, then explain the relevant supplied evidence in natural language. Avoid jargon when possible. When a technical term is useful, explain it briefly.

Do not write one mini-report for each chart. Integrate the supplied evidence around the user's selected life theme.

Do not mention astrology facts that were not supplied.

Use the requested output language.

Return only valid JSON matching the provided output schema.
```

---

## 49.2 Love & Relationships Module

```text
The selected theme is Love & Relationships.

Read analysis.analysis_mode first.

If analysis_mode = my_love_life:
- This is a single-person love-life analysis.
- Use Natal evidence for longer-term relationship needs and patterns.
- Use timing evidence for the current romantic climate and areas of changing emphasis.
- Do not infer the thoughts, feelings, intentions or future actions of any specific other person unless a second person's deterministic relationship evidence is explicitly supplied.
- Relationship status, focus and user notes are context only and are not astrology evidence.
- Do not predict that the user will definitely meet someone, reconcile, marry, separate or begin a relationship during the requested period.

Use the requested My Love Life sections:
1. Your Relationship Pattern
2. Emotional Needs
3. Attraction & Connection
4. Communication & Reciprocity
5. Current Romantic Climate
6. What Is Changing
7. The Period Ahead

If analysis_mode = specific_relationship:
- The analysis concerns the relationship between primary and person_b.
- Use Synastry and Composite evidence as the relationship foundation.
- Synastry A→B and B→A are two directional views of the same relationship, not two separate relationships.
- Do not repeat the same cross-aspect twice.
- Use directional house overlays only when explaining how one person activates a particular area of the other person's life.
- Use Composite evidence to describe the relationship as a shared system rather than the personality of either individual.
- Use Composite Transit evidence to describe external/current activation of the relationship.
- Use Composite Secondary Comparison evidence to describe medium-term internal development relative to the base Composite.
- Use Composite Tertiary Comparison, when present, only as shorter-term detail.
- Relationship type, focus and user notes may guide emphasis and wording, but they are not astrology evidence.
- Do not predict separation, marriage, infidelity, reconciliation, pregnancy or other major outcomes as certain facts.

Use the requested Specific Relationship sections:
1. The Core Dynamic
2. Emotional Connection
3. Communication
4. Attraction & Intimacy
5. Stability & Tension
6. Current Phase
7. What Is Changing
8. The Period Ahead
```

---

## 49.3 Career & Purpose Module

```text
Interpret the supplied evidence in relation to work, professional direction, contribution, responsibility, visibility, skills, opportunity, pressure and purpose.

Natal evidence describes longer-term work patterns and ways of contributing.

Timing evidence describes the current or upcoming phase during the requested period.

Career stage, focus and user notes are context only.

Do not claim that the chart proves the user will receive a job, promotion, resignation, dismissal or other specific outcome.

Do not force every purpose-related theme into a career event. Purpose can include contribution, direction, meaning and how the user wants to apply their abilities.

Organize the report around:
1. Your Work & Purpose Pattern
2. Where You Are Now
3. Strengths & Contribution
4. Pressure & Friction
5. Direction & Opportunity
6. What Is Changing
7. The Period Ahead
8. Practical Focus
```

---

## 49.4 Money & Growth Module

```text
Interpret the supplied facts in relation to resources, earning patterns, financial priorities, security, pressure, growth, opportunity and changing resource needs.

Do not predict exact financial gains or losses.

Do not recommend securities, investments, trades, loans or other financial products.

Do not treat astrology as sufficient evidence for a financial decision.

User-provided concerns about money are context only and must not be presented as chart-confirmed facts.

Growth does not automatically mean financial gain. It may describe expansion of capacity, opportunities, priorities or resource demands when supported by supplied evidence.

Organize the report around:
1. Your Relationship With Resources
2. Current Resource Climate
3. Growth & Opportunity
4. Security & Pressure
5. Priorities & Trade-offs
6. What Is Changing
7. The Period Ahead
```

---

## 49.5 Family & Home Module

```text
This theme concerns the primary person's family, home, roots, belonging and current domestic/family phase.

Use the primary person's foundation and timing evidence to describe the broader Family & Home context.

If member_relationships are supplied:
- Only analyze relationships for which explicit evidence is provided:
  primary ↔ member_1
  primary ↔ member_2
  primary ↔ member_3
- Never infer or describe relationships between family members when no direct evidence for that pair is supplied.
- Use each Synastry evidence group to describe the primary person's relationship with that specific family member.
- A family-level relationship theme should normally be supported by a pattern repeated across at least two primary-member relationships, or by the primary person's timing evidence that provides a common background affecting several relationships.
- Do not concatenate several independent Relationship reports.

If no family members are supplied:
- Do not invent family-member dynamics.
- Focus on the user's own home, roots, belonging, emotional base, boundaries and current family/home phase.

User notes and family roles are context only and are not astrology evidence.

Organize the report around:
1. Your Family & Home Pattern
2. Belonging & Roots
3. Emotional Climate
4. Communication & Boundaries
5. Home & Stability
6. One section for each selected family member, when present
7. What Is Changing
8. The Period Ahead
```

---

## 49.6 Self & Wellbeing Module

```text
Interpret the supplied evidence in relation to the user's inner climate, emotional needs, energy, routines, stress, rest, recovery and relationship with self.

This is not a medical or clinical assessment.

Do not diagnose any physical or mental health condition.

Do not suggest that an astrology placement or timing event proves illness, psychiatric disorder, trauma diagnosis or a need for a specific treatment.

When 6th-house, 12th-house or similar evidence is supplied, interpret it only within the non-clinical themes explicitly supported by the request, such as routines, rest, pressure, withdrawal, recovery or self-care.

User notes about how they feel are context, not chart-confirmed medical facts.

Organize the report around:
1. Your Inner Climate
2. Emotional Needs
3. Energy & Vitality
4. Stress & Recovery
5. Your Relationship With Yourself
6. What Is Changing
7. The Period Ahead
```

---

## 49.7 Creativity & Expression Module

```text
Interpret the supplied evidence in relation to creativity, imagination, self-expression, visibility, personal projects, motivation and the user's current ability to bring ideas into form.

Natal evidence describes longer-term creative and expressive patterns.

Timing evidence describes what is currently activated, blocked, accelerated or changing.

Do not claim that the chart guarantees commercial success, public recognition, fame or a specific project outcome.

User focus and notes are context only.

Organize the report around:
1. Your Creative Signature
2. Voice & Expression
3. Current Spark
4. Projects & Momentum
5. Blocks & Pressure
6. What Is Changing
7. The Period Ahead
```

---

## 49.8 Learning & Exploration Module

```text
Interpret the supplied evidence in relation to learning, study, skill development, curiosity, travel, exploration and changing perspectives.

Natal evidence describes longer-term learning and exploration patterns.

Timing evidence describes the current period of curiosity, movement, study, expansion or revision.

Do not guarantee admission, exam results, visas, travel safety or any other specific external outcome.

Do not invent a travel destination or date that is not supplied.

User focus and notes are context only.

Organize the report around:
1. How You Learn & Explore
2. Current Curiosity
3. Study & Skill Growth
4. Travel & New Perspectives
5. Momentum & Friction
6. What Is Changing
7. The Period Ahead
```

---

## 49.9 Life Direction Module

```text
Integrate the supplied foundation and timing evidence into a broad picture of the person's current life chapter.

Give greatest weight to themes that recur across multiple independent evidence sources.

Avoid turning every active aspect into a separate life event.

Life Direction can include identity, relationships, home, work, purpose and personal growth, but the report should synthesize them into a coherent chapter rather than reproduce several smaller Theme reports.

User focus and notes may guide emphasis but are not astrology evidence.

Do not present one possible direction as the user's only fate or inevitable path.

Organize the report around:
1. Your Current Chapter
2. Identity & Inner Direction
3. What Is Changing
4. Areas of Growth
5. Pressure & Transition
6. What Deserves Attention
7. The Period Ahead
```

---

## 49.10 Output Contract Prompt

在 Base + Theme Module 后追加：

```text
Return only one valid JSON object.

Required shape:

{
  "summary": "string",
  "keyThemes": [
    {
      "title": "string",
      "summary": "string"
    }
  ],
  "sections": [
    {
      "id": "one of the requested section ids",
      "title": "string",
      "body": "string"
    }
  ],
  "evidenceConfidence": "strong | mixed | limited"
}

Rules:
- Return 3 to 5 keyThemes.
- Do not invent section ids.
- Include every required requested section exactly once.
- Do not include markdown fences.
- Do not include commentary outside the JSON.
- Summary should lead with the overall conclusion rather than listing chart techniques.
- Section bodies should integrate evidence rather than describe charts one by one.
- Do not expose internal evidence IDs unless the product explicitly requests them.
```

---

## 49.11 AI 的职责边界总结

AI 允许：

```text
Interpret
Synthesize
Prioritize supplied evidence
Explain
Resolve report structure
Adapt wording to user context
```

AI 不允许：

```text
Calculate
Recalculate
Derive missing astrology facts
Infer missing cross relationships
Turn user statements into chart evidence
Invent timing windows
Invent exact dates
Make deterministic major-life predictions
```

因此完整链路必须保持：

```text
Calculation
      ↓
Facts
      ↓
Normalize
      ↓
Deduplicate
      ↓
Theme Select
      ↓
Group
      ↓
AI Interpret
```

而不是：

```text
Calculation raw data
      ↓
AI 自己算、自己选、自己解释
```

---

# 50. 本次开发不包含

明确排除：

```text
重新开发 Wheel Renderer
重新设计 Modern / Classic / Special 预设参数
Family > 3 members
Family 成员互相交叉计算
Specific Relationship 默认同时加入全部 02–17
1 Year 分析默认生成 12 张逐月 Lunar Return
用户手动选择 Theme Chart Recipe
按单张轮盘收费
Theme Web 分享
Theme 社交分享
Theme 对话追问
自由文本自动触发高级合盘
无限自由日期范围
```

---

# 51. 推荐代码层次

沿用现有 ChartType / Facts / Card 分离思路。

```text
Themes/
│
├── Model/
│   ├── ThemeKind.swift
│   ├── ThemeDefinition.swift
│   ├── ThemeInput.swift
│   ├── ThemeAnalysis.swift
│   ├── ThemeChartRecipe.swift
│   └── ThemeChartTask.swift
│
├── Planning/
│   └── ThemePlanner.swift
│
├── Calculation/
│   └── ThemeCalculationCoordinator.swift
│
├── Facts/
│   ├── ThemeFactsBuilder.swift
│   ├── ThemeEvidenceNormalizer.swift
│   ├── ThemeEvidenceSelector.swift
│   └── ThemeAIPayload.swift
│
├── Report/
│   ├── ThemePromptBuilder.swift
│   ├── ThemeReportService.swift
│   └── ThemeReportResponse.swift
│
├── Storage/
│   └── ThemeAnalysisStore.swift
│
└── UI/
    ├── ThemesView.swift
    ├── ThemeSetupView.swift
    ├── ThemeResultView.swift
    ├── ThemeChartSelector.swift
    ├── FamilyHomeResultSection.swift
    └── ThemeHistorySection.swift
```

文件名根据当前工程结构调整，不为符合本文而做无关重构。

---

# 52. 第一版验收标准

Coding Agent 完成后至少验证：

```text
1. Themes 成为一级入口。

2. Themes 首页只显示 8 个一级 Theme：
   Love & Relationships
   Career & Purpose
   Money & Growth
   Family & Home
   Self & Wellbeing
   Creativity & Expression
   Learning & Exploration
   Life Direction。

3. 不再显示旧的独立 Love & Dating / Relationship / Family /
   Career / Money / Year Ahead 一级 Theme。

4. Love & Relationships 支持 My Love Life 与
   A Specific Relationship 两种 Analysis Mode。

5. My Love Life 不选第二个人，不调用 02–17。

6. Specific Relationship 必须选择第二个人，并按 Horizon
   正确调用 02/03/04/05/08/09。

7. Specific Relationship 的 02/03 在 AI Payload 中合并为一个
   双向 Synastry Evidence Group，跨盘相位不重复。

8. 05 重点提供 Composite Transit → Composite 的激活事实。

9. 08 作为 Base Composite ↔ Composite Secondary 的主要中长期
   对比 Evidence；如已覆盖解释所需事实，06 不重复上传。

10. 09 / 07 使用相同去重原则。

11. 10–17 当前仍可由底层调用，但第一版默认 Theme Recipe 不自动选。

12. Family & Home 允许 0–3 位 Family Members。

13. 0 位成员时 Family & Home 仍可完成 Primary 自己的 Home /
    Roots / Family Phase 分析。

14. 选择成员时只计算 Primary ↔ Member，不计算成员彼此关系。

15. 每位 Family Member 默认只调用 02/03，不自动堆 04–17。

16. Career & Purpose / Money & Growth / Self & Wellbeing /
    Creativity & Expression / Learning & Exploration /
    Life Direction 都按文档规定的单人 Chart Recipe 调度。

17. 1 Year 是 Horizon，不再依赖独立 Year Ahead Theme。

18. ThemePlanner 返回 ThemeChartRecipe，并正确设置 evidenceRole /
    targetDate / range / includeInAIFacts / displayInResult。

19. 所有 Chart 复用现有 Calculation Service，不在 Themes 重新实现。

20. Theme 中同 ChartKind 与 Charts 中相同输入的 deterministic
    结果一致。

21. ThemeEvidenceBuilder 完成 Normalize → Deduplicate →
    Select → Group。

22. 单人 Theme 的 Transit / Secondary / Tertiary / Solar Arc /
    Return 优先提供相对于 Foundation 的已有 activations，
    而不是让 AI 从 raw degree 自己计算。

23. ThemeEvidenceSelector 只筛选已有 deterministic facts，
    不新增相位、宫位、宫主、强弱或评分算法。

24. AI Payload 明确拆分 analysis / people / user_context /
    evidence / requested_output。

25. 原始出生日期、出生时间、精确经纬度、timezone 默认不进入
    AI Payload。

26. user_context 与 astrology evidence 在 JSON 中物理分离。

27. Love & Relationships Prompt 根据 analysis_mode 正确分支。

28. Family & Home Prompt 不允许推导未计算的成员彼此关系。

29. Self & Wellbeing Prompt 不输出医学/精神疾病诊断或治疗建议。

30. Money & Growth Prompt 不输出具体投资、交易、贷款决策。

31. Learning & Exploration Prompt 不保证录取、考试、签证、
    旅行安全等现实结果。

32. Creativity & Expression Prompt 不保证爆红、商业成功或作品认可。

33. Life Direction Prompt 不把某一个方向写成唯一命运。

34. Theme Report 按现实主题组织，而不是按盘型组织。

35. AI 返回结构化 JSON，keyThemes = 3...5，
    section id 必须来自 requested_output 白名单。

36. 无效 JSON repair/retry 使用同一 analysisID，不重复扣 Credits。

37. Analyze 统一显示 2 Credits。

38. 一次点击同时进入“计算 Charts + 生成综合报告”。

39. Charts Ready 后立即可进入 Result，并在 AI 生成期间查看轮盘。

40. 一个区域只显示一个主 Wheel，通过 selector 切换。

41. 历史 Analysis 再次打开不收费、不重新请求 AI。

42. 历史 Analysis 保存 ThemeKind + themeMode + participant/input/
    chart/evidence/report 快照，不受后续 Profile 修改影响。

43. Relay Retry 不能重复扣 Credits。

44. Local Calculation Failure 不扣 Credits。

45. AI Failure 不造成用户最终 Credits 损失。

46. Optional Context 不改变 deterministic chart facts。

47. 现有 Charts / Ask / Reports 不发生回归。
```

---

# 53. 最终产品逻辑

最终可以压缩为：

```text
Themes
= 8 个现实生活主题入口
+ 自动 Chart Recipe
+ Deterministic Multi-chart Calculation
+ Theme-specific Evidence Selection
+ Visible Wheels
+ Unified AI Interpretation
= 2 Credits
```

8 个入口固定为：

```text
Love & Relationships
Career & Purpose
Money & Growth
Family & Home
Self & Wellbeing
Creativity & Expression
Learning & Exploration
Life Direction
```

其中：

```text
Love & Relationships
→ 单人爱情 / 具体双人关系两种模式

Family & Home
→ Primary 自身家庭/居所阶段
  + 可选 0–3 位家庭成员 Synastry
```

开发顺序建议：

```text
1. ThemeKind / ThemeDefinition / ThemeInput
2. ThemePlanner / ThemeChartRecipe
3. ThemeCalculationCoordinator
4. ThemeFactsBuilder / Evidence Selector
5. ThemeAIPayload / PromptBuilder
6. ThemeReportService / Relay / Credits
7. ThemeAnalysisStore / Recent Analyses
8. 8 个 Theme 的 Setup / Result UI
9. 回归测试
```

本次真正需要新开发的核心不是新的 Astrology 算法，而是：

> **把已经存在的盘型能力，按 8 个现实主题进行正确调度、筛选、去重、组织和解释。**

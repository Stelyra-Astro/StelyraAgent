# StelyraAgent v1 开发规格

> 状态：可进入开发  
> 文档类型：产品 + iOS + Agent Runtime + Account/IAP + Admin 一体化开发规格  
> 目标读者：Coding Agent / iOS 开发 / Runtime 开发 / 后台管理开发  
> 原则：本项目为 **StelyraAgent 独立项目**，不与现有 Interstellar Relay 共仓、共服务、共数据库或共账户体系。

---

# 0. 文档权威级别与实现原则

本文件是 StelyraAgent v1 的主开发规格。

若当前代码、旧 Interstellar 逻辑、旧 Themes 文档、原型或历史实现与本文件冲突：

1. 本文件中的“冻结规则”优先；
2. 现有 AstroCore / Swiss Ephemeris 的确定性计算结果优先，不重新实现同一套算法；
3. 新 Runtime 只负责编排、对话、模型调用、Credits、账户和临时 Run；
4. iOS 负责本地 Profile、Conversation、Chart 计算、Chart Assets 和长期历史；
5. 不为了兼容旧 Relay 而污染 StelyraAgent 新架构。

---

# 1. 产品定位

StelyraAgent 不是“给星盘加一个聊天框”，而是：

> **一个能理解用户现实问题、主动决定需要哪些占星计算、通过 iPhone 本地 AstroCore 获取确定性证据，再基于这些证据进行多轮分析的占星 Agent。**

产品核心由四部分组成：

```text
Chat / Themes / Charts / Profiles
            ↓
    Astrology Agent Runtime
            ↓
     Analysis Plan
            ↓
iOS Local Astrology Tool Execution
            ↓
       Chart Assets
            ↓
      Evidence Bundle
            ↓
        AI Analysis
```

核心差异化：

- 占星计算继续在 iPhone 本地完成；
- AI 不重新计算行星位置、宫位、相位；
- Agent 可以自主决定“需要什么证据”；
- 用户可以查看 Agent 实际计算过的每一张 Chart；
- AI 结论可追溯到 Chart / Aspects / Positions / Timing；
- 长期聊天和资产默认存在本地，不把服务器变成聊天数据库。

---

# 2. 独立项目与 NAS 部署架构

## 2.1 与 Interstellar 完全隔离

StelyraAgent 是新项目。

禁止：

```text
StelyraAgent Runtime
→ 直接塞进现有 Interstellar Go Relay
```

禁止共享：

- 源码仓库
- 数据库
- Credits ledger
- 用户账户
- 配置文件
- Session token
- Provider key
- Runtime state
- Admin 后台数据模型

可以共享的仅是 NAS 基础设施，例如：

- Docker Host
- 反向代理
- TLS
- 日志基础设施（若是通用宿主级日志）
- 备份系统

---

## 2.2 NAS 第一版运行两个应用容器

```text
NAS
│
├── stelyraagent-runtime
│   ├── Hono
│   ├── TypeScript
│   ├── Node.js 22
│   ├── Vercel AI SDK
│   ├── DeepSeek Provider
│   ├── Agent Runtime
│   ├── Auth
│   ├── Credits / IAP
│   ├── Run State
│   └── SQLite volume
│
└── stelyraagent-admin
    ├── React + Vite
    ├── static build
    └── 仅通过 Runtime Admin API 访问数据
```

第一版不启动 PostgreSQL 第三个容器。

使用：

```text
SQLite + persistent Docker volume
```

未来规模上升后可以迁移 PostgreSQL，但业务代码必须通过 Repository 层访问数据库，禁止在业务逻辑里散落 SQLite-specific SQL。

---

# 3. 后端技术选型

## 3.1 Runtime

冻结：

```text
Language      TypeScript
Runtime       Node.js 22
HTTP          Hono
Agent SDK     Vercel AI SDK
Phase 1 LLM   DeepSeek direct provider
Phase 2 LLM   OpenRouter
Validation    Zod
Database      SQLite
Container     Docker
```

原因：

- Agent Runtime 的复杂度主要在 tool loop、structured output、model usage、provider abstraction，而不是 HTTP；
- Vercel AI SDK 原生 TypeScript，避免用 Go 自己重新实现 Agent loop；
- Hono 足够轻，适合 NAS；
- DeepSeek 第一版直接接；
- Provider 必须经过自定义抽象，未来可切 OpenRouter，而不是业务代码到处直接调用某个 provider。

---

## 3.2 Provider 抽象

业务代码禁止：

```ts
deepseek(...)
```

散落各处。

统一：

```text
ModelProvider
├── createModel(modelPolicy)
├── stream(...)
├── generate(...)
├── getUsage(...)
└── normalizeError(...)
```

Phase 1：

```text
DeepSeekProvider
```

Phase 2：

```text
OpenRouterProvider
```

Agent Runtime、Credits、Capability、Evidence 不应知道当前供应商。

---

# 4. iOS / Server 职责边界

## 4.1 iOS 长期持有

```text
Profiles
Birth data
Saved people
Current / saved locations

Conversations
Messages
Conversation titles
Conversation summaries

Chart calculation
AstroCore / Swiss Ephemeris

Chart Assets
Wheel data
Aspects
Positions
Houses
Timing data

Chart files / fingerprints
Analysis asset references

Long-term local memory
```

现有代码已经具备本地 Profile / Saved People / ChartContext / location override / semantic fingerprint / GeneratedChartArtifact 等基础，应尽量迁移和复用，不重新写第二套近似逻辑。

---

## 4.2 Runtime 持有

长期持久化：

```text
Apple identity
Astro server account
Credits wallet
Credit ledger
IAP transaction ledger
Subscription state
Provider/model configuration
Run metadata
Usage / token / cost metrics
Admin audit logs
```

短期持有：

```text
active Agent Run
temporary messages required by this Run
temporary tool results
temporary Evidence
temporary Interaction state
temporary Analysis Plan
```

最终结果送达 iOS 并收到 ACK 后：

```text
删除 Run payload
删除 Evidence payload
删除临时对话上下文
```

只保留不含详细私密内容的运行元数据与用量统计。

---

# 5. 主界面信息架构

UI 参考：

```text
interstellar_stelyraagent_prototype_v3.html
```

但以本文件规则为准。

---

# 6. Chat 初始状态

尚未开始任何 Conversation 时：

顶部：

```text
StelyraAgent
```

首页包含：

```text
Themes
Charts
Try asking
```

## 6.1 Themes 快捷入口

显示部分高频 Theme，支持 See All。

v1 Catalog 统一保留 8 个 Theme：

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

首页无需全部铺开。

---

## 6.2 Charts 快捷入口

显示高频：

```text
Natal
Transit
Secondary
Synastry
```

支持 See All。

点击 Theme / Chart：

**不得立即向 AI 发送。**

而是添加到输入框上方的 Draft Context Chip：

```text
Theme · Career
Chart · Transit
```

用户还可以编辑输入框中的自然语言问题，最后统一发送。

---

## 6.3 Try asking 动态推荐

快捷问题不是静态写死。

由本地 Profiles 状态决定。

### 没有主 Profile 完整出生资料

仍可以给：

```text
What should I focus on in the next three months?
When might be a better time for a career change?
What patterns keep showing up in my relationships?
```

用户点击后：

```text
只写入输入框
不自动发送
```

用户编辑后发送。

Agent 后续若需要出生资料：

```text
requires_action → required_input
```

通过原生 UI 补齐资料。

### 主 Profile 完整

可以推荐更具体的个人问题。

### 已保存其他 Profiles

可以额外推荐：

```text
What should I understand about my relationship with Bill?
```

推荐内容仅来自本地 Profile 状态。

---

# 7. 输入框 + 菜单

输入框左侧固定：

```text
+
```

点开只有 4 个：

```text
Charts
Themes
Assets
Profiles
```

不单独设置：

```text
Analyze a person
```

人物分析入口统一归入 Profiles。

---

## 7.1 Profiles

Profiles 包含：

```text
You
Saved Person A
Saved Person B
...
```

选择某个人：

```text
Person · Bill
```

作为 Draft Context 加入输入框上方。

**选择人物本身不能触发发送。**

用户必须继续输入：

```text
What should I understand about our relationship lately?
```

然后一起发送。

---

# 8. Conversation 命名

第一条消息发送前：

```text
StelyraAgent
```

第一轮完成后 Runtime 可生成一个短标题：

```text
Career Move Timing
Relationship With Bill
Moving to New York
```

标题保存在 iOS Conversation Store。

Runtime 不作为长期标题数据库。

若标题生成失败：

```text
使用本地 fallback
```

例如取首条用户消息摘要。

---

# 9. 三种 Agent 入口

统一使用同一个：

```text
AstrologyAgentRuntime
```

但自治程度不同。

---

## 9.1 Chart Mode

用户明确选择某张盘：

```text
selectedChart
```

Agent 必须分析这张盘。

不得静默替换成别的盘。

如果额外盘明显有价值：

```text
作为进一步分析建议
```

或在规则允许的轻量 drill-down 中追加，但不能改变用户明确选择的主盘。

---

## 9.2 Themes Mode

用户选择现实主题。

Agent 在 Theme Policy 约束内可自动选择 Chart capabilities。

用户无需懂：

```text
Secondary
Solar Arc
Composite Tertiary
...
```

---

## 9.3 Chat Mode

用户自由提问。

Agent自主判断：

```text
是否需要占星证据
需要哪些人物
需要哪些 Chart capabilities
时间范围
地点
是否需要 Interaction
```

---

# 10. Agent Runtime 核心状态机

不要保持一个长 HTTP 请求等待 iPhone 算盘。

统一采用可暂停 Run：

```text
create_run
    ↓
reasoning
    ↓
requires_action
    ├── tool_call
    └── user_interaction
    ↓
paused
    ↓
iOS 执行
    ↓
submit_action_result
    ↓
resume
    ↓
可能再次 requires_action
    ↓
finalizing
    ↓
completed
    ↓
client ACK
    ↓
temporary payload deleted
```

建议 Run 状态：

```text
created
reasoning
requires_action
waiting_for_client
resuming
finalizing
completed
failed
cancelled
expired
acknowledged
```

---

# 11. Agent Tool Contract

第一版尽量只有一个核心占星工具：

```text
request_astrology_evidence
```

而不是为 20 多张盘注册 20 多个 tools。

示例：

```json
{
  "requests": [
    {
      "capability": "you.transit",
      "subjects": ["primary"],
      "time_scope": {
        "start": "2035-01-01",
        "end": "2035-12-31",
        "resolution": "two_weeks"
      },
      "locations": ["new_york"]
    }
  ],
  "reason": "Find likely career change windows."
}
```

`reason`：

- 仅用于日志、调试、可观测性；
- 不参与确定性计算；
- iOS 不得因为 reason 改变 AstroCore 算法。

---

# 12. Capability Manifest

iOS 每个 Session / Run 报告：

```text
capabilityManifestVersion
supportedCapabilities
clientVersion
calculationSchemaVersion
```

Runtime 只允许：

```text
Server Catalog
∩
Client Manifest
```

的能力进入 Analysis Plan。

---

# 13. Capability Catalog v1

## 13.1 You

默认 Agent 能力：

```text
you.natal
you.transit
you.secondary
you.tertiary
you.solar_arc
you.solar_return
you.lunar_return
```

条件调用：

```text
you.current_sky
you.relocation
```

高级、默认不自治：

```text
you.harmonic_12
you.harmonic_13
```

用户若明确选择高级盘：

```text
允许分析
```

---

## 13.2 Bonds

Foundation：

```text
relationship.synastry
relationship.composite
```

Timing：

```text
relationship.composite_transit
relationship.composite_secondary_compare
relationship.composite_tertiary_compare
```

Advanced：

```text
relationship.davison
relationship.davison_transit
relationship.davison_secondary
relationship.davison_tertiary

relationship.marks
relationship.marks_secondary
relationship.marks_tertiary
```

Advanced：

```text
user_selectable = true
agent_autonomy = advanced_only
default_theme_recipe = false
```

---

## 13.3 Synastry 映射

Agent 看到：

```text
relationship.synastry
```

底层可计算：

```text
Synastry A
Synastry B
```

然后本地 EvidenceBuilder 合并成一组双向关系证据。

Agent 不需要知道底层 A/B 两个内部计算枚举。

---

## 13.4 Compare 依赖

例如：

```text
relationship.composite_secondary_compare
```

底层允许先计算 dependency：

```text
Composite Secondary
```

但 Agent-facing Evidence 主要给 compare 结果。

避免依赖盘和 compare 盘重复占 Evidence budget。

---

# 14. Analysis Plan

冻结：

> **Analysis Plan = AI Proposal + Deterministic Plan Compiler**

AI 提议：

```text
intent
goal
candidate capabilities
why
subjects
time intent
location intent
```

Deterministic Compiler 决定：

```text
allowed capabilities
available subjects
missing required data
resolution options
location rules
computation estimate
credit requirement
model budget
interaction requirements
```

结构：

```text
AnalysisPlan
├── intent
├── subjects
├── time
├── locations
├── capabilities
├── interactions
├── computation
└── modelBudget
```

---

# 15. Interaction Policy v1

硬规则：

1. 默认不问；只有信息会实质改变分析方案时才问。
2. Intent 聚焦最多 2 轮，通常 0–1 轮。
3. 结构化计算参数通过 iOS 原生 UI 获取，不靠 Agent 逐条聊天询问。
4. 同一次 Interaction 最多聚合 3 个强相关决策维度。
5. 当前范围/当前 Credit 内的小幅 drill-down 可自动执行；扩大人物、地点、时间、费用、极高计算量或 advanced capability 必须确认。
6. 用户拒绝 Interaction 后，优先尝试降级分析，不直接失败。

Interaction 类型：

```text
clarify_intent
required_input
analysis_choice
plan_review
```

---

# 16. Interaction 的首要目标

Interaction 主要用于：

> **把用户问题聚焦、具体化。**

而不是每次 Agent 想算盘都问：

```text
Do you approve Transit?
Do you approve Secondary?
```

例如：

```text
我明年怎么样？
```

可以问：

```text
Overall
Career
Relationships
Money
Home & Family
Personal Growth
```

用户选 Overall 后应直接继续，不无限下钻。

---

# 17. Analysis Plan Review

以下情况通常不显示：

```text
用户明确选择单 Chart
只有一个明显 capability
普通不算盘的聊天
Theme 已经明确输入
```

以下情况应显示：

```text
Agent 自主选择 ≥2 capabilities
增加新的 Person
多个地点
High / Extreme computation
需要消费 Credit
明显扩大原始分析范围
```

示例：

```text
Analysis

Future career · 1 year

✓ Transits
✓ Secondary Progressions
✓ Solar Arc

Timeline
Every 2 weeks

1 Credit

[ Analyze ]
```

用户可以：

```text
取消推荐盘
Add chart
Continue
```

但默认不要把全部高级盘摊成 20 个 checkbox。

---

# 18. 时间 Resolution Policy

Resolution 指：

> **用户希望得到的结果时间精度。**

不是要求所有技术按机械时间步长生成一张张盘。

---

## 18.1 固定档

| 查询跨度 | Overview | Balanced 默认 | Detailed |
|---|---|---|---|
| ≤ 1周 | 每日 | 12小时 | 6小时 |
| >1周–1月 | 每周 | 3天 | 每日 |
| >1–6月 | 每月 | 双周 | 每周 |
| >6月–2年 | 每月 | 双周 | 每周 |
| >2–10年 | 每年 | 半年 | 每季度 |
| >10–30年 | 每5年 | 每年 | 每半年 |
| >30–100年 | 每10年 | 每5年 | 每年 |

额外：

```text
Major Windows Only
```

用于长周期事件扫描。

---

## 18.2 什么时候显示 Resolution

### Hidden

趋势问题：

```text
今年事业整体怎么样？
未来一年感情如何？
```

自动 Balanced。

### Required

明确 timing search：

```text
什么时候
哪一天
哪一周
哪个月份
最佳时间
最适合
关键窗口
```

### Optional

用户说：

```text
详细看看
具体一点
```

但不明确要求时间搜索。

---

# 19. Technique-specific Evidence Planner

禁止：

```text
1 年 weekly
=
52 张 Transit × 所有技术
```

每个 capability 有自己的 planner。

例如：

```text
Transit Planner
Secondary Planner
SolarArc Planner
CompositeTiming Planner
```

Planner 根据：

```text
time span
output resolution
astrological technique
local compute cost
```

寻找事件、exact window、active window。

最终按用户 Resolution 分组输出。

---

# 20. Computation Budget

分开：

```text
LocalComputationBudget
ModelEvidenceBudget
```

不能混成一个复杂度。

---

## 20.1 LocalComputationBudget

估算：

```text
technique complexity
× subjects
× locations
× effective temporal work
```

等级：

```text
LOW
NORMAL
HIGH
EXTREME
```

LOW/NORMAL：

```text
直接执行
```

HIGH：

```text
轻提示
```

EXTREME：

```text
必须确认
并推荐更粗 Resolution
但用户可以坚持
```

具体 Work Unit 阈值不在规格阶段拍脑袋。

必须在真实目标 iPhone 上 benchmark 后确定。

---

# 21. Evidence Policy

现有 AIFacts / Facts pipeline 继续作为确定性事实来源，但 Agent 不应把多张盘的完整 Facts JSON 直接拼接发送模型。

新增：

```text
AgentEvidenceBuilder
```

职责：

```text
Normalize
Deduplicate
Rank
Select
Group
Compress
```

---

## 21.1 Evidence 可包含

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

每条至少：

```text
id
source_chart
evidence_role
fact_type
data
```

可选：

```text
priority
strength
phase
exact_at
active_window
tags
```

---

## 21.2 默认不要发

除非确实需要：

```text
完整 raw longitude dump
全部 cusp degree
中间计算数据
重复 reference chart
wheel renderer data
```

Agent 版本经过用户 AI 数据授权后，允许在任务需要时发送：

```text
姓名/昵称
生日
出生时间
出生城市
关系身份
当前/目标城市
用户自然语言
Astrology Evidence
```

精确经纬度、内部 timezone 计算参数仍无需发送给模型，留在本地计算层。

---

## 21.3 Evidence Budget

不要用“最多 N 张盘”控制模型成本。

应控制：

```text
Evidence tokens
model cumulative input
output reserve
provider cost
```

第一版建议：

```text
Normal evidence target ≈ 16K tokens / Run
```

此值是工程初始目标，不是永远不变的商业承诺。

---

# 22. Evidence Round

v1 推荐：

```text
最多约 2 个本地 Evidence Round
```

Round 1：

```text
broad scan
foundation
major windows
```

Round 2：

```text
targeted drill-down
```

Round 2 若请求 focus window：

```text
必须来自 Round 1 evidence / discovered window
```

不要让模型第一轮任意编造一个日期要求 iOS 细算。

---

# 23. Budget 到顶不能“无答案”

必须预留 finalization budget。

如果达到：

```text
tool budget
token budget
provider cost budget
```

Runtime：

1. 停止继续 tool call；
2. 基于已有 Evidence 完成当前最佳结论；
3. 明确告诉用户分析已达到本次额度；
4. 说明还可以进一步分析什么；
5. 提供继续消耗下一个 Credit 的入口。

不得：

```text
直接报 quota error
最终没有答案
```

---

# 24. Chart Assets

每一次 Conversation 中出现的 Chart：

> **作为该 Conversation 独立的 Asset 记录。**

例如：

```text
Natal · Bill
Transit · Bill · New York · 2035.01.01
Synastry · You + Bill
Transit · Amy · Tokyo · 2035.01.01
```

---

## 24.1 Asset 和底层文件分离

逻辑 Asset：

```text
ConversationChartAsset
```

底层实际计算文件：

```text
ChartArtifactFile
```

通过：

```text
semanticFingerprint
```

关联。

所以：

```text
Conversation A → Natal Bill ┐
Conversation B → Natal Bill ├→ same underlying file
Conversation C → Natal Bill ┘
```

逻辑上三个 Asset。

物理存储只有一份完全相同的计算结果。

---

## 24.2 Fingerprint

必须至少覆盖：

```text
chart kind
subjects
birth-data identity hash
target date/time
target location
calculation preset
relevant range/resolution parameters
calculation schema version
```

同 fingerprint：

```text
复用底层文件
```

不同人物、不同关系组合、不同日期或地点：

```text
不同 fingerprint
```

---

# 25. Assets 页面

每个 Conversation 有自己的：

```text
Assets
```

Assets 页面主要列：

```text
Chart Assets
```

每张卡片明确显示：

```text
Chart type
Person / People
Location
Date / time
range / resolution if relevant
```

例如：

```text
Natal
Bill
1994.08.17 · Beijing
```

```text
Transit
Bill
New York · 2035.01.01
```

```text
Synastry
You + Bill
Relationship chart
```

---

# 26. 单个 Chart 页面

一个 Chart Asset = 一个完整 Chart Detail 页面。

页面包含：

```text
Chart title
Person / People card
Birth / subject information
Target date
Location
Time range
Resolution
Wheel
Aspects
Positions
Houses
Timing events
Calculation details
```

不要把：

```text
Aspects
Positions
House list
```

拆成独立 Asset。

它们属于这张 Chart。

---

# 27. Chat 内 Chart 展示

Chat 内必须让用户看到：

> Agent 刚刚真的完成了哪些本地计算。

但不要把所有数据铺满聊天流。

### 1 张盘

可以显示较大的 Chart Card / wheel thumbnail。

### 2–4 张

横向缩略 Chart Cards。

### 5 张以上

显示摘要：

```text
6 charts analyzed
[ View all charts ]
```

Agent 回答中的 Evidence reference 可跳转：

```text
Conclusion
↓
Evidence
↓
Chart Detail
↓
Wheel / Aspects / Positions
```

禁止仅显示：

```text
Calculation complete. Go to Assets.
```

---

# 28. Profiles

Profiles 是占星人物资料，不等于 Server Account。

本地保存：

```text
Profile
├── person_id
├── name
├── relation / role
├── birth date
├── birth time
├── birth location
├── timezone
├── location coordinates
└── data completeness
```

支持：

```text
You
Friends
Partner
Family
Others
```

Profiles 可在：

```text
+ → Profiles
```

选择后加入当前 Draft Context。

---

# 29. AI 数据授权

出生资料不是 iOS 系统权限。

第一次需要进行 AI 分析时：

显示 App 内授权：

```text
Allow AI Analysis
```

说明可能发送：

```text
birth date/time
birth city
selected people information
calculated astrology evidence
messages in the active analysis
```

一次授权后记录本地 consent。

Current Location 仍然单独走 iOS CLLocation 系统权限。

---

# 30. Account 原则

App 使用：

```text
Guest-first
Sign in with Apple only
```

不做：

```text
Email/password
Google login
Facebook login
phone OTP
Supabase Auth
```

正常使用本地功能不强制账户。

购买 Credits / 服务器资产需要：

```text
Sign in with Apple
```

---

# 31. Account 页面

More → Account 集中所有账户相关动作。

至少包含：

```text
Account
├── Sign in with Apple / Login state
├── Sign Out
├── Credits balance
├── Buy Credits
├── Purchase History
├── Subscription status
├── Manage Subscription / Cancel Subscription
├── Restore / Reconcile Purchases
├── Reset Account
└── Delete Account
```

Apple 要求的隐私、法律、支持等从 More / Settings 可访问。

订阅管理应跳转 Apple 官方订阅管理入口或使用系统提供的订阅管理方式，不自行假装取消 App Store 订阅。

---

# 32. Apple Authentication

iOS：

```text
ASAuthorizationAppleIDProvider
↓
identityToken
authorizationCode
nonce
↓
POST /auth/apple
```

Runtime 必须验证：

```text
JWS signature
nonce
iss
aud
exp
```

然后建立自己的：

```text
AppleIdentity
AstroAccount
CreditsWallet
```

Runtime 返回：

```text
access token
refresh token
```

日常 API 使用 StelyraAgent 自己的 token，不每次调用 Apple。

---

# 33. Account 数据模型

必须拆开：

```text
AppleIdentity
AstroAccount
CreditsWallet
```

而不是全部塞进一张 users 表。

---

## 33.1 AppleIdentity

```text
identity_id
apple_sub
apple_refresh_token_encrypted
status
created_at
updated_at
```

---

## 33.2 AstroAccount

```text
account_id UUID
identity_id
generation
status
created_at
reset_at
deleted_at
```

一个 AppleIdentity 历史上可以产生多个 generation。

正常只允许一个 active account。

---

## 33.3 CreditsWallet

```text
wallet_id UUID
account_id
app_account_token UUID
balance_cached
status
created_at
closed_at
```

**注意：本项目最终规则是 Reset 后创建新 Wallet，旧 Credits 不迁移。**

---

# 34. Reset Account 最终规则

Reset 不等于 Apple 身份注销。

流程：

```text
用户点击 Reset Account
↓
展示强警告
↓
二次确认
↓
处理当前可处理的 StoreKit unfinished transaction
↓
关闭旧 AstroAccount
↓
关闭旧 CreditsWallet
↓
旧 Credits 不迁移
↓
创建新 AstroAccount generation
↓
创建新 CreditsWallet / new appAccountToken
↓
iOS 根据选择清理本地 Profile / Conversation / Assets
↓
回到全新状态
```

重要：

> Reset / Delete 的要求不是“先把 Credits 数值写成 0”，而是执行后 **旧 Credits 不再有恢复路径**。

用户确认页必须明确：

```text
Your remaining Credits cannot be restored after this action.
```

不能只写模糊的：

```text
This action cannot be undone.
```

---

# 35. Delete Account 最终规则

流程：

```text
Delete Account
↓
明确显示 Credits 不可恢复
↓
二次确认 / 必要时重新认证
↓
reconcile unfinished transactions
↓
revoke sessions
↓
Apple token revoke
↓
close/delete AstroAccount
↓
close wallet
↓
删除/匿名化服务器账户数据
↓
清除本地认证 credential
↓
回到 Guest
```

用户若之后用同一个 Apple ID 再登录：

```text
创建新的 AstroAccount
创建新的 Wallet
不恢复旧 Credits
不恢复旧服务器账户
```

---

# 36. Reset/Delete 与在途购买

这是强制实现项。

**绝不能只删除数据库账户而不处理 StoreKit。**

Reset/Delete 前：

```text
scan Transaction.unfinished
```

对已 verified 且可交付的交易：

```text
先向旧 Wallet 完成 reconcile
```

再执行 Reset/Delete。

若存在真正 Apple `.pending`：

```text
允许用户 Reset/Delete
```

但必须提示：

```text
You have a purchase still pending with Apple.
Resetting/deleting your account won't cancel the App Store transaction.
If Apple completes it later, it may require support to resolve.
```

---

# 37. Purchase / Credits 正确事务

StoreKit 成功以后：

```text
purchase()
↓
verified transaction
↓
不要立即 finish()
↓
POST transaction to Runtime
↓
server verify
↓
DB transaction
    iap_transactions
    credit_ledger
↓
credited / already_processed
↓
iOS transaction.finish()
```

只有：

```text
Credits 已确认进入正确 Wallet
```

以后才 `finish()`。

---

# 38. IAP 幂等

表：

```text
iap_transactions
```

必须：

```text
transaction_id UNIQUE
```

Credit ledger：

```text
transaction_id UNIQUE
```

同一交易无论出现：

```text
purchase result
Transaction.updates
Transaction.unfinished
App restart
Restore
manual retry
```

都只能发放一次 Credits。

---

# 39. appAccountToken

每个 CreditsWallet 生成：

```text
app_account_token UUID
```

购买时传给 StoreKit。

Reset 后：

```text
new Wallet
→ new appAccountToken
```

这样 Reset 前后的购买归属明确分界。

旧 transaction 不得因为用户 Reset 后再次登录而自动记入新 Wallet。

---

# 40. Pending / Unfinished

`.pending`：

```text
不是 failed
```

UI：

```text
Purchase pending
We'll update your Credits when Apple completes the purchase.
```

App 启动立即监听：

```text
Transaction.updates
```

同时提供：

```text
Transaction.unfinished
```

主动 reconcile。

目标：

> 永远不要再出现“一笔交易留在队列里，后续购买一直卡住，而 App 没有自愈路径”。

---

# 41. Credits Runtime

Credits 使用：

```text
reserve
commit
release
```

不要一开始永久扣掉。

开始 AI 分析：

```text
reserve 1 credit
```

最终成功：

```text
commit
```

失败 / Runtime 崩溃 / 无有效最终输出：

```text
release
```

---

## 41.1 Credits 与模型预算

用户 Credits 不直接绑定固定 token 数。

内部维护：

```text
maxProviderCost
maxInput
maxOutput
maxToolRounds
finalizationReserve
```

未来不同模型可以：

```text
1 credit
2 credits
3 credits
```

但 v1 可先固定 DeepSeek。

---

# 42. Run 与 Credits 一致性

Run 表必须记录：

```text
run_id
wallet_id
credit_reservation_id
status
provider
model
input_tokens
output_tokens
reasoning_tokens
provider_cost
tool_rounds
created_at
completed_at
```

一个 Run 的 credit commit 必须幂等。

---

# 43. Runtime API v1

建议：

## Auth

```text
POST /v1/auth/apple
POST /v1/auth/refresh
POST /v1/auth/logout
POST /v1/account/reset
DELETE /v1/account
GET /v1/account
```

## Credits / IAP

```text
GET  /v1/credits
GET  /v1/purchases
POST /v1/iap/reconcile
GET  /v1/subscription
```

## Agent

```text
POST /v1/runs
GET  /v1/runs/:runId
POST /v1/runs/:runId/actions
POST /v1/runs/:runId/cancel
POST /v1/runs/:runId/ack
```

## Config

```text
GET /v1/capabilities
GET /v1/runtime-config
```

---

# 44. requires_action Contract

示例：

```json
{
  "run_id": "run_xxx",
  "status": "requires_action",
  "action": {
    "id": "action_xxx",
    "type": "astrology_tool",
    "tool": "request_astrology_evidence",
    "payload": {}
  }
}
```

Interaction：

```json
{
  "type": "interaction",
  "interaction": {
    "kind": "analysis_choice",
    "fields": []
  }
}
```

iOS 回：

```text
POST /runs/:runId/actions
```

必须带：

```text
action_id
```

重复提交相同 action_id：

```text
幂等返回已有结果
```

---

# 45. Local Conversation Store

建议：

```text
Conversation
├── id
├── title
├── createdAt
├── updatedAt
├── messages[]
├── chartAssetRefs[]
├── analysisRefs[]
├── localSummary
└── runtimeMetadata
```

Message 类型：

```text
userMessage
assistantMessage
interaction
chartReference
systemNotice
```

---

# 46. Conversation Assets

```text
ConversationChartAsset
├── asset_id
├── conversation_id
├── fingerprint
├── chart_kind
├── subject_refs
├── display_subjects
├── location_summary
├── time_summary
├── resolution
├── created_at
└── used_by_message_ids
```

底层文件：

```text
ChartArtifactFile
├── fingerprint PK
├── schema_version
├── payload_path
├── created_at
└── last_accessed_at
```

---

# 47. Analysis Asset

允许本地保存一次完整 Agent 分析：

```text
AnalysisAsset
├── analysis_id
├── conversation_id
├── user_question
├── analysis_plan
├── chart_asset_refs
├── key_evidence_refs
├── final_answer
└── created_at
```

普通用户页面不需要直接展示内部 Evidence ID。

可转换为：

```text
Key factors
```

---

# 48. Admin 后台

独立：

```text
stelyraagent-admin
```

不要接旧 Interstellar Admin。

---

## 48.1 v1 页面

```text
Dashboard
Users
Accounts
Credits
IAP Transactions
Subscriptions
Agent Runs
Models
Provider Usage
Runtime Config
Prompt Versions
Capability Versions
System Health
Audit Log
```

---

## 48.2 Dashboard 指标

至少：

```text
DAU / active accounts
guest → login conversion
credit purchase count
credit spend count
revenue
provider cost
gross margin estimate

run success rate
run failure rate
budget-limit rate
average model input/output tokens
average tool rounds
average charts per run
interaction rate
analysis completion time

pending IAP
unfinished IAP recovered
duplicate transaction prevented
reset count
delete count
```

---

# 49. Admin 安全

Admin 不直接读 SQLite 文件。

流程：

```text
Admin UI
↓
Runtime Admin API
↓
Repository
↓
SQLite
```

Admin 使用独立认证。

不要复用普通用户 Apple token。

第一版可使用：

```text
admin username/password
+ strong random password
+ NAS/private network restriction
```

后续再增加 2FA。

---

# 50. Privacy

原则：

```text
Local by default
Minimum necessary server data
Temporary Run payload
No server-side long-term chat archive
```

用户授权 AI 分析后可以根据任务发送必要出生信息和 Evidence。

服务器 Admin 默认不显示完整出生数据和完整消息正文。

运行日志只记录：

```text
IDs
types
sizes
usage
latency
error code
cost
```

不要默认记录完整 prompt / Evidence。

---

# 51. 错误与恢复

必须覆盖：

```text
network dropped while waiting for iOS calculation
app backgrounded
runtime restarted
provider timeout
provider rate limit
model tool-call malformed
invalid capability
missing profile data
unsupported app version
credit reservation expired
IAP transaction duplicate
IAP transaction pending
reset during active run
delete during active run
```

原则：

- 所有 action 有 ID；
- 所有账本写入幂等；
- Run 可恢复；
- Credits 可 release；
- StoreKit 可 reconcile；
- 用户最终尽量拿到当前最佳结果，而不是裸 error。

---

# 52. Runtime TTL

未完成 Run 不能永久存。

建议初始：

```text
active run TTL = 24h
```

可配置。

过期：

```text
expire run
release reserved credit
delete temporary payload
```

保留 metadata：

```text
run_id
failure/expiry reason
usage
```

---

# 53. Phase 1 实现范围

不要一次实现所有占星能力。

先跑通主链。

## Runtime

实现：

```text
Hono server
DeepSeek provider
Agent loop
Run state
requires_action
Interaction
AnalysisPlanCompiler skeleton
Credits reservation
Apple auth
IAP reconcile skeleton
SQLite
Admin API
```

## iOS

实现：

```text
StelyraAgent Chat shell
local ConversationStore
Profiles context
Draft Chips
Assets
ChartAssetStore
Agent API client
Tool executor
Run resume
AI consent
Account page
StoreKit transaction listener/reconcile
```

## 第一批 Agent capability

```text
you.natal
you.transit
you.secondary
relationship.synastry
relationship.composite
relationship.composite_transit
```

---

# 54. Phase 1 验收主链

必须真实跑通：

```text
User sends question
↓
Agent understands
↓
optional Interaction
↓
Analysis Plan
↓
Credit reserve if required
↓
requires_action
↓
iOS local calculation
↓
Chart Asset persisted
↓
Evidence returned
↓
Runtime resumes
↓
AI final answer
↓
iOS persists answer + Asset references
↓
ACK
↓
Runtime deletes temporary payload
↓
Credit commit
```

失败：

```text
release Credit
```

---

# 55. Phase 2

扩展：

```text
all You capabilities
relationship compare capabilities
Themes 8
Time Resolution complete policy
Technique-specific planners
Evidence compression/ranking
Advanced local timing scan
Admin analytics
```

---

# 56. Phase 3

增加：

```text
OpenRouter
model selection
model-specific credit tiers
advanced relationship charts
Davison / Marks autonomous policy
long-range 10–100 year scan optimizations
local evidence memory / follow-up compression
```

---

# 57. 强制测试

## Agent Runtime

```text
tool pause/resume
duplicate action submission
invalid tool args
provider timeout
provider returns no final
budget exhausted finalization
runtime restart
TTL expiry
```

## Assets

```text
same fingerprint → one physical file
same chart in two conversations → two logical assets
different person → different fingerprint
different relationship pair → different fingerprint
different date/location → different fingerprint
```

## Account

```text
guest mode works
Apple login
logout/login
reset
delete
same Apple ID after reset
same Apple ID after delete
new account generation
new wallet after reset
old credits not restored
```

## IAP

```text
purchase success
network failure before server credit
app killed before finish()
Transaction.unfinished recovery
Transaction.updates recovery
duplicate transaction
pending purchase
reset with unfinished
reset with pending
delete with pending
restore/reconcile
```

---

# 58. Reset/Delete 验收标准

Reset 确认页必须明确出现：

```text
Remaining Credits will not be recoverable after reset.
```

Delete 确认页必须明确出现：

```text
Remaining Credits will not be recoverable after account deletion.
```

不能只写：

```text
This action cannot be undone.
```

Reset 之后：

```text
new account_id
new wallet_id
new appAccountToken
balance = 新账户初始规则
旧 balance 不迁移
```

Delete 后再次登录：

```text
new account
new wallet
不恢复历史 server account / credits
```

---

# 59. 不做事项

v1 不做：

```text
server-side long-term conversation sync
Supabase
RAG
vector DB
MCP
Mastra
LangGraph
multiple autonomous subagents
web version of Chat
cross-device Chat sync
automatic cloud backup of Profiles
AI-side astrology calculation
```

---

# 60. 最终架构图

```text
┌─────────────────────────────────────────────┐
│                StelyraAgent iOS              │
│                                             │
│  Chat / Themes / Charts / Profiles          │
│  Conversation Store                         │
│  Asset Index                                │
│  Chart Artifact Store                       │
│  AstroCore / Swiss Ephemeris                │
│  AgentEvidenceBuilder                       │
│  StoreKit 2                                 │
└──────────────────────┬──────────────────────┘
                       │ HTTPS
                       │
┌──────────────────────▼──────────────────────┐
│          stelyraagent-runtime (NAS)          │
│                                             │
│  Hono / Node.js / TypeScript                │
│  Vercel AI SDK                              │
│  AstrologyAgentRuntime                      │
│  CapabilityCatalog                          │
│  AnalysisPlanCompiler                       │
│  InteractionPolicy                         │
│  Evidence Budget                           │
│  DeepSeek → OpenRouter                      │
│                                             │
│  Sign in with Apple                        │
│  Account / Wallet                           │
│  StoreKit Ledger / Credits                  │
│  Active Run State                           │
│  SQLite                                     │
└──────────────────────┬──────────────────────┘
                       │ Admin API
┌──────────────────────▼──────────────────────┐
│           stelyraagent-admin (NAS)           │
│                                             │
│  React / Vite                               │
│  Users / Credits / Purchases / Runs         │
│  Models / Costs / Runtime Config            │
└─────────────────────────────────────────────┘
```

---

# 61. 开发顺序

必须按顺序：

```text
1. 新建独立 stelyraagent-runtime repo
2. Hono + SQLite + Docker
3. Run state machine
4. DeepSeek + AI SDK
5. Tool pause/resume
6. iOS local tool bridge
7. Conversation Store
8. Chart Asset / fingerprint
9. Agent Evidence
10. Interaction / Analysis Plan
11. Apple Auth
12. Credits Wallet + ledger
13. StoreKit reconciliation
14. Reset/Delete
15. Admin
16. 第一批 6 capabilities
17. Integration tests
18. 再扩展完整 Catalog / Themes
```

禁止先大量做高级 Chart orchestration，而主 Run / IAP / resume 链还没跑通。

---

# 62. 现有实现可复用的关键点

现有 iOS 已存在的设计应优先复用：

- `SavedPerson` / Profile 选择；
- `ChartContext` 已把人物、日期、地点等参数封装为 Chart 计算上下文；
- `semanticFingerprint` / `factsHash` 已用于生成结果一致性与缓存；
- `GeneratedChartArtifact` 已按 fingerprint 做本地文件保存；
- 当前 AI 请求已有 evidence ID / allowed evidence 的概念；
- Themes 旧设计已经明确：Themes 是 orchestration，不应重新实现 Astrology Calculation。

因此 Agent 改造重点是：

```text
把单盘 AI pipeline
升级为
Agent orchestration + multi-chart evidence + local assets
```

而不是推倒 AstroCore。

---

# 63. Definition of Done

v1 不以“能和 AI 聊天”为完成。

必须同时满足：

```text
1. Chat / Chart / Theme 三种入口共用同一 Runtime
2. Agent 可以暂停等待 iOS 本地算盘并恢复
3. 用户能看到每一张 Agent 使用过的 Chart Asset
4. 相同 fingerprint 物理文件去重
5. Conversation 长期只在本地
6. AI Evidence 不重新计算占星事实
7. 1 Credit 不会因为失败无答案而永久丢失
8. Apple login / logout / reset / delete 可用
9. Reset/Delete 明确提示 Credits 不可恢复
10. StoreKit unfinished/pending 可以自动恢复，不再卡死后续购买
11. Runtime 与 Admin 是独立 StelyraAgent 项目
12. 不依赖 Interstellar Relay / Supabase
```

达到上述条件后，才进入完整 Themes / advanced relationship / OpenRouter 阶段。

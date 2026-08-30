# StelyraAgent 项目整合与首次部署设计

日期：2026-08-30  
状态：已获用户批准，进入实施

## 1. 目标与边界

将附件 `astro-agent-phase3-final-2026-08-30-combined.zip` 导入当前空的 `main` 分支，形成名为 StelyraAgent 的项目工作区，并完成首次真实环境部署与集成验证。

本次工作保持附件项目的既有架构和产品约束，不进行新功能设计或核心重构。iOS 工程的显示名称、target/project 名称、包名、Docker 服务名、镜像名、文档标题和用户可见文案统一为 `StelyraAgent`；Bundle ID、StoreKit/IAP product ID 等 Apple 平台稳定标识只在确有必要且不破坏签名/购买链路时处理，不把稳定标识误当作显示名称改动。

附件 `AGENTS.md` 与随附的首次部署文本作为项目约束和验收清单使用；用户在对话中追加的 Colima、双容器 NAS 部署、buildx、热修复、iPhone 12 mini、临时 Logo 和 NAS 部署文档要求作为本次执行要求。

## 2. 目标拓扑

```text
Mac + Colima + buildx (linux/amd64)
        │  runtime image -> transfer/load -> start/health
        │  admin image   -> transfer/load -> start/API/UI
        ▼
NAS x86_64 / QNAP Container Station
  ├─ stelyraagent-runtime :8787
  │    └─ named SQLite volume mounted at /data
  └─ stelyraagent-admin   :8788 -> runtime Admin API

iPhone 12 mini
  └─ Debug build points to NAS LAN address, no provider key in the app
```

NAS 的实际检查结果和可复用操作步骤写入 `docs/NAS_DOCKER_DEPLOYMENT.md`；根目录 `AGENTS.md` 必须明确引用该文档，后续 NAS 操作以该文档为准。

## 3. 实施顺序

顺序按照用户最后确认的要求执行：

1. 导入附件，保留根目录 `AGENTS.md`，建立 Git 基线。
2. 接入 1024×1024 的临时 App Icon，并完成普通工程构建修复。
3. 运行源码测试、Runtime/Admin production build、Swift/AstroCore 测试和 iOS 无签名构建。
4. 在 Mac 的 Colima Buildx 上先构建 Runtime，再构建 Admin，目标平台为 `linux/amd64`。
5. 将两个镜像从 Mac 导出并传输到 NAS；NAS 只执行 `load` 和 Compose 启动，不在 NAS 上源码构建。
6. 先启动 Runtime，验证健康检查、SQLite 持久化、重启恢复和 fail-closed 行为；再启动 Admin，验证静态页面和 Admin API 链路。
7. 配置 iOS Debug 的 NAS 地址，重新生成 Xcode 工程，并将应用完整安装到已连接的 `HUAWEI PURA 70` 设备。该设备已被 CoreDevice 识别为 `iPhone 12 mini (iPhone13,1)`。
8. 在没有 Provider API Key 的情况下完成能执行的设备安装、启动、基础配置/能力/模型接口、无密钥错误路径和本地确定性能力测试。
9. 到达 Provider smoke test 前暂停，请用户填写 NAS 上 Runtime 的 API Key；用户填写后继续完成真实 Provider、简单 Natal/Transit E2E、红队和最终报告。

Apple/StoreKit 需要真实凭据或签名条件时，按验收清单单独标记为 `BLOCKED_BY_SECRET`，不使用伪造凭据绕过。

## 4. Docker 镜像与发布策略

镜像使用不可变版本标签，例如：

```text
stelyraagent/runtime:<git-sha>
stelyraagent/admin:<git-sha>
```

Compose 生产部署使用 `image:` 标签，不在 NAS Compose 文件中使用 `build:`。镜像构建在 Mac/Colima 完成，并显式指定 `--platform linux/amd64` 以匹配 NAS。

首次发布流程：

1. 本地依次构建 Runtime、Admin。
2. 对每个镜像执行 `docker save`，再压缩为传输包。
3. 通过 SSH/SCP 传到 NAS 部署目录。
4. 使用 NAS 的完整 Docker CLI 路径执行 `load`。
5. 写入对应的镜像标签，先启动 Runtime，再启动 Admin。
6. 只以健康检查通过和持久化验证通过作为部署成功依据。

热修复流程：

1. Mac 上只重新构建受影响的镜像并生成新标签。
2. 传输、加载新镜像。
3. 只对对应服务执行 `--no-build`、`--no-deps`、`--force-recreate`。
4. 验证容器健康、接口和日志。
5. 失败时恢复前一个镜像标签并重新创建对应服务。

SQLite 命名卷不能因应用热修复而删除或重建。禁止把源码直接拷贝到运行中的容器作为热修复方式。

## 5. 配置与密钥

Runtime 实际生产环境文件位于 NAS 部署目录下的：

```text
/share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent/stelyraagent-runtime/.env
```

文件不提交 Git、不打入镜像、不写入报告。Provider 测试前由用户填入：

```env
DEEPSEEK_API_KEY=
OPENROUTER_API_KEY=
```

优先使用 DeepSeek 做 smoke test；OpenRouter 仅在需要或用户提供对应 Key 时测试。JWT、数据加密、Admin 密码等本地随机秘密可在部署时生成，但不得输出到聊天或提交到仓库。iOS 不保存任何 Provider Secret。

## 6. iOS 临时 Logo

使用用户提供的原始图片生成项目临时图标，并按用户要求用 1024×1024 版本直接覆盖 Downloads 中的原始 PNG。最终接入位置：

```text
stelyraagent-ios/ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

资源保持方形、1024×1024、RGB、无透明通道、全幅背景，不在资源文件中预先加入圆角。

## 7. 已知的最小修复范围

基线已经发现以下普通构建问题，实施时只做最小修复：

- Runtime TypeScript 的 `.ts` 导入/编译配置，以及 Agent draft context 的类型兼容。
- Runtime `npm test` 对 Node `node:test` 与编译产物的扫描脚本问题，保留附件规定的 `test:core` 作为核心验收入口。
- Admin 缺失 CSS side-effect import 类型声明。
- XcodeGen 生成后的 Swift actor-isolation 和非 Optional `ChartSnapshot` 使用错误。
- Compose 从本地 `build:` 切换到可审计的版本化 `image:` 发布方式。

不修改 Credits reserve/commit/ACK、IAP 验证、Prompt 注入防护、Provider fail-closed、AstroCore 计算规则或服务器长期保存用户私有状态的边界。

## 8. 验收与报告

最终报告分别列出 Runtime、Admin、Docker/SQLite、iOS 编译与真机安装、Provider、Apple/StoreKit、端到端和红队结果。每项使用 `PASS`、`FAIL`、`BLOCKED_BY_SECRET` 或 `NOT_RUN`，不以局部通过替代整项结论。

完成后生成新的检查点压缩包和报告，保留原始附件 ZIP 不变；Downloads 中的原始 Logo 按用户明确要求更新为项目临时图标版本。

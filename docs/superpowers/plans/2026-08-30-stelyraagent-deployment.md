# StelyraAgent 首次整合、NAS 部署与真机验证实施计划

> 执行约束：按已批准设计执行；除 Provider API Key 填写点外不再请求阶段确认。

## 目标

将附件源码导入当前空的 `main`，统一项目对外名称为 `StelyraAgent`，接入临时 App Icon，修复普通构建问题，在 Mac/Colima Buildx 上构建两个 `linux/amd64` 镜像并部署到 NAS，完成无 Key 的基础验证和 iPhone 12 mini 真机安装；之后暂停等待用户填写 Provider API Key，再继续真实 Provider 和端到端验证。

## 执行步骤

### 1. 建立源码基线

- 解压附件到工作区，去掉压缩包外层目录的多余嵌套。
- 复制附件 `AGENTS.md` 到项目根目录，并追加 StelyraAgent 的 Colima/buildx、双容器 NAS、热修复、真机和文档引用规则。
- 检查并保留原始文件的 Git 历史边界；不覆盖原始附件 ZIP。
- 统一人类可见的项目名称、iOS 显示名称、项目/target 名称、Node package name、Docker service/container/image 名称和文档标题为 `StelyraAgent`；保留 Bundle ID、IAP product ID 等稳定平台标识，除非修改是签名或购买链路所必需。
- 建立 `.gitignore`，排除 `.env`、构建产物、镜像包、Xcode DerivedData、临时报告和本地密钥。

### 2. 接入 Logo 与生成工程

- 使用已经生成并验证的 1024×1024 RGB opaque PNG 替换 iOS AppIcon 资源。
- 按用户明确要求，将同一 1024×1024 文件覆盖 `/Users/xiaoguiwk/Downloads/ChatGPT Image 2026年8月30日 13_42_12.png`。
- 运行 `xcodegen generate`，不手工编辑生成的 pbxproj。
- 进行必要的 Xcode project/target/resource 名称改动，并检查 scheme、资源、Swift Package 和脚本引用。

### 3. 最小构建修复与基线回归

- 先运行现有 Runtime、Admin、iOS Python、AstroCore Swift 测试。
- 修复 Runtime 的 TypeScript `.ts` 导入编译配置和 Agent draft context 类型问题。
- 修复 Runtime 测试脚本对 `node:test` 与 `dist` 的错误扫描；以附件要求的 `test:core` 作为核心验收入口。
- 添加 Admin CSS side-effect import 类型声明。
- 修复 XcodeGen 后暴露的 Swift actor-isolation 和 `ChartSnapshot` 非 Optional 使用问题。
- 运行 Runtime/Admin production build、核心测试、Admin contract、iOS `pytest`、AstroCore `swift test` 和 iOS 无签名 `xcodebuild`。

### 4. 编写 NAS 部署运行手册

- 创建 `docs/NAS_DOCKER_DEPLOYMENT.md`。
- 记录本次只读勘察得到的 NAS 版本、架构、Docker/Compose/Buildx 路径、可用端口、数据目录和 IP 候选。
- 写明 Mac Colima → `linux/amd64` buildx → `docker save`/压缩 → `scp` → NAS `load` → Runtime → Admin 的顺序。
- 写明 SQLite named volume、健康检查、重启持久化、镜像版本标签、热修复、回滚和禁止在运行容器中拷贝源码等规则。
- 在根 `AGENTS.md` 中明确：NAS 实际部署必须参考该文档。

### 5. Mac/Colima 构建与 NAS 部署

- 使用 Colima 的 Buildx builder，显式目标 `linux/amd64`。
- 先构建 `stelyraagent/runtime:<version>`，再构建 `stelyraagent/admin:<version>`。
- 生成镜像清单、SHA/commit 记录和压缩传输包；不把 `.env` 或密钥放进镜像包。
- 传输到 `/share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent`，使用 NAS 完整 Docker CLI 路径加载。
- 先启动 Runtime，检查 `/health`、容器状态、日志、SQLite 写入/重启恢复和无 Provider Key 的 fail-closed；再启动 Admin，检查页面与 Admin API。
- 记录部署版本、容器状态、端口和持久化验证结果。

### 6. 无 Key 的 iOS 真机安装与验证

- 将 Debug Runtime base URL 配置为部署后实测可达的 NAS LAN 地址。
- 在 macOS/CoreDevice 中选择已连接的 `HUAWEI PURA 70`（实际设备：iPhone 12 mini）。
- 完成签名条件允许范围内的真实 Xcode 构建、安装和启动；签名受限时先完成 `CODE_SIGNING_ALLOWED=NO` 编译并记录阻塞，不删除功能模块。
- 在设备上验证启动、基础配置、能力/模型列表、无 Key 错误提示、确定性本地能力和 Runtime 基础链路。
- 在进入真实 Provider smoke test 前暂停，告知用户 `.env` 的准确填写位置。

### 7. 用户填写 Key 后继续

- 用户填写 NAS 上 `stelyraagent-runtime/.env` 的 Provider Key 后，重新创建 Runtime 服务。
- 先做 DeepSeek，再按条件做 OpenRouter；验证普通、结构化、工具、超时和 malformed output 路径。
- 运行简单 Natal/Transit E2E、能力矩阵/本地 chart smoke、prompt injection/red-team smoke、重启/idempotency 检查。
- 按 `PASS`、`FAIL`、`BLOCKED_BY_SECRET`、`NOT_RUN` 分项生成部署报告和新的检查点 ZIP。

## 检查点

1. 源码导入、命名统一、Logo、文档和 AGENTS 更新完成。
2. 本地测试和 production build 完成。
3. 两个 `linux/amd64` 镜像在 Mac/Colima 构建成功。
4. NAS Runtime/Admin 部署、健康检查和 SQLite 持久化完成。
5. iPhone 12 mini 安装和无 Key 测试完成。
6. Provider Key 填写后完成真实 Provider/E2E/报告。

## 不改变的边界

不新增第二套 Agent engine，不引入 Supabase/RAG/MCP/Mastra/PostgreSQL，不让 iOS/Admin 持有 Provider Secret，不削弱 Credits reserve/commit/ACK、IAP 验证、Prompt 安全策略、能力限制或服务端私有状态边界。

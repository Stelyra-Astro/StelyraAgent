# StelyraAgent NAS Docker 部署与热修复手册

更新时间：2026-08-30  
适用项目：StelyraAgent  
适用环境：Mac + Colima Buildx → QNAP NAS / Container Station

## 1. NAS 已探明环境

以下信息来自本次只读 SSH/Docker 检查；它描述的是部署前基线，不代表 StelyraAgent 已经部署成功。

| 项目 | 已确认值 |
| --- | --- |
| SSH 别名 | `nas` |
| 主机名 | `xiaoguiwk-s` |
| 架构 | `x86_64` / `amd64` |
| 系统 | QNAP QTS 5.2.9（Container Station） |
| Docker Engine | 27.1.2-qnap8 |
| Docker API | 1.46 |
| Compose | 2.29.1-qnap2 |
| Buildx | 0.21.2-qnap1 |
| CPU / 内存 | 4 CPU / 19.38 GiB |
| Docker socket | `/var/run/docker.sock` |
| Docker root | `/share/CACHEDEV6_DATA/Container/container-station-data/lib/docker` |
| 用户可用数据盘 | `/share/CACHEDEV4_DATA`，约 1003 GiB 可用 |
| Docker CLI | `/share/CACHEDEV4_DATA/homes/xiaoguiwk/docker-cli` |
| LAN 地址候选 | `192.168.0.103`（eth0）、`192.168.0.101`（br0） |
| StelyraAgent 端口 | 8787、8788 在探查时均未占用 |

NAS 默认 SSH PATH 中没有 `docker`、`docker compose` 或 `docker-compose`，后续命令必须使用上表中的完整 CLI 路径，或在同一 SSH 命令中显式设置 PATH。

探查时 NAS 上已有其他 Container Station 服务，但没有 StelyraAgent 容器，也没有修改现有容器、卷、网络或数据库。

## 2. 目标部署目录

只把 Compose、版本清单、镜像包和运行时配置放在 NAS；不把源码作为运行时部署依赖：

```text
/share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent/
├── docker-compose.yml
├── deployment.env                         # 只放镜像版本，不放秘密
├── images/
│   ├── stelyraagent-runtime-<version>.tar.gz
│   └── stelyraagent-admin-<version>.tar.gz
└── stelyraagent-runtime/
    ├── .env                                # 未跟踪的真实 Runtime 配置
    └── secrets/                             # 可选 Apple Root CA 等文件
```

Runtime 的 SQLite 数据必须使用 Compose named volume 挂载到 `/data`。不要把 SQLite 数据库放进镜像层，也不要在热修复时删除该卷。

真实 Provider Key 的填写位置是：

```text
/share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent/stelyraagent-runtime/.env
```

其中填写 `DEEPSEEK_API_KEY`，需要时再填写 `OPENROUTER_API_KEY`。该文件永远不进入 Git、镜像包或部署报告。

本次首次真机安装按用户指定顺序，在 Provider Key 填写前使用仓库内的
`deploy/nas/runtime-prekey.env` 作为该 NAS `.env` 的临时模板。它明确使用
`NODE_ENV=development`、关闭可用模型且不含任何 Provider/Apple Secret，只适用于
局域网安装、启动和无 Key 错误路径验证；不得将该配置当作生产公网配置。

## 3. Mac/Colima 构建原则

NAS 是 `amd64`，即使 Mac/Colima 是 Apple Silicon，也必须显式构建 `linux/amd64`。构建顺序固定为 Runtime 在前、Admin 在后。

版本标签必须可回滚，建议使用 Git commit SHA：

```text
stelyraagent/runtime:<git-sha>
stelyraagent/admin:<git-sha>
```

在 Mac 上确认 Colima Buildx builder：

```bash
colima list
docker context show
docker buildx ls
```

按顺序构建并加载到当前 Colima Docker：

```bash
docker --context colima buildx build \
  --builder colima \
  --platform linux/amd64 \
  --tag stelyraagent/runtime:<git-sha> \
  --load \
  ./stelyraagent-runtime

docker --context colima buildx build \
  --builder colima \
  --platform linux/amd64 \
  --tag stelyraagent/admin:<git-sha> \
  --load \
  ./stelyraagent-admin
```

`--load` 是为了让 `docker save` 能从本地 Colima 镜像存储导出。构建完成后检查镜像架构和摘要，再导出：

```bash
docker --context colima image inspect stelyraagent/runtime:<git-sha> --format '{{.Architecture}}/{{.Os}}'
docker --context colima image inspect stelyraagent/admin:<git-sha> --format '{{.Architecture}}/{{.Os}}'
docker --context colima save stelyraagent/runtime:<git-sha> | gzip > stelyraagent-runtime-<git-sha>.tar.gz
docker --context colima save stelyraagent/admin:<git-sha> | gzip > stelyraagent-admin-<git-sha>.tar.gz
```

不要把真实 `.env` 通过 Dockerfile `COPY` 进镜像，也不要把它和镜像包一起提交。

## 4. 传输与首次部署

先在 Mac 生成不含秘密的 `deployment.env`，内容只包含本次镜像标签，例如：

```env
STELYRAAGENT_RUNTIME_IMAGE=stelyraagent/runtime:<git-sha>
STELYRAAGENT_ADMIN_IMAGE=stelyraagent/admin:<git-sha>
```

然后传输 Compose、版本文件和两个镜像包：

```bash
scp docker-compose.yml deployment.env \
  stelyraagent-runtime-<git-sha>.tar.gz \
  stelyraagent-admin-<git-sha>.tar.gz \
  nas:/share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent/
```

在 NAS 上先建立目标目录和 Runtime 配置目录，再加载两个镜像：

```bash
ssh nas 'mkdir -p /share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent/images /share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent/stelyraagent-runtime/secrets'
ssh nas '/share/CACHEDEV4_DATA/homes/xiaoguiwk/docker-cli load --input /share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent/stelyraagent-runtime-<git-sha>.tar.gz'
ssh nas '/share/CACHEDEV4_DATA/homes/xiaoguiwk/docker-cli load --input /share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent/stelyraagent-admin-<git-sha>.tar.gz'
```

把实际 Runtime `.env` 放到上述指定位置并限制权限后，再按顺序启动：

```bash
ssh nas 'cd /share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent && chmod 600 stelyraagent-runtime/.env && /share/CACHEDEV4_DATA/homes/xiaoguiwk/docker-cli compose --env-file deployment.env up -d stelyraagent-runtime'
ssh nas 'cd /share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent && /share/CACHEDEV4_DATA/homes/xiaoguiwk/docker-cli compose --env-file deployment.env ps stelyraagent-runtime'
ssh nas '/share/CACHEDEV4_DATA/homes/xiaoguiwk/docker-cli inspect stelyraagent-runtime --format "{{.State.Status}} {{.State.Health.Status}}"'
```

Runtime 通过后再启动 Admin：

```bash
ssh nas 'cd /share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent && /share/CACHEDEV4_DATA/homes/xiaoguiwk/docker-cli compose --env-file deployment.env up -d stelyraagent-admin'
ssh nas 'cd /share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent && /share/CACHEDEV4_DATA/homes/xiaoguiwk/docker-cli compose --env-file deployment.env ps'
```

从 Mac 或同一 LAN 设备检查：

```bash
curl -fsS http://192.168.0.103:8787/health
curl -fsS http://192.168.0.103:8788/
```

如果 `192.168.0.103` 不可达，再使用 `192.168.0.101`。iOS Debug 的 Runtime URL 必须使用实际可达地址，不能使用手机上的 `127.0.0.1`。

## 5. 必做部署验证

### Runtime

- `docker compose ps` 显示运行中且 health 为 healthy。
- `/health` 返回成功 JSON。
- 容器日志没有启动异常、权限异常或未配置 Provider 的非预期放行。
- `/data` 是 named volume，不是容器临时层。
- 停止并重新启动 Runtime 后，SQLite 文件和服务状态仍然存在。
- 没有 Provider Key 时，Provider 调用必须 fail closed；不能使用假 Key 或静默切换到未授权 Provider。

### Admin

- Admin 容器运行并监听 8788。
- 静态页面可加载。
- Admin 请求只经过 Runtime Admin API，Admin 不挂载 SQLite。
- Runtime 未 healthy 时 Admin 不应被误判为完整可用。

### 设备链路

- iPhone 12 mini 已安装完整 Debug 构建并能启动。
- iOS 能访问 Runtime 的健康/配置/能力/模型接口。
- 无 Provider Key 的错误路径可观察、可解释，不把 Secret 写入 iOS。

## 6. 热修复与回滚

热修复必须仍然在 Mac/Colima 上完成构建，不能在 NAS 上执行源码构建。

1. 修改源码并在 Mac 上重新运行相关测试。
2. 只构建受影响镜像，使用新 commit SHA 标签。
3. 导出、传输、加载新镜像。
4. 更新 NAS 上的 `deployment.env` 镜像标签。
5. 只重建受影响服务：

```bash
ssh nas 'cd /share/CACHEDEV4_DATA/homes/xiaoguiwk/stelyraagent && /share/CACHEDEV4_DATA/homes/xiaoguiwk/docker-cli compose --env-file deployment.env up -d --no-build --no-deps --force-recreate stelyraagent-runtime'
```

6. 重新验证容器健康、接口和日志。
7. 若失败，将 `deployment.env` 恢复到上一版本标签，再用同样的 `--no-build --no-deps --force-recreate` 回滚对应服务。

Admin 热修复只替换 `stelyraagent-admin`；Runtime 热修复只替换 `stelyraagent-runtime`。除非有独立迁移方案，热修复不得删除 SQLite named volume、清空数据目录或改变数据 schema。

## 7. 当前未决项

部署前已确认 Docker 基础设施可用，但以下项目状态必须在实际执行时记录：

- 真实 Runtime `.env` 尚未由用户填写 Provider Key。
- 本次首轮可先使用 `deploy/nas/runtime-prekey.env` 完成局域网真机安装；这不是生产配置。
- NAS 外部 HTTPS、反向代理和公网域名尚未确认，本手册只覆盖 LAN 部署。
- Apple Sign in、App Store Server API、StoreKit/TestFlight 凭据尚未验证。
- Provider smoke test 必须等用户填写 Key 后再执行。

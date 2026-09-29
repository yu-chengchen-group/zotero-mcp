# zotero-mcp

`zotero-mcp` 提供 Zotero MCP 网关。默认 CPU 镜像不启用语义索引、向量嵌入或 Chroma；CUDA override 启用 Jina Embedding 和 Markdown-only RAG。

## 职责边界

| 组件 | 职责 | 运行位置 |
| --- | --- | --- |
| Zotero Desktop | 提供本地 API 和文献数据 | Windows 主机 |
| `zotero-mcp` | MCP、Zotero 适配补丁；GPU 模式额外提供 Embedding、Chroma/RAG | Docker 容器 |
| `cloudflared` | HTTPS 公网传输和 Cloudflare Tunnel | Windows 主机服务 |
| `document2md` | 文档转 Markdown，不属于本容器 | 独立项目/独立 Compose |

本项目不包含 PaddleOCR、Docling 或 tunnel 凭据。`document2md` 生成的 Markdown 是语义索引的优先正文来源。

## 目录职责

| 目录/文件 | 职责 |
| --- | --- |
| `Dockerfile` | 构建默认 CPU 镜像，不安装 semantic extra |
| `Dockerfile.cuda` | 构建 CUDA + Embedding/RAG 镜像 |
| `docker/` | Windows 主机 Zotero API 适配、Markdown 索引和工具补丁 |
| `config/` | GPU 语义索引配置模板与本地配置 |
| `env/` | 本地运行参数模板；真实凭据不提交 |
| `docker-compose.yml` | 默认 CPU 配置 |
| `docker-compose.cuda.yml` | GPU override |

Zotero Desktop / Actions & Tags 脚本统一维护在独立仓库
[`../zotero-actions/`](../zotero-actions/) 中，不属于 MCP 服务实现。

## 启动

首次使用时复制环境模板，将 `ZOTERO_DATA_DIR` 改为自己的 Zotero 数据目录，并将 `ZOTERO_MCP_RESOURCE_URL` 中的 `xxx` 改为分配给自己的标识：

```powershell
Copy-Item env/.env.example .env
gh auth refresh -h github.com -s read:packages
gh auth token | docker login ghcr.io -u <GitHub用户名> --password-stdin
docker compose pull
docker compose up -d
```

启动前确认：

1. Zotero Desktop 正在运行，并已启用本地 API；
2. `ZOTERO_DATA_DIR` 指向包含 `zotero.sqlite` 的 Zotero 数据目录；
3. Docker Desktop 可以正常运行 Linux 容器。

默认镜像不安装语义检索依赖，不加载 Embedding 模型，也不创建 Chroma 向量索引，因此不需要 NVIDIA GPU。

服务仅绑定本机：

```text
http://127.0.0.1:8000
```

## GPU 模式

首次使用先复制语义配置，再使用 CUDA override：

```powershell
Copy-Item config/zotero-mcp-config.example.json config/zotero-mcp-config.json
docker compose -f docker-compose.yml -f docker-compose.cuda.yml up -d --build
```

- GPU 模式在同一个容器中运行 Embedding 和 MCP。
- Chroma 数据使用 `zotero-mcp-chroma` Docker volume 持久化。
- Hugging Face 模型缓存使用独立的外部 Docker volume。
- Zotero 数据目录只读挂载；语义索引只读取 Markdown，失败时保留元数据，不回退 PDF。
- 原地覆盖 Markdown 不一定触发增量更新；需要时执行全量重建：

```powershell
.\update-semantic-index.ps1
```

该脚本会清空当前 Chroma collection 后全量重建，仅在明确需要重建时运行。

## Cloudflare Tunnel

Tunnel 不放进 MCP 容器，也不暴露 Zotero `23119`、PaddleOCR `8080` 或 document2md `18321`。

Cloudflare Tunnel 的公网域名由管理员分配；本机目标固定为：

```text
ChatGPT 网页版
    ↓ HTTPS
Cloudflare Tunnel
    ↓
127.0.0.1:8000 → zotero-mcp
```

Cloudflare 配置只保存 Tunnel ID 和凭据文件路径；凭据文件保存在用户目录，不进入项目。

## 网络和数据边界

- MCP 容器通过 `host.docker.internal:23119` 访问 Windows 主机上的 Zotero 本地 API。
- MCP 端口绑定 `127.0.0.1:8000`，公网入口只由 Cloudflare Tunnel 提供。
- document2md 和 zotero-mcp 使用独立 Compose、镜像、网络和数据卷，仅通过 HTTP API 与共享 Zotero 附件目录协作。
- 不使用 `paddleocr-https-proxy`，不保留 Windows 原生 `zotero-mcp-runtime`。

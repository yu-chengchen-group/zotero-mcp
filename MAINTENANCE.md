# zotero-mcp 维护说明

本页面向维护者，记录镜像、Compose、GPU、Cloudflare Tunnel、网络和数据边界。

## 运行模式

默认 CPU 镜像提供 MCP、Zotero 适配和本地文献访问。CUDA override 在同一服务中增加 Jina Embedding、Chroma 和 Markdown-only RAG。

## 职责边界

| 组件 | 职责 | 运行位置 |
| --- | --- | --- |
| Zotero Desktop | 提供本地 API 和文献数据 | Windows 主机 |
| `zotero-mcp` | MCP、Zotero 适配；GPU 模式增加 Embedding、Chroma/RAG | Docker 容器 |
| `cloudflared` | HTTPS 公网传输和 Cloudflare Tunnel | Windows 主机服务 |
| `document2md` | 文档转 Markdown | 独立项目 / 独立 Compose |

`document2md` 生成的 Markdown 是语义索引的优先正文来源。Tunnel 凭据由 Windows 主机上的 Cloudflare 服务管理。

## 目录职责

| 目录/文件 | 职责 |
| --- | --- |
| `Dockerfile` | 构建默认 CPU 镜像 |
| `Dockerfile.cuda` | 构建 CUDA + Embedding/RAG 镜像 |
| `docker/` | Windows 主机 Zotero API 适配、Markdown 索引和工具补丁 |
| `config/` | GPU 语义索引配置模板与本地配置 |
| `env/` | 本地运行参数模板 |
| `docker-compose.yml` | 默认 CPU 配置 |
| `docker-compose.cuda.yml` | GPU override |

Zotero Desktop / Actions & Tags 脚本维护在 [zotero-actions](https://github.com/yu-chengchen-group/zotero-actions) 仓库。

## 手工启动

维护者需要直接执行 Compose 流程时：

```powershell
Copy-Item env/.env.example .env
gh auth refresh -h github.com -s read:packages
gh auth token | docker login ghcr.io -u <GitHub用户名> --password-stdin
docker compose pull
docker compose up -d
```

启动条件：

1. Zotero Desktop 正在运行，并已启用本地 API。
2. `ZOTERO_DATA_DIR` 指向包含 `zotero.sqlite` 的 Zotero 数据目录。
3. Docker Desktop 正常运行 Linux 容器。

服务绑定：

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
- Zotero 数据目录以只读方式挂载。
- 语义索引以 Markdown 为正文来源，解析失败时保留元数据。

需要全量重建索引时执行：

```powershell
.\update-semantic-index.ps1
```

该脚本清空当前 Chroma collection 后全量重建。

## Cloudflare Tunnel

公网访问统一经 Cloudflare Tunnel 进入本机 `127.0.0.1:8000`：

```text
ChatGPT
   ↓ HTTPS
Cloudflare Tunnel
   ↓
127.0.0.1:8000
   ↓
zotero-mcp
```

Cloudflare 配置保存 Tunnel ID 和凭据文件路径；凭据文件保存在用户目录。

## 网络与数据边界

- MCP 容器通过 `host.docker.internal:23119` 访问 Windows 主机上的 Zotero 本地 API。
- MCP 端口绑定 `127.0.0.1:8000`，公网入口由 Cloudflare Tunnel 提供。
- document2md 和 zotero-mcp 使用独立 Compose、镜像、网络和数据卷，通过 HTTP API 与共享 Zotero 附件目录协作。
- Zotero 数据目录以只读挂载方式提供给容器。

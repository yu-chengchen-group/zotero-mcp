# zotero-mcp

`zotero-mcp` 是课题组定制的 Zotero MCP 网关。学生默认使用 CPU 镜像，只提供 Zotero MCP，不启用语义索引、向量嵌入或 Chroma；PC-CYC 使用 CUDA override 启用 Jina Embedding 和 Markdown-only RAG。

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
| `Dockerfile` | 构建学生默认 CPU 镜像，不安装 semantic extra |
| `Dockerfile.cuda` | 构建 PC-CYC CUDA + Embedding/RAG 镜像 |
| `docker/` | Windows 主机 Zotero API 适配、Markdown 索引和工具补丁 |
| `config/` | Zotero 数据库与语义索引配置 |
| `env/` | 本地运行参数模板；真实凭据不提交 |
| `docker-compose.yml` | 学生默认 CPU 配置 |
| `docker-compose.cuda.yml` | PC-CYC GPU override |

Zotero Desktop / Actions & Tags 脚本统一维护在独立仓库
[`../zotero-actions/`](../zotero-actions/) 中，不属于 MCP 服务实现。

## 启动

学生首次使用时复制环境模板，将 `ZOTERO_DATA_DIR` 改为自己的 Zotero 数据目录，并将 `ZOTERO_MCP_RESOURCE_URL` 中的 `xxx` 改为分配给自己的标识：

```powershell
Copy-Item env/.env.example env/.env
docker compose --env-file env/.env pull
docker compose --env-file env/.env up -d
```

启动前确认：

1. Zotero Desktop 正在运行，并已启用本地 API；
2. `ZOTERO_DATA_DIR` 指向包含 `zotero.sqlite` 的 Zotero 数据目录；
3. Docker Desktop 可以正常运行 Linux 容器。

学生默认镜像不安装语义检索依赖，不加载 Embedding 模型，也不创建 Chroma 向量索引，因此不需要 NVIDIA GPU。

服务仅绑定本机：

```text
http://127.0.0.1:8000
```

## PC-CYC GPU 模式

PC-CYC 使用 CUDA override：

```powershell
docker compose --env-file env/.env -f docker-compose.yml -f docker-compose.cuda.yml up -d --build
```

- GPU 模式在同一个容器中运行 Embedding 和 MCP。
- Chroma 数据使用 `zotero-mcp-chroma` Docker volume 持久化。
- Hugging Face 模型缓存使用独立的外部 Docker volume。
- Zotero 数据目录以只读方式挂载到 `/mnt/zotero`；语义索引正文固定为 Markdown-only，不修改原始附件。
- `docker/zotero_mcp_attachment_patch.py` 约束语义索引：存在 document2md Markdown 时只读取 Markdown；不存在 Markdown 时只索引条目元数据；不得回退解析 PDF、HTML 或其他附件正文。升级 `zotero-mcp-server` 后必须验证该补丁仍生效，避免意外恢复 PDF 正文嵌入。
- 同一 Markdown 附件被原地覆盖时，v0.13.0 上游增量扫描不一定能发现文件内容变化；当前已舍弃 mtime 状态补丁。更新 MD 后需重新建立语义索引，或让 Zotero 附件记录本身发生变化。PDF 自身变化不会触发正文嵌入。
- 需要从头重建语义索引时，从项目目录运行固定入口：

```powershell
.\update-semantic-index.ps1
```

该脚本会清空整个 Chroma collection，再为当前 Zotero library 全量重建索引；会覆盖其他库在此 collection 中的索引。它通过 `/app/zotero_mcp_entrypoint.py` 启动 CLI，并启用 `--force-rebuild --fulltext --clear-fulltext-cache --allow-mass-deletion`，确保 Markdown、Jina 和本地适配补丁生效。仅在确实要清空并重建整个索引时运行。不要直接执行容器内的裸命令 `zotero-mcp update-db --fulltext`；裸命令会绕过本项目入口补丁。

## Cloudflare Tunnel

Tunnel 不放进 MCP 容器，也不暴露 Zotero `23119`、PaddleOCR `8080` 或 document2md `18321`。

Cloudflare Tunnel 的公网域名由课题组统一分配；本机目标固定为：

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

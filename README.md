# zotero-mcp

让 ChatGPT 访问个人电脑上的 Zotero 文献库。

学生默认使用 CPU 模式，通过 Zotero Desktop、本地 API 和 Markdown 文献内容提供检索与阅读能力。

## 首次安装

准备以下软件：

- Zotero Desktop
- Docker Desktop
- Git for Windows
- GitHub CLI

完成 GitHub 登录：

```powershell
gh auth login
gh auth setup-git
```

为 GitHub Packages 添加读取权限并登录 GHCR：

```powershell
gh auth refresh -h github.com -s read:packages
gh auth token | docker login ghcr.io -u <GitHub用户名> --password-stdin
```

下载并安装：

```powershell
gh repo clone yu-chengchen-group/zotero-mcp
cd zotero-mcp
.\install.cmd
```

安装器会：

- 查找 Zotero 数据目录
- 询问管理员分配的 Zotero MCP 公网地址
- 生成本机 `.env`
- 拉取课题组 Docker 镜像
- 启动 Zotero MCP 容器

启动 Zotero Desktop，然后验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 doctor
```

验证通过后，本机 Zotero MCP 环境配置完成。

## 日常使用

日常使用时保持以下组件运行：

- Docker Desktop
- Zotero Desktop
- Cloudflare Tunnel 服务

`zotero-mcp` 容器使用 Docker 的自动恢复机制运行。

在 ChatGPT 中连接管理员提供的 OAuth Client ID 和 MCP URL。连接完成后，可通过自己的 Zotero 文献库进行检索、全文读取、比较和总结。

## 更新

进入 Zotero MCP 仓库目录：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 update
```

启动 Zotero Desktop 后验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 doctor
```

验证通过后即可继续使用。

## 工作结构

```text
ChatGPT
   ↓ HTTPS
Cloudflare Tunnel
   ↓
Zotero MCP
   ↓
Zotero Desktop
   ↓
个人 Zotero 文献库
```

学生默认使用 CPU 模式。CUDA 模式提供 Embedding、Chroma 和语义检索能力。

维护者的镜像、Compose、GPU、网络和数据边界见 [MAINTENANCE.md](MAINTENANCE.md)。

## 卸载

进入 Zotero MCP 仓库目录：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 uninstall
```

本机 `.env` 和 Zotero 数据继续保留，便于后续恢复。

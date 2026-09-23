"""为 document2md Markdown 图片增加最小只读 MCP 工具。"""

from __future__ import annotations

import re
from pathlib import Path

from fastmcp.utilities.types import Image


_STORAGE_ROOT = Path("/mnt/zotero/storage")
_ATTACHMENT_KEY_RE = re.compile(r"[A-Z0-9]{8}")
_IMAGE_NAME_RE = re.compile(r".+_fig_\d+\.(?:jpg|png)", re.IGNORECASE)


def _read_md_image(attachment_key: str, image_name: str) -> Image:
    """读取一个 Markdown attachment 同目录下的 document2md 图片。"""
    if not _ATTACHMENT_KEY_RE.fullmatch(attachment_key):
        raise ValueError("attachment_key 必须是 8 位 Zotero key")
    if "/" in image_name or "\\" in image_name or ".." in image_name:
        raise ValueError("image_name 必须是同目录图片文件名，不能包含路径")
    if not _IMAGE_NAME_RE.fullmatch(image_name):
        raise ValueError("image_name 必须匹配 *_fig_<数字>.jpg 或 .png")

    base = (_STORAGE_ROOT / attachment_key).resolve()
    target = (base / image_name).resolve()
    if target.parent != base:
        raise ValueError("图片路径超出 attachment storage 目录")
    if not target.is_file():
        raise FileNotFoundError(f"图片不存在: {image_name}")

    return Image(path=target)


def install() -> None:
    """向现有 Zotero FastMCP 实例注册只读 Markdown 图片工具。"""
    from zotero_mcp._app import mcp

    if getattr(mcp, "_md_image_tool_installed", False):
        return

    mcp.tool(
        name="zotero_read_md_image",
        description=(
            "Read one document2md image from a Markdown attachment's Zotero storage directory. "
            "Pass the Markdown attachment's 8-character key and the exact *_fig_<number>.jpg/.png filename "
            "found in its Markdown."
        ),
    )(_read_md_image)
    mcp._md_image_tool_installed = True

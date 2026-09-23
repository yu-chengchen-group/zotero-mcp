FROM python:3.12-slim

LABEL org.opencontainers.image.source="https://github.com/yu-chengchen-group/zotero-mcp"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

ARG PIP_INDEX_URL=https://pypi.org/simple
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

RUN python -m pip install --no-cache-dir --break-system-packages \
    --index-url "${PIP_INDEX_URL}" \
    "zotero-mcp-server[scite]==0.13.0"

COPY docker/zotero_mcp_entrypoint.py /app/zotero_mcp_entrypoint.py
COPY docker/zotero_mcp_attachment_patch.py /app/zotero_mcp_attachment_patch.py
COPY docker/zotero_mcp_auth_patch.py /app/zotero_mcp_auth_patch.py
COPY docker/zotero_mcp_embedding_patch.py /app/zotero_mcp_embedding_patch.py
COPY docker/zotero_mcp_sidecar_patch.py /app/zotero_mcp_sidecar_patch.py
COPY docker/zotero_mcp_tool_disable_patch.py /app/zotero_mcp_tool_disable_patch.py

ENTRYPOINT ["python", "/app/zotero_mcp_entrypoint.py"]

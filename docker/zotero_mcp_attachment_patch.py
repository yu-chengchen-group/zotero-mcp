"""为 v0.13.0 保留严格 Markdown 来源和失败时旧 chunks 保护。"""

from pathlib import Path


_MARKDOWN_SUFFIXES = {".md", ".markdown"}


def install() -> None:
    """只限制上游本地全文缓存回退，并保护增量重写中的旧 chunks。"""
    from zotero_mcp import chroma_client, local_db, semantic_search

    if getattr(semantic_search, "_local_safety_patch_installed", False):
        return

    reader = local_db.LocalZoteroReader
    original_cache_lookup = reader._cache_lookup
    original_ft_cache_fallback = reader._zotero_ft_cache_fallback

    def cache_lookup_without_stale_fallback(self, target, attachment_key):
        cached = original_cache_lookup(self, target, attachment_key)
        if cached and cached[1] == "zotero-cache":
            return None
        return cached

    def ft_cache_for_selected_markdown(self, item_id, chosen=None, item_key=None):
        if not chosen:
            return None

        target, attachment_key = chosen
        target = Path(target)
        if target.suffix.lower() not in _MARKDOWN_SUFFIXES:
            return None

        text = self._read_zotero_ft_cache(attachment_key)
        if not text:
            return None

        source = "zotero-cache"
        self._cache_store(target, attachment_key, item_key, text, source)
        return text, source

    reader._cache_lookup = cache_lookup_without_stale_fallback
    reader._zotero_ft_cache_fallback = ft_cache_for_selected_markdown

    original_delete_item_chunks = chroma_client.ChromaClient.delete_item_chunks
    original_prepare_slice = (
        semantic_search.ZoteroSemanticSearch._prepare_and_classify_slice
    )
    original_upsert_documents = chroma_client.ChromaClient.upsert_documents
    original_upsert_embeddings = chroma_client.ChromaClient.upsert_embeddings

    def delete_item_chunks_after_success(self, item_key, group_id=None):
        if (
            group_id is None
            and getattr(self, "_preserve_chunk_ids_on_rewrite", False)
        ):
            return
        return original_delete_item_chunks(self, item_key, group_id=group_id)

    def prepare_slice_preserving_old_chunks(self, items, force_rebuild=False):
        client = self.chroma_client
        previous = getattr(client, "_preserve_chunk_ids_on_rewrite", False)
        client._preserve_chunk_ids_on_rewrite = True
        try:
            return original_prepare_slice(
                self, items, force_rebuild=force_rebuild
            )
        finally:
            client._preserve_chunk_ids_on_rewrite = previous

    def cleanup_stale_chunks(client, metadatas):
        parents = {}
        for metadata in metadatas:
            item_key = metadata.get("parent_item_key")
            count = metadata.get("n_chunks")
            if not item_key or count is None:
                continue
            try:
                count = int(count)
            except (TypeError, ValueError):
                continue
            group_id = metadata.get("group_id")
            parents[(item_key, group_id)] = count

        for (item_key, group_id), count in parents.items():
            expected = {f"{item_key}#{index}" for index in range(count)}
            where = {"parent_item_key": item_key}
            if group_id is not None:
                where = {
                    "$and": [
                        {"parent_item_key": item_key},
                        {"group_id": int(group_id)},
                    ]
                }
            result = client.collection.get(where=where, include=[])
            existing = set(result.get("ids", []))
            if expected.issubset(existing):
                stale = sorted(existing - expected)
                if stale:
                    client.delete_documents(stale)

    def upsert_documents_then_cleanup(self, documents, metadatas, ids):
        result = original_upsert_documents(self, documents, metadatas, ids)
        cleanup_stale_chunks(self, metadatas)
        return result

    def upsert_embeddings_then_cleanup(
        self, documents, metadatas, ids, embeddings
    ):
        result = original_upsert_embeddings(
            self, documents, metadatas, ids, embeddings
        )
        cleanup_stale_chunks(self, metadatas)
        return result

    chroma_client.ChromaClient.delete_item_chunks = delete_item_chunks_after_success
    semantic_search.ZoteroSemanticSearch._prepare_and_classify_slice = (
        prepare_slice_preserving_old_chunks
    )
    chroma_client.ChromaClient.upsert_documents = upsert_documents_then_cleanup
    chroma_client.ChromaClient.upsert_embeddings = upsert_embeddings_then_cleanup
    semantic_search._local_safety_patch_installed = True

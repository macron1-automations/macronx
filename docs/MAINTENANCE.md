# Maintenance

## Reprocessing workflow items

If you change a workflow's prompt (or your LLM setup) and want to re-run it on items that were already processed, you can re-process the most recent ones. This re-runs each item's tag workflow with the item's `payload` and overwrites the item's `body` and workflow metadata.

Re-process the 10 most recent processed items tagged `news`:

```sh
bin/rails workflows:reprocess COUNT=10
```

Point it at a different tag with `TAG`:

```sh
bin/rails workflows:reprocess COUNT=5 TAG=research
```

Behavior:

- Items are picked newest first, limited to `COUNT`.
- Only processed, non-archived items are included.
- Items whose tag has no workflow are skipped.
- A failed item does not abort the run; the error is recorded in the item's `metadata` and reported at the end.

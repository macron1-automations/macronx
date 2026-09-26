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

## Changing a tag's id

A tag's id is a plain auto-increment primary key, and every tag list in the app is ordered by name (`Tag.order(:name)`) — there is no `position` column, so changing an id never changes the order tags appear in. You need this when ids have to line up with something else: the inbox filter carries a tag id in the URL (`/inboxes?tag=9`), so a bookmarked or shared filter breaks as soon as the id means a different tag in a restored or migrated database.

Move the tag with id 9 to id 14:

```sh
bin/rails tags:renumber_id OLD_ID=9 NEW_ID=14
```

In Docker:

```sh
docker compose exec web bundle exec rake tags:renumber_id OLD_ID=9 NEW_ID=14
```

Behavior:

- Inbox items and workflows on the tag are repointed to the new id, and the counts are reported.
- Nothing is written if `NEW_ID` is already taken, if no tag has `OLD_ID`, if the two ids are the same, or if either is not a positive integer. The task prints the reason and the usage line.
- The whole change runs in one transaction, so a failure part-way through leaves both the ids and the foreign key constraints exactly as they were.

`update_column(:id, ...)` on its own cannot do this. `inboxes` and `workflows` both hold foreign keys to `tags.id`, and the rows have to be repointed in an order Postgres will accept: the children cannot point at the new id before it exists, and the tag cannot move while the children still point at the old one. The task drops the referencing constraints, repoints the rows, moves the id, and restores the constraints. It finds those constraints in `pg_constraint` rather than hardcoding the two tables, so a new table referencing `tags` is picked up automatically.

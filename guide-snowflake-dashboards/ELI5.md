# Snowflake Dashboards, Explained Simply

> Simplified from: [Roll Out Snowflake Dashboards as an Administrator](README.md)

Pair-programmed by SE Community + Cortex Code

## One-Sentence Version

Analysts can now publish live dashboards to coworkers, and by default anyone can share, so an administrator should decide who may share and make sure viewers can see the data.

## The Story

Think of a company library. Analysts write reports in a private workroom, which is a Snowsight workspace. When a report is ready, they put a published copy on the library shelf. Coworkers read the copy, never the draft.

These copies are special. Every time someone opens one, it looks up fresh numbers using that reader's own library card. A reader without access to the data sees an empty page. Two readers with different access can see different totals.

The library has three locks on sharing. A master switch turns sharing on or off for everyone. A per-type permission decides who may put copies on the shelf. A per-copy guest list decides who may read each one. Out of the box, the master switch is on and everyone holds the shelf permission.

## The Cast

- **Dashboard file (`.dash`):** the editable draft in the workroom.
- **Dashboard artifact:** the published, read-only copy people open.
- **Caller's rights:** each reader's queries run as that reader, on their own compute.
- **Master switch:** the account setting that turns all sharing on or off.
- **`MANAGE ACCESS` privilege:** permission to share one type of artifact. It starts out granted to everyone.
- **Owner:** whoever controls a copy. By default, that is the person who made it.

## What Changed

- Before, old dashboards ran on a shared identity. Now each viewer runs their own queries.
- Before, filters belonged to the whole account. Now each dashboard has its own.
- Before, there was a shared cache. Now each viewer pays for their own queries.
- The old Legacy Dashboards screen is gone. An upgrade button turns old dashboards into new ones.

## What to Watch Out For

- **Anyone can share by default.** Remove that permission from everyone and give it to a publisher role if you want control.
- **Other artifact types are riskier.** HTML reports, files, and saved chats are frozen snapshots. Their readers see the saved data even without access to the source.
- **Turning the master switch off hides copies but keeps their guest lists.** Turning it back on restores access.
- **Viewers need a warehouse and table access.** Without them, a shared dashboard shows nothing.
- **Compute grows with viewers.** Give viewers their own small warehouse with a timeout and a spending cap.
- **Some admin tools are not here yet.** You cannot yet list all artifacts or their grants with SQL.
- **Deleted copies cannot be restored.** Moving or renaming a draft can disconnect it from its published copy.
- **Upgraded old dashboards may show less.** They now use each viewer's access, not the owner's.

## The One Thing to Remember

Sharing a dashboard never shares the data behind it, so decide who may share, then grant viewers the data they need.

> For the full technical details, see the source document.

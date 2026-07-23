> Simplified from: [Cortex Search Access Control — README.md](README.md)

# Cortex Search Access Control: Plain-Language Summary

## One-Sentence Version

Snowflake's AI search feature runs as its owner — not as whoever calls it — so if you want different users to see different results, you have to build that restriction yourself using one of two available workarounds.

## The Story

Think of Cortex Search like a librarian who has a master key to every shelf. When you walk up and ask a question, the librarian answers based on *their* key — not yours. It doesn't matter that you're only supposed to see certain books; the librarian opens everything. That's "owner's rights," and it's how Cortex Search works today.

To fix this, you have two options. The first is to stamp each book with a list of who's allowed to read it, and train the librarian to always check that stamp before handing over a result. You hand the librarian your ID when you ask a question, and they only pull books that list you. This is Pattern 1 — the recommended approach for most situations.

The second option is to build separate reading rooms: one room contains only the books for Region A, another for Region B. Region A users only get a key to their room. No stamp-checking needed — the wrong books were never in their room to begin with. This is Pattern 2, and it's the safest option when you have a small number of clearly separated groups and can't risk the stamp being forgotten.

A smarter version — where the librarian automatically uses your key instead of theirs — does not yet exist in this product. There is no publicly announced release date for it.

## The Cast

| Concept | In plain words |
|---|---|
| **Cortex Search Service** | The AI-powered search index. You ask it questions in plain English and it finds the most relevant rows from your data. |
| **Owner's rights** | The security model where the search runs as the person who built the index — not the person asking. Everyone who can use the service sees everything the owner can see. |
| **ATTRIBUTES** | Columns you mark as "filterable" when you build the service. These are the fields you can use to narrow results at query time. |
| **`@contains` filter** | The specific filter that checks whether an array column holds a given value — the key tool for Pattern 1. |
| **Access control identifier** | Any ID you use as an access gate: an account ID, a user email, a tenant ID, a Salesforce record ID, etc. |
| **Caller's rights** | A future feature where the service would automatically respect the calling user's permissions. Not available yet. |

## What Changed

- **Before this guide:** teams either exposed all search results to all users, or tried to build ad-hoc restrictions without a clear pattern.
- **Now:** two documented, supported patterns with concrete SQL examples for enforcement.
- **Pattern 1 (filter UBAC):** tag each document with an array of authorized identifiers; inject the caller's ID at query time; one service handles all users.
- **Pattern 2 (separate services):** scope each service to one group's data at index time; grant roles only to their own service; no filter injection needed.
- **Hardening (Pattern 1 only):** wrap the search call in a stored procedure that injects the filter automatically — callers can't bypass it because they never touch the service directly.

## What to Watch Out For

**Pattern 1 has a real risk if you skip the hardening step.** If the app forgets to inject the filter, the full index is returned to the caller. This isn't theoretical — it happens when code paths are added later without awareness of the filter requirement. The stored procedure wrapper described in the pattern page eliminates this risk.

**Row-level masking on your source table does not carry over.** If you rely on column masking policies to hide sensitive values for certain users, those policies do not apply to Cortex Search results. The service bypasses them. Plan for this explicitly.

**Caller's rights is not yet available for Cortex Search, and Snowflake has not publicly announced when it will be.** Don't design a product or make a customer commitment based on it landing in a specific quarter.

## The One Thing to Remember

Cortex Search sees everything its owner can see — so enforcing what individual users see is your job, not the platform's, for as long as native caller's rights remains unavailable.

---

> For the full technical details, see the [README](README.md), [Pattern 1](filter-attribute-ubac.md), and [Pattern 2](separate-services.md).

# User search — a model, and three bugs found on the way

**Status:** proposal, awaiting Achia's choice. Nothing built.

**Ask (Achia, 2026-08-27):** contacts search is right — one letter should
surface everyone, because you already know those people. User search is not:
*"i dont want one to be able to send requests to all just like that."* Look at
what Instagram and Telegram do and offer a model.

---

## What the endpoint does today

`GET /auth/chat/search?keyword=` → `ChatService::search()`:

```php
User::select('id','first_name','last_name','email','avatar','last_activity_at')
    ->where('id','!=',$user_id)
    ->where('first_name','LIKE',"%{$keyword}%")
    ->orWhere('last_name','LIKE',"%{$keyword}%")
    ->orWhere('email','LIKE',"%{$keyword}%")
    ->get();
```

Three defects, independent of any product decision:

**1. Email addresses leak.** `email` is both matched *and returned*. Typing
`gmail` returns a page of strangers **with their email addresses**. That is an
enumeration vector and the most serious thing here — worth fixing whether or not
the model changes.

**2. The "not me" filter doesn't hold.** `AND` binds tighter than `OR`, so the
query is really `(id != me AND first_name LIKE …) OR (last_name LIKE …) OR
(email LIKE …)`. A match on either of the last two branches ignores the
exclusion, so a user can find **themselves** — and any exclusion added later
(blocked users, deactivated accounts) would be skipped the same silent way.

**3. No result cap and no rate limit.** `%k%` on a single letter returns an
unbounded slice of the user table, and the route carries no `throttle`
middleware, so it can be walked in a loop.

**Useful thing already in place:** every user gets a unique `@username` at
signup (`Helper::generateUniqueUsername`, slugged from their name), and there is
already an endpoint to change it. **No migration or backfill is needed** for any
model below.

---

## What Instagram and Telegram actually do

**Telegram — discovery by identifier, not by browsing.**
Profiles are not indexed by real name at all. You find someone by their exact
`@username`, or because their number is already in your phone contacts. Privacy
settings govern who can find you by number. Type a first name and you get
nothing.

**Instagram — browsing is allowed, but the abuse is capped at the action.**
Names and usernames are searchable, results are ranked by the social graph
(mutuals first), and the real defence sits on the *follow* side: roughly 20
follows an hour and a few hundred a day before a temporary block, plus spam
detection on the pattern.

Two different bets. Telegram narrows **who you can find**; Instagram allows
finding but limits **what you can do next**.

---

## Which bet suits Reacti

Reacti is a private messenger, not a discovery network — closer to Telegram.
And it matters more here than for either of them: opening a Reacti **turns on
your camera and sends your face back**. A stranger who can reach you is not a
follow request, it is a recording.

Reacti also already has the two directed paths Telegram leans on: **contacts
matching** and **personal invite links**. Someone who knows you in real life
never needs the search box. What is left for search is the narrow case of
someone who knows your handle.

---

## The three models

### Model A — identifier only (Telegram-strict)

Matches **`@username`, exact, case-insensitive**. One result or none. Names and
email are not searchable at all.

- Browsing is impossible: you cannot find anyone you cannot already name.
- Cost: you must know the exact handle; a typo returns nothing.
- Auto-generated handles are name-derived (`@dana_cohen`), so "I know their
  name" mostly still works — but two Danas mean `@dana_cohen1`, and guessing
  wrong is invisible to the searcher.

### Model B — prefix + graph rank (recommended)

Matches **`@username` by prefix**, minimum **3 characters**, capped at **20
results**, ordered by social distance: friends first, then friends-of-friends,
then everyone else. Names and email are not searchable.

- One letter returns nothing (below the minimum), so the browsing complaint
  goes away.
- Partial recall works: `@dana` finds `@dana_cohen` without knowing the suffix.
- The cap plus the ordering means a stranger sees at most 20 handles they
  already half-knew, and people they actually know sort to the top.
- Cost: a common prefix still shows up to 20 strangers' handles and avatars —
  orders of magnitude less than today, but not zero.

### Model C — keep substring search, cap the damage

Leave `%keyword%` on names, drop email, add a minimum length, a result cap and
rate limits.

- Smallest change; keeps today's "type a few letters, find a person" feel.
- Does **not** answer the actual complaint: three letters still returns a slab
  of strangers.

---

## The other half, in every model: cap the request, not just the search

This is Instagram's real defence and it is missing entirely.

- **Friend requests: N per hour, M per day** per account. Suggested start
  20/hour, 100/day — generous for a person, useless for a script.
- **Rejection back-off:** after K rejected or ignored requests, cut the limit.
  Someone whose requests are consistently unwanted is exactly the case worth
  slowing down.
- **Rate-limit `/search` itself** (`throttle:30,1`), which nothing does now.

Worth doing on its own even if the search model never changes, because it bounds
the harm from any future discovery surface.

---

## Recommendation

**Model B, plus the request limits.** Model A is safest and the most faithful to
Telegram, but it turns a mistyped handle into a dead end with no feedback, and
Reacti has no profile-link flow to fall back on the way Telegram does. Model B
keeps search usable for the one case it exists for — someone whose handle you
roughly know — while removing browsing, the email leak and the unbounded result
set.

Whichever model wins, **the three bugs above are worth fixing immediately**, the
email leak most of all.

## Rough shape of the work

1. **S1 — fix the bugs** (small, no product decision needed): group the
   `orWhere` clauses so the exclusion holds, stop matching and returning
   `email`, cap results, add `throttle` to the route. Contract test for the
   response shape.
2. **S2 — the chosen model** in `ChatService::search`, with tests for the
   minimum length, the cap and the ordering.
3. **S3 — request limits**, enforced server-side, with a clear client message
   when the cap is hit.

S1 is worth merging on its own whatever is decided about S2.

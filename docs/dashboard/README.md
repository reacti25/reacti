# Reacti CI Dashboard

A small static page that shows the current state of CI for this repo.
It lives at **`<your-pages-url>`** once GitHub Pages is enabled — see
"Enable" below.

## What it shows

* **Latest run status** for Backend CI and Flutter CI separately.
* **Pass rate** over the most recent 30 runs.
* **Average run duration** across successful runs.
* **Pass/fail bar chart** — last 30 runs colored green/red.
* **Duration line chart** — Backend CI vs Flutter CI duration over time.
* **Recent runs table** — newest 15 runs, click any row to open in GitHub Actions.

All data is **baked in at deploy time** (no client-side API calls), so
the dashboard works whether the repo is public or private.

## How it works

```
+--------------+        +-------------+        +-----------------+
| Backend CI   |        |             |        |                 |
| Flutter CI   |---+--->| workflow:   |------->| GH Pages static |
| ...other CI  |   |    | deploy-     |        | site            |
+--------------+   |    | dashboard   |        | (this folder)   |
                   |    +-------------+        +-----------------+
                   |          ^
                   |          | runs after CI completes
                   +----------+
```

The workflow `.github/workflows/deploy-dashboard.yml` runs whenever
Backend CI or Flutter CI completes. It uses `gh run list` to fetch the
last 60 runs, transforms the result into `data.json`, and deploys the
folder (HTML + JS + CSS + data.json) to GitHub Pages.

## Enable (one-time setup)

GitHub Pages on private repos requires a paid plan, so this
dashboard deploys to **Cloudflare Pages** instead (free for private
repos, same kind of static hosting). One-time setup:

### 1. Sign up for a free Cloudflare account

https://dash.cloudflare.com/sign-up — email + password, no card needed.

### 2. Create the Pages project

In the Cloudflare dashboard:

1. **Workers & Pages** → **Create application** → **Pages** tab → **Upload assets**.
2. Project name: **`reacti-ci`** (must match the `--project-name` flag
   in `.github/workflows/deploy-dashboard.yml`).
3. You can upload anything for the initial deploy — even an empty
   `index.html`. The GitHub workflow will overwrite it on the next push.

The site URL appears at the top of the project page once created,
something like `https://reacti-ci.pages.dev/`.

### 3. Get an API token

In Cloudflare dashboard:

1. **My Profile** (top-right avatar) → **API Tokens** → **Create Token**.
2. Use the **Custom token** template.
3. Permissions: add **Account · Cloudflare Pages · Edit**.
4. Account Resources: include the account you used above.
5. Continue → **Create Token** → copy the token immediately (you only
   see it once).

### 4. Get your Account ID

In the Cloudflare dashboard right sidebar of any Workers & Pages page,
"Account ID" — a 32-char hex string. Copy it.

### 5. Add the two values as GitHub repo secrets

`https://github.com/reacti25/reacti/settings/secrets/actions` →
**New repository secret**:

* `CLOUDFLARE_API_TOKEN`  — the token from step 3
* `CLOUDFLARE_ACCOUNT_ID` — the ID from step 4

### 6. Trigger the workflow

Push anything, or use **Actions → Deploy CI Dashboard → Run workflow**.
The site updates within ~30 seconds and the dashboard is live at the
URL Cloudflare assigned in step 2.

## File layout

```
docs/dashboard/
├── index.html      The page itself (cards + 2 charts + table).
├── style.css       Dark mode, GitHub-ish color palette.
├── dashboard.js    Fetches data.json on load, renders charts.
├── build.sh        Generates data.json from `gh run list`.
└── README.md       This file.
```

## Iterating locally

The dashboard is plain static files. Open `index.html` directly to see
the layout (the page will say "failed to load data.json" since the
file isn't generated locally by default).

To generate a real `data.json` locally:

```sh
cd docs/dashboard
GITHUB_REPOSITORY=reacti25/reacti ./build.sh > data.json
python3 -m http.server 8080   # or any static server
# open http://localhost:8080
```

## Why Cloudflare Pages?

* Free for private repos (GitHub Pages on private requires a paid plan).
* Static hosting only — no servers, no functions, no backend.
* No CDN configuration, no DNS setup; the `*.pages.dev` URL is
  assigned automatically.
* The same HTML / CSS / JS would also work on Netlify, Vercel, S3, or
  any static host if you want to switch later — the workflow's only
  CF-specific piece is the deploy step.

## Why not Codecov / a third-party service?

We picked a static dashboard because:

* Customisable — adding "patent-flow-only" filters or test-count
  trends later is just JS.
* Works identically across hosts.
* No commitment to a particular SaaS analytics product.

Codecov-style line-by-line coverage is a separate concern; we can
layer it on later if needed. The deploy-dashboard workflow could be
extended to download the `backend-coverage` and `app-coverage`
artifacts each run, parse the coverage %, and store it in a small
JSON history file. Skipped in the first version to keep the deploy
fast and simple.

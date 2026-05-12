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

The repo is public, so GitHub Pages works on the free plan. One-time:

1. Open https://github.com/reacti25/reacti/settings/pages
2. Under **Source**, pick **GitHub Actions** from the dropdown.

That's the whole setup. The `enablement: true` flag on
`actions/configure-pages` in the workflow also auto-enables Pages on
first run, so even step 1 above may be unnecessary — but flipping it
manually guarantees the very first workflow run succeeds.

After the first successful deploy, every push (and every CI run
completion) regenerates and republishes the dashboard. The URL is
stable: typically `https://reacti25.github.io/reacti/`.

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

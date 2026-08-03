# Awaken tile-fallback Worker

Last-resort map tier for `territory_page.dart` / `active_run_page.dart`.
**Not the primary map** — OpenFreeMap stays primary (full street-level
detail). This only gets used if both the primary style host and the
optional `MAP_STYLE_FALLBACK_URL` time out, so it trades detail (a global
extract capped at zoom 6 — country/city level, no streets) for never being
fully blank during an outage. See `MapStyleLoader`
(`lib/features/territory/presentation/widgets/map_style_loader.dart`) for
the escalation logic and `SESSION_HARDENING_STATUS.md` for why this exists.

Everything in this directory is vendored from Protomaps' official
[`PMTiles/serverless/cloudflare`](https://github.com/protomaps/PMTiles/tree/main/serverless/cloudflare)
Worker (a byte-range tile reader over an R2-hosted `.pmtiles` file), adapted
for this repo's layout. It's already been `npm install`ed, type-checked, and
dry-run built in this repo — the only things left require your Cloudflare
login, which nobody but you should ever paste into a chat or config file.

## What's here

- `generate_basemap.sh` — regenerates `generated/awaken-fallback-basemap.pmtiles`
  (gitignored — it's a ~45MB binary, regenerate rather than commit). Already
  run once; the file should exist locally from this session unless you've
  cleaned it up.
- `src/index.ts` + `shared/index.ts` — the Worker itself (R2 byte-range
  reads, gzip decompression, CORS, edge caching, TileJSON).
- `wrangler.toml` — bucket binding (`awaken-tile-fallback`) and CORS/cache
  vars, pre-filled for this project.
- `../../assets/map/fallback_style.json` — the MapLibre style the Flutter
  app bundles as a local asset. Its `{{TILE_WORKER_BASE_URL}}` placeholder
  is substituted at runtime by `MapStyleLoader` using `Env.tileWorkerUrl` —
  you don't need to hand-edit this file.

## Setup (steps only you can run — needs your Cloudflare login)

### 1. Create the R2 bucket

Cloudflare dashboard → **R2** → **Create bucket** → name it
`awaken-tile-fallback` (must match `wrangler.toml`'s `bucket_name`, or edit
both to match).

### 2. Upload the PMTiles file

The file is ~45MB, well under the 300MB web-UI upload limit, so the
simplest path is: R2 bucket → **Upload** → select
`generated/awaken-fallback-basemap.pmtiles` from this directory.

(If you regenerate a larger extract later that exceeds 300MB, use `rclone`
instead — see [Protomaps' Cloudflare guide](https://docs.protomaps.com/deploy/cloudflare#_1-upload-to-r2).)

### 3. Authenticate wrangler

```bash
cd infra/tile-worker
npx wrangler login
```

Opens a browser to authorize the CLI against your account — this is the
correct way to authenticate, never an API token pasted into a file or chat.

### 4. Deploy the Worker

```bash
npx wrangler deploy
```

Prints your Worker's URL, something like
`https://awaken-tile-fallback.<your-subdomain>.workers.dev`.


### 5. Verify it serves tiles

```bash
curl -I https://awaken-tile-fallback.<your-subdomain>.workers.dev/awaken-fallback-basemap/0/0/0.pbf
curl https://awaken-tile-fallback.<your-subdomain>.workers.dev/awaken-fallback-basemap.json
```

First should return `200` with `content-type: application/x-protobuf`;
second returns TileJSON describing the archive.

### 6. (Optional but recommended) Custom domain

`workers.dev` responses aren't cached by Cloudflare's edge cache — only a
zone on your own domain gets that. In your Worker's **Settings > Domains &
Routes**, add a **Custom Domain** (e.g. `tiles.yourdomain.com`). Without
this the Worker still works, just re-reads from R2 on every request instead
of serving cached responses.

### 7. Point the app at it

Add to `.env.client` (and `.env.client.example` stays as the template with
this blank):

```
TILE_WORKER_BASE_URL=https://awaken-tile-fallback.<your-subdomain>.workers.dev
```

or your custom domain from step 6 if you set one up. That's it —
`MapStyleLoader` only reaches this tier if both earlier tiers time out, so
you won't see it in normal use. To test it deliberately, temporarily point
`MAP_STYLE_URL` at an unreachable host and unset `MAP_STYLE_FALLBACK_URL`.

**Status: deployed.** Live at
`https://awaken-tile-fallback.codestormhub.workers.dev` — verified serving
both the root tile and a real non-root tile (`/3/4/3.pbf`) with
`200`/`application/x-protobuf`, and the TileJSON endpoint
(`/awaken-fallback-basemap.json`) reflects the expected vector-layer schema.
`TILE_WORKER_BASE_URL` in `.env.client` is already set to this URL.

## Cost

Free at this app's current scale — see the cost breakdown discussed when
this was built: R2's 10GB storage / 10M read ops free tier comfortably
covers a 45MB file, and Workers' 100k requests/day free tier only matters at
a request volume this fallback-only tier isn't expected to approach. R2 has
no egress fees ever, at any tier.

## Regenerating the basemap later

OSM data changes; there's no requirement to keep this perfectly fresh since
it's a last-resort overview map, not the primary. Every few months:

```bash
./generate_basemap.sh
```

Then re-upload `generated/awaken-fallback-basemap.pmtiles` to R2 (step 2
above) — no Worker redeploy needed, it reads whatever's in the bucket.

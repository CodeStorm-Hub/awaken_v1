#!/usr/bin/env bash
# Regenerates generated/awaken-fallback-basemap.pmtiles — a global,
# maxzoom-6 extract of Protomaps' daily OSM build. This is the *fallback*
# tier's basemap (country/city-level detail only), not the app's primary
# map — OpenFreeMap stays primary. Re-run this occasionally (every few
# months is plenty) to pick up OSM changes; there's no need to automate it.
#
# Requires: the `pmtiles` CLI (https://github.com/protomaps/go-pmtiles) on
# PATH. Download the release for your OS from the Releases page if you
# don't have Go installed to build it yourself.
set -euo pipefail

cd "$(dirname "$0")"

# Find the most recent available daily build (today's may not be published
# yet, so walk back a few days).
today=$(date -u +%Y%m%d)
source_url=""
for i in 0 1 2 3 4; do
  candidate=$(date -u -d "$today - $i days" +%Y%m%d 2>/dev/null || date -u -v-"${i}"d +%Y%m%d)
  url="https://build.protomaps.com/${candidate}.pmtiles"
  if curl -sfI "$url" >/dev/null; then
    source_url="$url"
    break
  fi
done

if [ -z "$source_url" ]; then
  echo "Could not find a recent Protomaps daily build. Check https://docs.protomaps.com/guide/getting-started" >&2
  exit 1
fi

echo "Using source: $source_url"
mkdir -p generated
pmtiles extract "$source_url" generated/awaken-fallback-basemap.pmtiles --maxzoom=6
pmtiles show generated/awaken-fallback-basemap.pmtiles

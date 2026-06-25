# TODO

## Stubbed / Partial (easiest wins)
- [ ] Smart Filter & MoreInGenre dashboard rows — types decoded but never rendered
- [ ] Series metadata completeness — publishers, characters (decoded but discarded; other contributor fields decided not worth showing)

## New Pages
- [ ] Collections & Reading Lists — browse and manage Kavita collections
- [ ] User statistics — pages read, series completed, reading history

## Reader
- [ ] Page bookmarking — Kavita API supports it
- [ ] Double-page spread mode

## UX / Discovery
- [ ] Custom dashboard layout — reorder/toggle row visibility (Kavita has an API for this)
- [ ] Favorites / watchlist — mark series without starting them
- [ ] Series recommendations — "more like this" based on shared tags/genres
- [ ] Bulk mark-as-read — multiple series or chapters at once

## Series / Metadata
- [ ] Series star rating — rate series 1–5, Kavita stores this per user
- [ ] Want to Read list — separate from in-progress, track intent (Kavita supports this)
- [ ] Related series — show sequels, prequels, spin-offs (Kavita has relationship data)
- [ ] Custom cover upload — let admins upload cover art for a series
- [ ] Tag / genre browser — clickable tags on series page navigate to a filtered list (currently only filterable from `/all`, not clickable from series detail page)

## Reader (more)
- [ ] Chapter list panel — jump to any chapter without leaving the reader
- [ ] Pinch-to-zoom on mobile
- [ ] "What to read next" prompt — suggest a series after finishing one

## Admin / Library
- [ ] Library statistics — total series, chapters, pages, storage used

## Integrations / Platform
- [ ] Scrobbling status UI — show AniList/MAL sync state (Kavita already tracks this)
- [x] PWA support — manifest.json missing, so app isn't installable yet (service worker/offline caching already exists)
- [ ] Random series picker — "surprise me" button, distinct from the randomized carousel row (low priority)

## Quality / Robustness (from 2026-06-25 audit)
- [ ] Distinguishable error states — `all.gleam`, `search.gleam`, `series/page.gleam` currently show blank/generic failure on API error with no retry and no way to tell "failed" from "empty"
- [ ] Empty states for chapters/volumes — series with 0 chapters/volumes renders blank space, indistinguishable from a loading state
- [ ] Alt text on series cover images — covers use `alt=""` instead of the series title (`elements/series.gleam`), hurts screen-reader users
- [ ] Mobile/responsive polish — `w-screen`/`h-screen` on login/setup pages (safe-area issue), cramped card grid on `/all` at small widths, dropdown menu overflows on narrow screens
- [ ] Fix N+1 metadata calls on home/search — home dashboard and search results fire one `/api/series/metadata` request per series shown instead of batching

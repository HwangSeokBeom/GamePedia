# Product 2.2 contract gaps (iOS)

Recorded against GamePediaCoreServer `a42ef7d0510c39811844293cc4dbebbf55a5da39`,
`openapi/product-2.2.openapi.json`, SHA-256
`c7bb0f485969d7d76375beb0c5e962ac1009dbe1c24a46612787a9b06632de55`.

Ten operations declare their 2xx body as `#/components/schemas/SuccessEnvelope`:

```json
"SuccessEnvelope": {
  "type": "object",
  "required": ["success", "data"],
  "properties": { "success": { "const": true }, "data": { "type": "object" } }
}
```

`data` has no `properties` and no `$ref`, so swift-openapi-generator types it as
`OpenAPIRuntime.OpenAPIObjectContainer` — untyped JSON. The client can call these
operations and can tell success from failure, but it cannot read a field out of
the response without guessing a key name that the contract does not state.

**No field is guessed anywhere in this app.** Where the response body is not
needed, it is ignored. Where it is needed, the section below says exactly what
that costs.

## Not affected — body genuinely not needed

| Operation | Path |
| --- | --- |
| `followCatalogGame` | `PUT /api/v1/catalog/games/{catalogGameId}/follow` |
| `unfollowCatalogGame` | `DELETE /api/v1/catalog/games/{catalogGameId}/follow` |
| `submitCatalogCorrections` | `POST /api/v1/catalog/games/{catalogGameId}/corrections` |
| `recordPlayCompassEvent` | `POST /api/v1/users/me/play-compass/events` |
| `deletePlaySession` | `DELETE /api/v1/users/me/play-sessions/{id}` |

These are acknowledgements. The app treats 2xx as "the server accepted it" and
reads nothing further. Follow/unfollow reconcile against the typed
`CatalogGameDetail.isFollowedByMe` on the next detail load.

## Worked around with a typed alternative

| Operation | Path | Workaround |
| --- | --- | --- |
| `createPlaySession` | `POST /api/v1/users/me/play-sessions` | The created row is re-read through `listPlaySessions`, whose 200 body **is** typed (`PlaySession[]`). Costs one extra request; invents nothing. |
| `updatePlaySession` | `PATCH /api/v1/users/me/play-sessions/{id}` | Same. |
| `getPlayCalendar` | `GET /api/v1/users/me/play-sessions/calendar` | **Not called.** The month grid is derived from `listPlaySessions` bounded by the month's UTC window, bucketed in the same IANA timezone that would have been sent to the endpoint. See the caveat below. |

### Caveat on the calendar

Deriving day buckets client-side is exactly what the dedicated endpoint exists
to avoid, and it is the one place the app computes a calendar boundary itself.
It is confined to `PlayCalendarDeriver`, which:

* asks the server for sessions in the month's half-open UTC window,
* buckets `playedAt` by the user's timezone using `Calendar`/`TimeZone`,
* never reinterprets a **Monthly Replay** result — `MonthlyReplay.window`,
  `monthKey` and `timezone` come from the server and are rendered verbatim.

If a future contract types the calendar response, delete `PlayCalendarDeriver`
and call the endpoint.

## Untyped objects inside otherwise typed responses

Three more places declare `{"type": "object"}` with no properties, so their
contents are untyped even though the surrounding response is typed.

| Schema / field | Effect |
| --- | --- |
| `searchCatalogGames` → `data.meta` | Holds the pagination cursor. Unreadable without guessing a key, so catalog search asks for one page at the contract maximum (`limit=50`) and does not paginate. |
| `listPlaySessions` → `data.meta` | Same; Playlog lists one page at `limit=50`. |
| `PublicArticle.heroImage` | Declared `{"type": ["object","null"]}` inline instead of `$ref: ArticleHeroImage`, so the article **detail** cannot type its hero. The reader takes the hero from the typed `ArticleSummary` card it was opened from; an article reached without a card shows no hero rather than an unreviewed one. |
| `PublicArticle.relatedGames` | Declared `{"items": {"type": "object"}}` instead of `$ref: ArticleRelatedGame`. Same treatment: related games come from the typed card, and are otherwise omitted. Note `ArticleSummary` gets both of these right — only the detail schema is untyped. |
| `ProductConfig.limits` | Not read. |
| `ProductConfig.allowlists` | Read *defensively* by `ProductConfigMapper`: if a `productEventCodes` array of strings is present it narrows what the app sends, and if it is absent or shaped differently the app falls back to the contract's own `eventCode` enum. Nothing depends on the key existing, and the value can only ever restrict — an event's validity is already guaranteed by the generated enum, which cannot express an undeclared code. |

## Blocked — reported, not faked

| Operation | Path | Blocked user scenario |
| --- | --- | --- |
| `confirmCatalogSubmission` | `POST /api/v1/catalog/submissions/{submissionId}/confirm` | After a successful Quick Add confirmation the app cannot learn the `catalogGameId` that was created or linked, so it cannot navigate the user straight to "the game you just registered". The confirmation screen reports the outcome it *does* know — PRIVATE registration versus PENDING_REVIEW public review, which is determined by the `requestPublicReview` flag the user themselves set — and offers a catalog search instead of a direct link. It never claims a specific game was linked. |
| `getCatalogSubmission` | `GET /api/v1/catalog/submissions/{submissionId}` | A "my submission status" screen cannot be built: status, resolution and the resulting game are all inside the untyped `data`. The operation is exposed on the API service and left uncalled by the UI. |

### Status in the shipped UI

Both are now live blockers against built screens, not hypotheticals:

* **`confirmCatalogSubmission`** — `QuickAddViewController.showCompletion` reports
  the outcome it can actually derive: PRIVATE registration versus a
  PENDING_REVIEW request, which follows from the `requestPublicReview` flag the
  user themselves set, plus created-versus-linked from the 201/200 status. It
  offers "카탈로그에서 찾아보기" (a normal catalog search) instead of a direct
  link, and never claims a specific game was created or linked. **No DTO is
  invented to fill the gap.**
* **`getCatalogSubmission`** — no submission-status screen exists. The operation
  stays on `Product22APIServicing` so the surface is complete, and no UI calls
  it. **No DTO is invented to fill the gap.**

### What the contract would need

For the two blocked operations, `SuccessEnvelope` should be replaced by a
response schema that names its `data`, in the same style the contract already
uses for `getCatalogGame` and `listPlaySessions`:

```json
"200": {
  "content": { "application/json": { "schema": { "allOf": [
    { "$ref": "#/components/schemas/SuccessEnvelope" },
    { "type": "object", "required": ["data"], "properties": {
        "data": { "type": "object", "required": ["submission"], "properties": {
          "submission": { "$ref": "#/components/schemas/CatalogSubmission" } } } } }
  ] } } }
}
```

with a `CatalogSubmission` schema exposing at minimum the submission status,
the resolution stage, and the resulting `catalogGameId` when one exists. The
same treatment on `getPlayCalendar` would let the calendar drop its
client-side aggregation.

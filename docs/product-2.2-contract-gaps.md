# Product 2.2 contract gaps (iOS)

Recorded against GamePediaCoreServer `ce083aa9d873c4f9338c0f926cc2cea647c455bf`,
`openapi/product-2.2.openapi.json`, SHA-256
`c0c5c0287879b4139306d59ef4951afc2d81d409ba34f24bdc7233e3c0612e27`.

## Resolved by server commit `6fbcf094`

Four operations previously declared their 2xx body as a bare
`SuccessEnvelope`. That revision typed all four, additively — 19 new schemas,
none removed, no existing schema altered, and the operation set unchanged at
26. Everything the app had worked around is now read from the generated types:

* `confirmCatalogSubmission` → `SubmissionConfirmResult`. Quick Add deep-links
  to the game it created or linked. All three paths return the same seven
  fields, so the app reads `createdNewGame` and `idempotentReplay` rather than
  branching on 200 versus 201, and an `identityConflict` points at the existing
  game without anything being merged.
* `getCatalogSubmission` → `SubmissionState`. `SubmissionStateViewController`
  shows status, the re-validated draft, the candidate summary and the resulting
  game.
* `searchCatalogGames` → `CatalogSearchResult` with a typed
  `meta.nextCursor`. Catalog search paginates properly, and `matchedBy`
  distinguishes an unreadable query from a genuine no-match.
* `listPlaySessions` → `PlaySessionListResult` with a typed
  `meta.nextCursor` over `(playedAt desc, id desc)`. The Playlog list
  paginates, and the calendar walks the cursor to aggregate a whole month.

The cursors are opaque: stored and passed back verbatim, never parsed.

## Still open

Six operations still declare their 2xx body as
`#/components/schemas/SuccessEnvelope`:

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
| `createPlaySession` | `POST /api/v1/users/me/play-sessions` | The created row is re-read through `listPlaySessions`, whose 200 body **is** typed. Costs one extra request; invents nothing. |
| `updatePlaySession` | `PATCH /api/v1/users/me/play-sessions/{id}` | Same. |
| `getPlayCalendar` | `GET /api/v1/users/me/play-sessions/calendar` | **Not called.** The month grid is derived from `listPlaySessions`, now following the typed cursor to the end of the month's window and bucketing in the user's timezone. See the caveat below. |

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
| `PublicArticle.heroImage` | Declared `{"type": ["object","null"]}` inline instead of `$ref: ArticleHeroImage`, so the article **detail** cannot type its hero. The reader takes the hero from the typed `ArticleSummary` card it was opened from; an article reached without a card shows no hero rather than an unreviewed one. |
| `PublicArticle.relatedGames` | Declared `{"items": {"type": "object"}}` instead of `$ref: ArticleRelatedGame`. Same treatment: related games come from the typed card, and are otherwise omitted. Note `ArticleSummary` gets both of these right — only the detail schema is untyped. |
| `ProductConfig.limits` | Not read. |
| `ProductConfig.allowlists` | Read *defensively* by `ProductConfigMapper`: if a `productEventCodes` array of strings is present it narrows what the app sends, and if it is absent or shaped differently the app falls back to the contract's own `eventCode` enum. Nothing depends on the key existing, and the value can only ever restrict — an event's validity is already guaranteed by the generated enum, which cannot express an undeclared code. |

## Previously blocked — now resolved

`confirmCatalogSubmission` and `getCatalogSubmission` were the two scenarios
this document reported as blocked. Server commit `6fbcf094` typed both, and the
app now implements them properly — the deep link and the submission status
screen. The workaround copy ("offers a catalog search instead of a direct
link") has been removed from `QuickAddViewController` along with it.

### What a future contract change would need

The six operations still on `SuccessEnvelope` are all acknowledgements, so
none of them blocks a user scenario today. If one ever needs to return
something, it should follow the shape commit `6fbcf094` established:

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

The same treatment on `getPlayCalendar` would let the calendar drop its
client-side aggregation and its cursor walk entirely.

# TailorTech — Backend API

Ruby on Rails 7.1 API for the TailorTech custom dress designing and tailoring
platform. Built against the existing React frontend in
[`../tailor_tech_frontend`](../tailor_tech_frontend) — every endpoint below
matches a call that app already makes.

```
React (Vite, :5173)
      │  Bearer JWT
      ▼
Rails API (:3000)
      ├── PostgreSQL          designs, library, measurements, orders
      ├── Redis + Sidekiq     preview cache, AI jobs, asset processing
      ├── Active Storage      S3 in prod (CloudFront), disk locally
      └── Python AI service   FastAPI — sketch, try-on, measurements, cut-out
```

---

## Requirements

| Component  | Version                        |
|------------|--------------------------------|
| Ruby       | 3.2+                           |
| PostgreSQL | 14+ (`pgcrypto`, `citext`, `pg_trgm`) |
| Redis      | 6+                             |
| ImageMagick| for Active Storage variants    |

## Setup

```bash
docker compose up -d
```

```bash
cp .env.example .env
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server -p 3000
```

Sidekiq, in a second terminal:

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

The frontend needs no change — its `.env` already points at
`http://localhost:3000/api/v1`.

Seeded accounts (all `password123`):

| Email                     | Role        |
|---------------------------|-------------|
| `admin@tailortech.app`    | super admin |
| `priya@tailortech.app`    | designer    |
| `customer@tailortech.app` | customer    |

Health check: `GET /up` reports database, Redis and AI-service status.

---

## API

Base path `/api/v1`. Authenticated routes take `Authorization: Bearer <token>`.

Errors always carry **both** shapes the frontend reads:

```json
{ "errors": ["Email is invalid", "Password is too short"],
  "error":  "Email is invalid" }
```

### Auth
| Method | Path | Notes |
|---|---|---|
| POST | `/auth/register` | `{name,email,password,password_confirmation,role}` → `{token,user}`. `role` can only be `customer` or `designer`. |
| POST | `/auth/login` | `{email,password}` → `{token,user}` |
| GET  | `/auth/me` | `{user}` |
| PATCH| `/auth/profile` | profile + avatar |
| DELETE | `/auth/logout` | 204 |

### Design library (Design Studio)
| Method | Path | Notes |
|---|---|---|
| GET | `/design_elements?category=neck` | **plain array** of `{id,name,image_url,…}`. Categories: `neck back_neck sleeve dress_type bodice skirt hemline fabric pattern color embroidery lace belt button accessory` |
| GET | `/design_elements/categories` | category list with counts |
| GET | `/design_elements/:id` | full detail incl. front/back/shadow URLs |
| GET | `/design_elements/:id/compatible?category=sleeve` | `{disabled, reason, allowed[], blocked_ids[]}` |

### Designs
| Method | Path | Notes |
|---|---|---|
| GET | `/dress_designs` | caller's designs, plain array |
| POST | `/dress_designs` | multipart: `name, neck_type, sleeve_type, dress_type, color, fabric, status` + optional `neck_image, sleeve_image, dress_image, fabric_image` |
| GET/PATCH/DELETE | `/dress_designs/:id` | |
| POST | `/dress_designs/:id/generate_sketch` | synchronous → `{sketch_url}` |
| POST | `/dress_designs/:id/duplicate` | |
| GET | `/dress_designs/:id/preview?view=front` | layer manifest |
| POST | `/previews` | manifest for an **unsaved** combination |

### Measurements
| Method | Path | Notes |
|---|---|---|
| GET/POST | `/measurements` | |
| PUT/PATCH/DELETE | `/measurements/:id` | |
| POST | `/measurements/estimate_from_photo` | multipart `photo` → `{estimated: {...}}` — not persisted; the user reviews before saving |

### Virtual try-on
| Method | Path | Notes |
|---|---|---|
| GET | `/virtual_tryons` | history |
| POST | `/virtual_tryons` | multipart `dress_design_id` + `photo` → `{result_photo_url}`. Pass `async=true` to queue it instead. |
| DELETE | `/virtual_tryons/:id` | |

### Boutique
| Method | Path | Notes |
|---|---|---|
| GET | `/boutique?city=Chennai` | **designer directory** — each card carries `best_design.sketch_url` |
| GET | `/boutique/:id` | designer + portfolio |
| GET | `/boutiques?lat=&lng=&radius=` | **physical store locator** with `distance_km` and `navigation_url` |
| GET | `/boutiques/:id` | |

### Designer workspace
| Method | Path | Notes |
|---|---|---|
| GET | `/designer/customers` | list with `measurement_count` |
| POST | `/designer/customers` | `{name,email,phone,password}` + optional flat measurement fields |
| GET | `/designer/customers/:id` | `{measurements: [...], designs: [...]}` |
| POST | `/designer/customers/:id/measurements` | `{measurement_name, height, …}` → the single measurement |
| GET/POST | `/designer/customers/:id/dress_designs` | |

### Orders
`GET/POST /orders`, `GET/PATCH /orders/:id`. Placing an order freezes a snapshot
of the design and the measurements so later edits cannot rewrite history.

### Super admin
| Method | Path |
|---|---|
| CRUD | `/admin/design_elements` (+ `publish`, `unpublish`, `reprocess`) |
| CRUD | `/admin/compatibility_rules` |
| CRUD | `/admin/boutiques` |
| GET/PATCH | `/admin/users` |

---

## Layer rendering engine

`app/services/layer_composer.rb`. No pre-rendered combinations are ever stored —
a design is resolved into an ordered stack of transparent layers:

```
Body → Dress Base → Neckline → Sleeve → Fabric → Pattern →
Embroidery → Lace → Belt → Buttons → Shadow
```

Each layer is `{slot, kind, name, url, z_index, color, blend_mode, opacity, meta}`.
The client paints them in `z_index` order and re-paints only the slot that
changed.

- Every manifest is fingerprinted (`SHA256` of the full selection) and cached in
  Redis under `tailortech:preview:v1:<view>:<fingerprint>`; a repeat combination
  is a cache read. `X-Preview-Cache: HIT|MISS` on `POST /previews`.
- Multi-colour stripes are ordered by the spec's priority — **curve > left cross
  > right cross > straight > triangle** — and the whole ordered list travels
  with the layer so the client can paint the overlap correctly.
- Front and back necklines are independent; the composer paints only the one
  belonging to the requested `view`.
- Custom uploads live on the design (`custom_images`) and never enter the shared
  library, exactly as the spec requires.
- `WarmPreviewCacheJob` pre-renders popular combinations.

## Compatibility rules

`app/services/compatibility_checker.rb`, driven entirely by the
`compatibility_rules` table — no rules live in code.

| Mode | Effect |
|---|---|
| `block_category` | the whole target category is unselectable (*Halter Neck → sleeves off*) |
| `allow` | if any allow rule exists for (source, category), **only** those targets remain (*High Neck → Full, 3/4*) |
| `block` | otherwise everything except the blocked targets (*High Neck front → no Deep U/V back*) |

Seeded with the examples from the spec; add more through
`/admin/compatibility_rules` without a deploy.

## Python AI service

Lives in [`../tailor_tech_ai`](../tailor_tech_ai). `app/services/ai_client.rb`
talks to `AI_SERVICE_URL`:

| Endpoint | Used by | Returns |
|---|---|---|
| `POST /sketch` | `SketchGenerator` | `image_url` or `image_base64` |
| `POST /tryon` | `VirtualTryonProcessor` | image + `landmarks`, `measurements` |
| `POST /measurements/estimate` | `MeasurementEstimator` | `measurements`, `confidence` |
| `POST /assets/process` | `DesignAssetProcessor` | `front_base64`, `back_base64`, `shadow_base64`, `bounds` |

Either an inline base64 payload or a URL is accepted; `ImageIngestor` normalises
both into an Active Storage attachment so the frontend always receives a stable
CDN link.

**`AI_SERVICE_ENABLED=false` (the default) is a working mode, not a broken one.**
Sketches fall back to the library asset for the chosen silhouette, try-on falls
back to the design's sketch, and admin uploads keep the raw image as the front
layer. Measurement estimation is the one operation with no meaningful fallback:
it returns `503` with a clear message, and the form stays manual. Nothing is
drawn in code — previews are always composed from uploaded assets, per the spec.

With the service running, `/assets/process` and `/measurements/estimate` work
immediately with no API keys (local OpenCV and MediaPipe). `/sketch` and
`/tryon` need `REPLICATE_API_TOKEN` and return `503` until one is set.

### Status codes are a contract

`AiClient::UNAVAILABLE_STATUSES` decides whether a failure degrades gracefully
or surfaces:

| From the AI service | Rails behaviour |
|---|---|
| `503` no provider configured, `504` upstream timeout | `AiClient::Unavailable` → **fall back to library assets** |
| `502` provider reached and failed | `AiClient::RequestFailed` → **surfaces as an error**, not masked |

Both halves must agree. Changing one side alone means either lost user work or
silently swallowed failures.

A sketch fallback needs a published `dress_type` element with an image
attached. The seed data creates the elements but has no image files, so until
you upload assets through the Design Library, `generate_sketch` fails with a
message naming that gap rather than blaming the AI service.

## Design library upload pipeline

```
Upload → extract outer boundary → remove background → transparent asset
       → front / back / shadow layers → assign category → compatibility → publish
```

`POST /admin/design_elements` stores the raw upload and queues
`ProcessDesignAssetJob` on the `assets` Sidekiq queue; `publish` refuses until a
front layer exists.

## Performance

- Redis-cached layer manifests, keyed by design fingerprint
- Only the changed layer is re-rendered client-side
- Active Storage on S3, optionally rewritten onto `CDN_HOST` (CloudFront)
- Pagination headers (`X-Total-Count`, `X-Page`, `X-Per-Page`) on admin and
  locator collections
- Distance search runs as a haversine expression in PostgreSQL — no extra
  geocoding dependency

## Tests

```bash
bundle exec rspec
```

Request specs cover auth, the design library and its compatibility rules, design
CRUD and the preview manifest, and measurement validation.

## Layout

```
app/
  controllers/api/v1/    auth, design_elements, dress_designs, measurements,
                         virtual_tryons, boutique, boutiques, orders, previews
              …/designer customers, customer_measurements, customer_designs
              …/admin    design_elements, compatibility_rules, boutiques, users
  models/                user, design_element, compatibility_rule, dress_design,
                         measurement, virtual_tryon, boutique, order
  services/              layer_composer, compatibility_checker, ai_client,
                         sketch_generator, virtual_tryon_processor,
                         measurement_estimator, design_asset_processor,
                         image_ingestor
  serializers/           plain modules — the JSON shape is explicit, not inferred
  jobs/                  sketch, try-on, asset processing, cache warming
  lib/                   json_web_token, attachment_url
```

## Not built

Ordering exists as an API but has no payment integration; 360° preview, fabric
draping and AR try-on are frontend/AI-service concerns and have no backend
counterpart yet.
#   t a i l o r _ t e c h _ b a c k e n d  
 
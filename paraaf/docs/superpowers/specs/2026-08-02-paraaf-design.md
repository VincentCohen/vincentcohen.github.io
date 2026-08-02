# Paraaf — Design Spec

**Date:** 2026-08-02
**Status:** Approved, ready for implementation planning
**Author:** Vincent Cohen

---

## 1. What this is

Paraaf is a Dutch/EU electronic signature SaaS: upload a PDF, place fields, send it to recipients, collect legally valid signatures, return a cryptographically sealed document.

It is inspired by Documenso but shares **no code** with it. Section 2 explains why that distinction is load-bearing.

**Positioning:** a standalone, general-purpose signing product for the Dutch and EU market. It competes on two things — interface quality and unambiguous Dutch/EU identity.

**Constraints this design is built around:**

- Solo developer, working nights and weekends
- No budget before revenue
- The interface is the primary differentiator

The dominant risk is not architectural. It is that the project never ships. Every decision below favours a stack the author is fluent in and a scope one person can finish.

---

## 2. Licensing analysis

Documenso is the reference product. Two separate licences govern it, and both matter.

### Root `LICENSE` — AGPL-3.0

A common misconception is that AGPL forbids commercial sale. It does not. You may run a paid SaaS on AGPL code. What AGPL requires is that anyone interacting with the server over a network can demand the **complete corresponding source, including every modification, under AGPLv3**.

It does not block revenue. It blocks a proprietary moat.

### `packages/ee/LICENSE` — Documenso Commercial License

Stricter and non-negotiable. That code "may only be used in production" with a paid Documenso Enterprise subscription, and explicitly forbids copying, distribution and sale. It covers Stripe billing, usage limits and CSC cloud signing.

Using it in a product you sell is a licence violation regardless of how the AGPL question is resolved.

### Additional constraints

- `CLA.md` — contributors assign rights to Documenso, Inc.
- The **Documenso name and logo are trademarks**, not licensed under AGPL.

### Decision: clean-room reimplementation

Documenso is used to understand *what* to build, never *how* it is written. Ideas, architecture and data models are not copyrightable; specific code is. Building the same product with independent implementation is legitimate.

**Hygiene rules, binding for the life of the project:**

1. The `documenso/` clone lives outside the Paraaf working tree.
2. No Documenso source file is open while writing an equivalent Paraaf module.
3. Work from public documentation and the running application, not from `.tsx` files.
4. No `Docu-` or `-enso` naming, no Documenso marketing copy.
5. A deliberately different stack (Laravel vs. their Remix/Hono) makes accidental copying structurally impossible.

### What is legitimately reusable

The visual layer is **not** Documenso's invention. Their `packages/ui/primitives/` is shadcn/ui + Radix + Tailwind, unmodified — MIT, installed from upstream. The hard engineering is likewise permissive:

| Need | Library | Licence |
|---|---|---|
| PDF rendering | `pdfjs-dist` | Apache-2.0 |
| PDF manipulation | `pdf-lib` | MIT |
| PAdES signing | `@signpdf` | MIT |
| Certificates / ASN.1 | `pkijs` | MIT |
| UI primitives | `shadcn/ui` + Radix | MIT |

**Not legal advice.** Confirm with a lawyer before commercialising.

---

## 3. Naming

**Paraaf** — Dutch for the initials placed on each page of a contract; `paraferen` is the verb every Dutch professional uses in that context.

Chosen because it is domain-native, has no competing second meaning, is unmistakably Dutch, and survives the border via its Latin root (*paraphe* FR, *Paraphe* DE).

**Rejected:** *Zegel* (means "postage stamp" to most Dutch speakers first), *Krabbel* (too informal for legal buyers, doesn't travel), *Signum* (abandons the Dutch wedge, highest trademark-collision risk).

**Brand decision:** standalone, not a Buddee sub-brand. Keeps it sellable to any industry. Accepted cost: no distribution on day one.

### Pre-launch checklist

- [ ] **BOIP** (`boip.int`) — Benelux trademark register. The governing one. Do this **before** buying domains.
- [ ] **EUIPO** (`euipo.europa.eu`) — classes 9 and 42.
- [ ] Domains: `paraaf.nl`, then `.com` / `.eu`.
- [ ] KvK handelsregister.
- [ ] Confirm no collision with DocuSign, SignRequest, Signhost, ValidSign, Zynyo, Evidos, Signicat, Ondertekenen.nl.

---

## 4. Legal assurance level

**Target: SES + AES** (eIDAS simple and advanced electronic signatures).

AES covers roughly 95% of Dutch commercial contracts, requires no Qualified Trust Service Provider partnership and no eIDAS audit. eIDAS Article 26 requires a signature that is uniquely linked to the signatory, capable of identifying them, created under their sole control, and linked to the data such that tampering is detectable. A cryptographic PAdES signature plus the audit trail satisfies all four.

**QES is explicitly out of scope**, and can be added later via a CSC-API partner (Signicat, InfoCert, D-Trust) as an additional `Sealer` implementation without rearchitecting.

### Certificate strategy

**Launch with a self-signed certificate.** It costs nothing and still produces a legally valid AES — the law does not care who issued the certificate.

What it costs is cosmetic but real: Adobe Acrobat shows a yellow *"signature validity unknown"* banner instead of a green check, because the certificate is not on Adobe's trust list.

**Buy an AATL-member organisational document-signing certificate** (GlobalSign, DigiCert, Sectigo — roughly €300–500/year, with identity vetting against the KvK registration) once there is revenue. Because signing sits behind a `SealerInterface`, this is a config change, not a refactor.

This deliberately moves the certificate from a launch blocker to a month-three expense.

### Signature format

**v1 targets PAdES-B-T** — signature plus RFC-3161 trusted timestamp. This is what the market means by AES.

`@signpdf` produces a valid PAdES-B-B signature easily. Adding the timestamp token (B-T) and DSS/VRI validation data for long-term validity (B-LT) requires assembling CMS structures with `pkijs`. **B-LT is a follow-up, not a launch blocker.**

---

## 5. Stack

```
Laravel 12 (PHP 8.3)  ·  Inertia.js  ·  React 19  ·  TypeScript
Tailwind v4  ·  shadcn/ui (re-themed)
PostgreSQL  ·  Fortify  ·  Cashier  ·  Queues (database driver)  ·  Flysystem → S3
pdf.js (browser)  ·  Node sealing sidecar (pdf-lib + @signpdf + pkijs)
Forge → Hetzner (Falkenstein)
```

### Why Laravel

The author is fluent in PHP and not in Node. For a solo nights-and-weekends build, fluency dominates every other consideration.

Laravel also happens to be ahead on merit here — most of the server layer this design would otherwise hand-roll already ships with the framework:

| Would need building | Laravel provides |
|---|---|
| Job queue with retries and backoff | Queues, `database` driver |
| Storage provider abstraction | `Storage::disk('s3')` via Flysystem |
| Transactional email | Mailables, Resend driver |
| Auth, verification, 2FA | Fortify |
| Stripe subscriptions, invoices, EU VAT | **Cashier** — weeks of work avoided |
| Migrations | Eloquent |

### Why Inertia

Inertia is glue, not a framework: one Composer package, one npm package, a middleware, a root Blade file. Controllers return `Inertia::render('Page', [...])` and the array arrives as React props. Routing stays in `web.php`, auth stays in Laravel middleware, validation stays in form requests — and the frontend is still real React.

It removes the need for a JSON API, API tokens, a client-side router, a data-fetching library and CORS configuration, while still supporting the genuinely stateful screens (field editor, signing page) that Blade would handle badly.

### Why React over Vue

The author has React already running in two Next.js projects. shadcn/ui is React-first (`shadcn-vue` is a community port that trails upstream). Laravel 12 ships an official React starter kit, so the integration is first-class. React also has substantially more learning material and better AI assistance.

### Why a Node sidecar for sealing

PHP has no solid free PAdES library. `setasign/fpdi` needs a **commercial** parser add-on for any PDF newer than v1.4; `mpdf` is **GPL-2.0** and unusable here; the professional option, `setasign/setapdf-signer`, costs roughly €1,500.

Instead: one stateless Node service, one endpoint, `POST /seal`, taking PDF bytes plus field data and returning signed bytes. On localhost, shared-secret authenticated, no database.

This is a standard pattern in the PHP world — structurally identical to how Laravel applications call Gotenberg for PDF generation. Node is already in the toolchain via Vite. PHP never parses a PDF byte, which also keeps FPDI, TCPDF and all GPL code out of the codebase entirely.

Behind `SealerInterface`, so buying SetaPDF later is a single class.

### Hosting

Not Vercel: serverless body-size and execution limits fight large PDF uploads, and the sealing worker needs a persistent process.

- **App:** Hetzner CX22, Falkenstein, deployed via Laravel Forge (~€20/month total). German company — the data-residency claim is airtight rather than "US company with an EU region."
- **Database:** Neon `eu-central-1` (Frankfurt) initially. Neon is US-incorporated; acceptable for commercial buyers, revisit if pursuing government or healthcare.
- **Storage:** Hetzner Object Storage, S3-compatible.

**Total cost to launch: under €25/month.** Nothing upfront.

---

## 6. Architecture

```
app/
  Actions/Documents/    CreateDocument, SendDocument, SignDocument,
                        SealDocument, CancelDocument
  Actions/Templates/    CreateTemplate, InstantiateTemplate
  Models/               User, Document, Recipient, Field, Signature,
                        AuditEvent  (Subscription comes from Cashier)
  Http/Controllers/     Document, Editor, Signing, Template
  Jobs/                 SendSigningInvite, SealDocument, SendCompletedCopies
  Services/Sealing/     SealerInterface, SidecarSealer

sealing-service/        Node: Express + pdf-lib + @signpdf + pkijs
resources/js/Pages/     React pages served via Inertia
```

**All business logic lives in Actions.** Controllers are thin. This is not decoration — it is what makes the public API cheap to add later (Section 12).

---

## 7. Data model

Nine tables, against Documenso's roughly sixty. The difference is entirely organisations, teams, groups, envelopes and folders — all cut.

```
user           id, email, name, password_hash, email_verified_at, created_at
session        (Fortify managed)
document       id, user_id, kind, template_id?, title, status,
               storage_key, sealed_storage_key,
               created_at, sent_at, completed_at
recipient      id, document_id, email?, name, placeholder_label?, role,
               signing_order, token?, status, viewed_at, signed_at
field          id, document_id, recipient_id, type, page,
               x, y, w, h, required, value, inserted_at
signature      id, recipient_id, field_id, kind, image_data | typed_text
audit_event    id, document_id, recipient_id?, type, ip, user_agent,
               metadata jsonb, created_at
job            (Laravel jobs / failed_jobs)
subscription   (Cashier managed)
```

**Enums**

- `document.kind`: `DOCUMENT | TEMPLATE`
- `document.status`: `DRAFT → SENT → PARTIALLY_SIGNED → COMPLETED`, plus `CANCELLED`, `REJECTED`
- `recipient.role`: `SIGNER | VIEWER | CC`
- `field.type`: `SIGNATURE | INITIALS | NAME | EMAIL | DATE | TEXT | CHECKBOX`

### Field coordinates — the central decision

**Coordinates are stored as fractions of page size**: `x, y, w, h` as floats in `[0,1]`, origin top-left, relative to the visually-rotated page box. Not points. Not pixels.

This is what makes the editor tractable. pdf.js renders at some scale *S*; the overlay div is positioned at exactly the canvas dimensions, so a drag to 120px on an 800px-wide canvas is `0.15` — and stays `0.15` at any zoom, on any screen, forever.

At seal time the sidecar converts fraction → PDF user space, flipping the y-axis and applying page rotation.

**Consequence:** the transform lives in the **Node sidecar**, not PHP. PHP only ever stores fractions. The most important tests in the project are therefore Vitest tests in the sidecar (Section 10).

### Templates

A template is a document with `kind = TEMPLATE`, placeholder recipients and no tokens. It deliberately shares tables with documents so the field editor, coordinate model, field CRUD and PDF renderer work on it **unchanged** — no duplicated write path through the hardest component in the app.

**Accepted risk:** every document query must filter on `kind`, or templates leak into the dashboard. Handled once in a data-access helper that requires the caller to state which kind it wants, rather than defaulting.

`InstantiateTemplate(templateId, recipientEmails[])`:

1. Copy the `document` row with `kind = DOCUMENT`, `status = DRAFT`, `template_id` set
2. Copy recipients, substituting real emails for placeholders, minting tokens
3. Copy fields, **remapping each `recipient_id` from old to new** via a lookup built in step 2

Step 3 is the fiddly part and must be unit-tested. Get it wrong and signer B is asked to sign signer A's box.

The uploaded PDF is **shared by reference** — the template's `storage_key` is reused. Templates cost no extra storage.

---

## 8. Document lifecycle

1. **Upload** → S3, document `DRAFT`
2. **Edit** → place fields (fractional coords), add recipients
3. **Send** → mint a 64-char token per recipient, status `SENT`, dispatch `SendSigningInvite` to the first recipient (or all, if signing order is off)
4. **View** → recipient opens `/sign/{token}`, audit event `VIEWED`, Inertia renders the signing page
5. **Submit** → one DB transaction: validate that recipient's required fields, persist values and signature, audit `SIGNED`
6. **Advance** → more recipients pending: invite the next. Otherwise `COMPLETED`, dispatch `SealDocument`
7. **Seal** → fetch original from S3 → POST to sidecar → pdf-lib draws values and signature images, appends the audit page, `@signpdf` signs with the P12, RFC-3161 timestamp applied → sealed bytes stored as a **new** object → `SendCompletedCopies`

**Key property: sealing is decoupled from completion.** Signatures are durable in the database before sealing runs, so a sealing failure is a retry, never data loss.

**Idempotency:** `SealDocument` takes `Cache::lock("seal:{$id}")` and returns early if `sealed_storage_key` is set. Running it twice produces one sealed PDF.

---

## 9. Error handling

- **Queue:** 5 tries, exponential backoff, `failed_jobs` plus a Sentry alert. Completed-but-unsealed documents surface in an internal list.
- **Never mutate the original.** Sealed output is always a new S3 object.
- **Uploads:** magic-bytes check (`%PDF-`), 25 MB cap, reject password-protected PDFs with a clear message, reject already-signed PDFs in v1.
- **Tokens:** 64-char random, rate-limited per IP on `/sign/{token}`, every access written to the audit log.
- **Email delivery is the silent failure mode.** A signing invite in a spam folder is a dead document the sender never learns about. Resend webhooks mark recipients `delivery_failed` and surface it in the sender's dashboard. **Not optional.**
- **Concurrency:** row-lock the document during status transitions, so two simultaneous signers cannot both believe they are last.
- **Sidecar unavailable:** job retries with backoff. It runs on localhost, so failure means the host is down regardless.

---

## 10. Testing

**Vitest (sealing sidecar)** — the highest-value tests in the project:

- Fraction → PDF user space across **all four page rotations** and mixed page sizes
- Field and signature-image drawing
- Sealed output parses and the signature validates

**Pest (Laravel):**

- Document lifecycle state machine
- Signing-order progression
- **Template instantiation recipient remapping**
- Authorization — recipient A must never see or submit B's fields
- Job idempotency: seal twice, get one output

**Playwright (E2E):**

- Upload → place field → send → open token link → sign → download sealed PDF

**Manual, every release:**

- Open the sealed PDF in Adobe Acrobat. Confirm the signature panel reports a valid signature over an unmodified document.

That last one is the acceptance test that actually decides whether there is a product. Automate what is automatable, but eyeball this one every time.

---

## 11. Design system

shadcn/ui provides the primitives — accessibility, keyboard handling, focus management. **The theme layered on top is entirely Paraaf's.** Default shadcn is the house style of every SaaS shipped since 2024; adopting it unchanged would mean visual parity with Documenso, which defeats the premise of leading with interface quality.

### Direction: Notarieel

Editorial and document-like. Looks like a well-set legal document rather than a dashboard — a position no competitor occupies. DocuSign is corporate blue; Documenso is developer dark-mode.

| Token | Value |
|---|---|
| Display type | Instrument Serif |
| Body type | IBM Plex Sans |
| Paper | `#FAF6EF` |
| Surface | `#F1EADE` |
| Accent (wax seal) | `#7A2E2E` |
| Ink | `#17130E` |

### Editor: document-forward

A slim top bar carries step progress. The PDF fills the canvas on a cream backdrop, floating like real paper. The field palette is a floating dock at the bottom; recipients and field settings slide in as a right drawer only when needed.

**Accepted risk:** the floating dock has a discoverability cost — a first-time sender may not spot where fields come from. Mitigated with a first-run hint.

### Signing page: document-first, focused signature sheet

The single highest-leverage surface in the product. Every document a customer sends puts this screen in front of recipients at other companies — people who did not choose Paraaf. It is a built-in acquisition channel, and the one place DocuSign is genuinely weak: pinch-zooming a PDF on a phone to hunt for a signature box.

- The real document scrolls, fields highlighted in place
- A persistent bottom bar shows progress and a **Volgende veld** button that scrolls and zooms to the next field
- Tapping a signature field opens a **full-width focused sheet** with the signature pad, not a cramped inline box

Keeping the real document on screen is what makes the signature defensible in a dispute — the first thing a Dutch buyer's jurist will ask about. The focused sheet recovers the three-tap feel without weakening that.

### Binding requirements

1. **Mobile-first signing.** Designed on a phone before a desktop.
2. **Dutch-first copy.** Written in Dutch, not translated from English.
3. **Motion over spinners.** Optimistic UI wherever the operation can fail safely.
4. **No default shadcn tokens** in shipped screens.

### Interaction quality in the editor

The trial "wow" moment, and where DocuSign is beatable: snapping and alignment guides, keyboard nudge, multi-select, duplicate-to-all-pages, undo.

The **dashboard is a table.** Nobody buys software because of a table. Keep it clean, invest nothing further.

---

## 12. Scope

### In v1

Email/password auth · upload PDF · drag-place fields (signature, initials, name, email, date, text, checkbox) · recipients with roles and signing order · templates (create, edit, list, instantiate) · email invites with tokenised links · document-first mobile signing page · flatten and seal with PAdES-B-T · audit-trail appendix · document dashboard · Stripe via Cashier.

### Explicitly out of v1

Organisations, teams, groups · SSO · passkeys · folders · multi-document envelopes · bulk send from CSV · public template direct links · public API · webhooks · admin panel · custom email domains · white-label branding · i18n beyond Dutch and English · QES.

Documenso ships all of these. None are needed to take money for a signed contract.

### Public API — architected for, not built

Documenso runs three API layers: `/api/v1` and `/api/v2` for customers, and a separate internal layer for its own frontend. It deliberately does not serve its own UI from its public API — and that is the right pattern.

The UI needs roughly sixty endpoints; customers need about ten. Serving the UI from a versioned public contract means every screen tweak forces a version bump or leaks UI concerns into a customer-facing API.

So: **write every use case as an Action from day one.** When the first customer asks for the API, `routes/api.php` plus thin Sanctum-authenticated controllers is a couple of weekends, not a rewrite.

---

## 13. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Project never ships (solo, part-time, widest positioning) | **High** | Ruthless v1 scope. Consider Buddee's customer base as beachhead despite the standalone brand. |
| Coordinate transform bugs | High | Isolated pure module in the sidecar, exhaustively unit-tested across all rotations. |
| PAdES timestamping harder than expected | Medium | v1 targets B-T; B-LT deferred. Fall back to SetaPDF (€1,500) if the sidecar stalls. |
| Signing invites landing in spam | Medium | Resend webhooks, delivery status surfaced to sender, SPF/DKIM/DMARC configured at launch. |
| UI advantage is copyable | Medium | Pair with structural differentiation: EU residency, Dutch product and support, iDIN, Dutch-legible invoicing. |
| Trademark collision | Medium | BOIP and EUIPO searches before any domain purchase. |
| Field editor takes longer than estimated | Medium | It is the one genuinely hard component. Budget 2–3 weekends and protect that time. |

---

## 14. Effort estimate

Solo, nights and weekends, roughly 10–15 hours per week.

| Area | Estimate |
|---|---|
| Laravel scaffolding, auth, models, migrations | 1–2 weekends |
| PDF viewer (pdf.js) | ~1 weekend |
| **Field overlay — drag, drop, resize, select** | **2–3 weekends** |
| Field palette, settings, recipient editor | 1–2 weekends |
| Signature pad (`signature_pad`, MIT) | hours |
| Signing page, mobile-first | 1–2 weekends |
| Sealing sidecar + PAdES-B-T | 2–3 weekends |
| Templates | 1–2 weekends |
| Billing (Cashier), email, dashboard | 1–2 weekends |
| Design system, polish, Dutch copy | 2–3 weekends |

**Roughly 3–4 months to something sellable.**

---

## 15. Open questions

1. **Distribution.** The standalone brand starts cold. Is Buddee's customer base the beachhead, and if so, when?
2. **Pricing.** Per-user, per-document, or flat? Not required for the build, required before launch.
3. **iDIN identity verification** — a genuine Dutch differentiator for AES. Post-v1, but worth validating demand early.
4. **Neon vs. self-hosted Postgres.** Fine for commercial buyers; revisit before pursuing government or healthcare.

# Spec — Standar penulisan output brainstorm & plan

**Ticket:** IDS-1
**Date:** 2026-08-20
**Status:** design approved, awaiting plan

## Problem

Tiga konvensi output gaspol tidak seragam dan tidak sinkron dengan standar global
operator di `~/.claude/CLAUDE.md`:

1. **Nama spec/plan tanpa tanggal.** Sekarang `docs/plans/<TICKET>-<topic>-spec.md`.
   Standar global mewajibkan `YYYY-MM-DD-<TICKET>-<topic>-spec.md` ("TANGGAL DI DEPAN,
   selalu"). Tanpa tanggal, `docs/plans/` tidak terurut kronologis dan file lama
   (yang justru berformat tanggal) bercampur dengan file baru berformat ticket.

2. **Ledger progress tidak dijamin ada.** `gaspol-execute` baru membuatnya di Step 3,
   saat eksekusi mulai. Plan yang ditulis lalu ditinggal tidak meninggalkan jejak apa
   pun. Nama filenya juga `progress-<TICKET>.md` (huruf kecil), bukan
   `PROGRESS-<TICKET>.md`.

3. **Ledger tidak punya checklist fase.** Isinya murni baris log append-only. Status
   keseluruhan ("fase mana yang sudah beres") harus disimpulkan dengan membaca seluruh
   log — tidak bisa dilihat sekilas oleh manusia.

4. **Perintah verifikasi di-hardcode ke npm/TypeScript.** `gaspol-verify` Layer 1
   memerintahkan `npm run build` (L56), `npx tsc --noEmit` (L64), `npm test` (L72),
   `npm run lint` (L82). Nol `pytest`, nol `php artisan`, nol `go test`, nol
   `cargo test`. Validation Ladder di `gaspol-parallel` L198 juga menyebut
   `tsc --noEmit` secara harfiah.

   Akibatnya di project non-JS (Laravel, Python, Go, Flutter) gate verifikasi
   memerintahkan perintah yang **tidak ada di project itu** — executor lalu
   berimprovisasi. Improvisasi di gate verifikasi persis tempat klaim "done" berubah
   jadi bohong (langgar Iron Law 3).

## Non-goals

- **Tidak menambah lapisan PRD.** Sudah dipertimbangkan dan ditolak eksplisit
  (2026-08-20). gaspol tetap murni dokumen engineering: `-spec.md` = RFC/design doc,
  `-plan.md` = implementation plan. Success metrics / user stories / release criteria
  tetap tidak diproduksi gaspol.
- **Tidak mengubah semantik resume.** Handoff cursor `— NEXT: <aksi>` tidak berubah, dan
  aturan aktif/selesai di `scan-active-ledgers` tidak berubah — satu-satunya perubahan di
  script itu adalah glob-nya diperluas agar menangkap nama huruf besar.
- **Tidak mengubah alur skill.** Rantai brainstorm → plan → execute → verify → finish
  tidak disentuh; hanya nama file, isi ledger, dan asal-usul perintah verifikasi.
- **Tidak menambah taksonomi layer (frontend / backend / integration).** Sudah
  dipertimbangkan dan ditolak (2026-08-20). gaspol sudah mendiferensiasi lewat **trigger
  kapabilitas**, bukan label layer: ekstensi `.tsx/.jsx/.vue/.svelte/.astro/.css` →
  `gaspol-design` + kolom Design Deliverable + verify Layer 4; auth/secrets/input/
  upload/endpoint/payment → `gaspol-security-review`; fitur LLM non-deterministik →
  `gaspol-eval`; `files` + token `db:<name>` → lane DAG terisolasi. Menandai sebuah fase
  "frontend" tidak mengubah satu pun perilaku — gate-nya menyala dari ekstensi file, bukan
  dari label. Yang benar-benar berbeda antar layer adalah **perintah pembuktinya**, dan
  itu masalah *stack*, bukan masalah *layer* — ditangani §4.
- **Tidak menebak perintah.** Kalau stack tak terdeteksi, jangan karang perintah yang
  masuk akal — STOP dan tanya. Mengganti improvisasi executor dengan improvisasi script
  tidak memperbaiki apa pun.

## Design

### 1. Konvensi nama file

```text
docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-spec.md    ← gaspol-brainstorm
docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md    ← gaspol-plan
.gaspol/progress/PROGRESS-<TICKET>.md                    ← gaspol-plan bikin, execute centang
```

`YYYY-MM-DD` = tanggal file itu **dibuat**, bukan tanggal tiket dimint. Konsekuensinya
plan boleh bertanggal beda dari spec-nya (ditulis besoknya, misal).

**Karena itu lookup spec dari plan WAJIB pakai glob, bukan tebak tanggal:**

```text
docs/plans/*-<TICKET>-*-spec.md
```

Kalau glob menemukan >1 file, itu error konfigurasi (dua spec satu ticket) — STOP dan
tanya user, jangan pilih sendiri.

Direktori ledger tetap huruf kecil (`.gaspol/progress/`), nama filenya huruf besar
(`PROGRESS-<TICKET>.md`) sesuai permintaan operator.

### 2. Format ledger

```markdown
# PROGRESS — IDS-1: gaspol output naming standard

**Ticket:** IDS-1
**Plan:** docs/plans/2026-08-20-IDS-1-gaspol-output-naming-standard-plan.md

## Checklist
- [x] Phase A: konvensi nama spec/plan — DONE
- [>] Phase B: ledger PROGRESS-<TICKET>.md — DOING
- [ ] Phase C: gate checklist di execute/parallel
- [~] Phase D: migrasi file lama — DIBATALKAN (YAGNI, alasan di Log)

## Log
- 2026-08-20 Phase A done — `bash tests/skill-triggering/run-all.sh` → 22/22 pass — NEXT: Phase B
```

**Empat state checklist:**

| Marker | Arti | Syarat |
|--------|------|--------|
| `[ ]`  | todo | — |
| `[>]`  | sedang dikerjakan | diset saat fase mulai |
| `[x]`  | selesai | tes fase itu hijau |
| `[~]`  | dibatalkan / dilewati | **wajib** alasan singkat di baris itu + rincian di Log |

**Pembagian peran dua blok:**

- `## Checklist` — state ringkas, untuk **manusia**. Dilihat sekilas.
- `## Log` — append-only, untuk **mesin**. Baris non-kosong terakhirnya membawa handoff
  cursor `— NEXT:` yang dibaca `gaspol-execute` untuk resume pasca-`/compact`, dan yang
  dibaca `scan-active-ledgers` untuk menentukan ledger masih aktif atau tidak.

Karena `## Log` selalu blok terakhir, baris non-kosong terakhir file selalu baris log —
`scan-active-ledgers` tidak perlu diubah logikanya, **hanya glob-nya** (lihat tabel
"File yang disentuh").

**Gate baru (BLOCKING, setara test gate):** selesai satu fase → centang checklist **dan**
tulis baris Log, **sebelum** fase berikutnya dimulai. Membatch semua update di akhir =
pelanggaran; crash di tengah harus meninggalkan cursor jujur, bukan status basi.

### 3. Pembuat ledger

`gaspol-plan` yang membuat `PROGRESS-<TICKET>.md` **saat plan ditulis**, lengkap dengan
blok `## Checklist` berisi seluruh nama fase dalam keadaan `[ ]`, plus satu baris Log
awal bercursor `— NEXT: Phase A`.

Alasannya: di titik itu nama fase sudah pasti. Execute tinggal mencentang, tidak perlu
menurunkan daftar fase sendiri.

Efek samping yang diterima sadar: plan yang ditulis lalu tidak pernah dieksekusi akan
muncul sebagai kerja aktif di `scan-active-ledgers`. Itu jujur — memang ada kerja
tertunda — dan `gaspol-execute` Step 0 sudah punya modal 4-opsi untuk menanganinya.

### 4. Perintah verifikasi diturunkan dari stack, bukan di-hardcode

Script baru `skills/gaspol-execute/scripts/detect-stack` (bash, stdlib, `--self-test`,
sepola dengan `next-ticket` / `scan-active-ledgers` yang sudah ada).

**Kontrak:**

```text
detect-stack <project-root>

stdout   satu baris per level, format "<level>: <perintah>"
         level ∈ static | lint | unit | build
exit 0   selalu, pada scan normal
exit 1   usage error (arg hilang / direktori tak ada)
```

**Deteksi lewat file penanda:**

| Penanda | Stack | static | lint | unit | build |
|---------|-------|--------|------|------|-------|
| `package.json` + `tsconfig.json` | Node/TS | `npx tsc --noEmit` | `npm run lint` | `npm test` | `npm run build` |
| `composer.json` | PHP/Laravel | `./vendor/bin/phpstan analyse` | `./vendor/bin/pint --test` | `php artisan test` | — |
| `pyproject.toml` / `requirements.txt` | Python | `mypy .` | `ruff check .` | `pytest` | — |
| `go.mod` | Go | `go vet ./...` | — | `go test ./...` | `go build ./...` |
| `Cargo.toml` | Rust | `cargo check` | `cargo clippy` | `cargo test` | `cargo build` |
| `pubspec.yaml` | Dart/Flutter | `dart analyze` | — | `flutter test` | `flutter build` |

**Aturan anti-karang (inti dari perubahan ini):** sebuah perintah hanya dicetak kalau
penopangnya benar-benar ada — key `"build"` ada di `scripts` package.json, binary ada di
`vendor/bin/`, `tsconfig.json` ada. Kalau penanda stack ketemu tapi penopang perintahnya
tidak, cetak:

```text
unit: UNKNOWN
```

`UNKNOWN` bukan "lewati". Skill yang membacanya **STOP dan tanya user** perintah apa yang
benar — persis seperti Data Integration Map memperlakukan sumber data yang tidak ada.

**Monorepo / poliglot:** lebih dari satu penanda ketemu → cetak semua baris, tiap baris
diberi awalan stack (`node/static: …`, `php/unit: …`). Semua yang berlaku dijalankan;
tidak ada yang dipilih diam-diam.

**Yang memakai:**

- `gaspol-verify` Layer 1 — jalankan hasil `detect-stack`, bukan blok npm hardcoded.
- `gaspol-parallel` Validation Ladder L1/L2/L3 — sumber perintah yang sama.
- `gaspol-plan` — jalankan `detect-stack` saat plan ditulis, tulis perintah hasilnya
  **verbatim** ke blok `Verification` tiap fase. Ini menjaga aturan self-contained: plan
  harus bisa dieksekusi agent tanpa konteks lain, jadi perintahnya ada di plan, bukan
  cuma di script.

Live App Check (verify L95) tetap seperti sekarang — ia menyala dari "UI/user-visible",
bukan dari stack.

## Data Integration Map

| Komponen | Sumber data | Ada? | Aksi |
|----------|-------------|------|------|
| Nomor ticket | `skills/gaspol-execute/scripts/next-ticket` + `## gaspol Ticket Counter` di CLAUDE.md target | Ya | Pakai apa adanya |
| Deteksi ledger aktif | `skills/gaspol-execute/scripts/scan-active-ledgers` | Ya | Ubah glob → case-insensitive |
| Resume cursor | baris `— NEXT:` terakhir di `## Log` | Ya | Tak berubah |
| Daftar fase untuk checklist | heading `### Phase X:` di plan file | Ya | Turunkan saat plan ditulis |
| Tanggal file | tanggal hari ini | Ya | — |
| Perintah verifikasi per stack | file penanda di root project (`package.json`, `composer.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pubspec.yaml`) | Ya (file-nya), **Tidak** (script pembacanya) | Buat `scripts/detect-stack` |
| Penopang perintah | key `scripts` di package.json, isi `vendor/bin/`, ada `tsconfig.json` | Ya | Baca, jangan asumsikan |

Nol dependensi baru. Nol layanan baru. Satu script bash stdlib (`detect-stack`) —
sepola dengan dua script yang sudah ada di direktori yang sama.

## File yang disentuh

| Area | File | Perubahan |
|------|------|-----------|
| Nama spec | `skills/gaspol-brainstorm/SKILL.md` (~L323) | tambah prefix tanggal |
| Nama plan, lookup spec via glob, header, skeleton ledger | `skills/gaspol-plan/SKILL.md` (L48-L98, L298) | prefix tanggal, glob lookup, path ledger huruf besar, instruksi tulis Checklist |
| Resolusi ledger + centang per-fase | `skills/gaspol-execute/SKILL.md` (L53, L101-102, L242, L288) | path baru, gate centang checklist |
| Template checkpoint | `skills/gaspol-execute/checkpoint-template.md` (L72) | tambah langkah centang |
| Centang per-task | `skills/gaspol-parallel/SKILL.md` (L363-364, L382) | path baru + centang |
| Glob ledger | `skills/gaspol-execute/scripts/scan-active-ledgers` (L45) | `shopt -s nocaseglob` agar `PROGRESS-*.md` kena di FS case-sensitive |
| Tes glob | `tests/ticket-scripts/test-scan-active-ledgers.sh` | kasus baru: fixture huruf besar (RED dulu) |
| Path plan | `agents/plan-verifier.md` (L23), `skills/gaspol-finish/SKILL.md` (L56) | contoh path |
| Path plan (usang) | `skills/gaspol-verify/plan-verification.md` (L10-12, L63, L271), `skills/gaspol-verify/SKILL.md` (L151) | masih `YYYY-MM-DD-feature-name.md` tanpa ticket — samakan |
| Dokumentasi | `CLAUDE.md` (L321-322, L449, L519) | konvensi + format ledger |
| **Deteksi stack (baru)** | `skills/gaspol-execute/scripts/detect-stack` | script baru + `--self-test` |
| **Tes deteksi stack (baru)** | `tests/ticket-scripts/test-detect-stack.sh` | fixture per stack + kasus `UNKNOWN` (RED dulu) |
| Layer 1 verifikasi | `skills/gaspol-verify/SKILL.md` (L52-L82) | ganti blok npm hardcoded → jalankan `detect-stack` |
| Validation Ladder L1-L3 | `skills/gaspol-parallel/SKILL.md` (L196-L202) | L1 jangan sebut `tsc --noEmit` harfiah — ambil dari `detect-stack` |
| Blok Verification per fase | `skills/gaspol-plan/SKILL.md` (bagian Phase Structure) | tulis perintah hasil `detect-stack` verbatim ke tiap fase |
| Prompt implementer | `skills/gaspol-execute/implementer-prompt.md` | sertakan perintah ladder verbatim (subagent tak bisa baca script) |
| Dokumentasi rubrik | `docs/rubric-model-switching.md` | — (di luar cakupan IDS-1, lihat Open questions) |

## Migrasi

**Tujuh file lama di `docs/plans/` dibiarkan apa adanya.** Semuanya lahir sebelum
ticket-minting ada, jadi tidak punya nomor tiket untuk disisipkan. Menyeragamkannya
berarti mengarang tiket yang tidak pernah ada di counter — data palsu di nama file.

Konsekuensi: skill yang mencari plan/spec harus tahan terhadap **dua pola** (lama tanpa
ticket, baru dengan ticket). Glob `*-<TICKET>-*-spec.md` otomatis aman — file lama tidak
punya ticket sehingga tidak pernah cocok.

Ledger lama (`progress-<TICKET>.md` huruf kecil) juga dibiarkan; isinya sementara dan
`nocaseglob` tetap menangkapnya.

## Verification

| Klaim | Perintah pembukti |
|-------|-------------------|
| Glob case-insensitive jalan | `bash tests/ticket-scripts/test-scan-active-ledgers.sh` |
| Script sehat | `bash skills/gaspol-execute/scripts/scan-active-ledgers --self-test` |
| Skill masih ter-trigger | `bash tests/skill-triggering/run-all.sh` |
| Skill rigid masih tahan tekanan | `bash tests/pressure/run-all.sh` |
| Tak ada sisa path lama | `grep -rn "progress/progress-" skills/ agents/ CLAUDE.md` → kosong |
| Tak ada contoh nama tanpa tanggal | `grep -rnE "docs/plans/<TICKET>" skills/ agents/ CLAUDE.md` → kosong |
| Deteksi stack benar per stack | `bash tests/ticket-scripts/test-detect-stack.sh` |
| Script deteksi sehat | `bash skills/gaspol-execute/scripts/detect-stack --self-test` |
| Deteksi jujur di repo ini | `bash skills/gaspol-execute/scripts/detect-stack .` → tak ada `npm run build` palsu (repo ini nol `package.json`) |
| Tak ada perintah verifikasi hardcoded lagi | `grep -rn "npm run build\|npx tsc --noEmit" skills/gaspol-verify/SKILL.md skills/gaspol-parallel/SKILL.md` → hanya muncul sebagai *contoh keluaran* `detect-stack`, bukan perintah wajib |

## Open questions

Prefix repo ini `IDS` (INDUSIA), counter dimulai dari `IDS-1` — sengaja dipisah dari
`IND` yang dipakai repo indusia-ai-logistics, jadi tidak ada tumpang tindih nomor
antar repo.

**Di luar cakupan IDS-1, dicatat agar tidak hilang** (temuan 2026-08-20):
`docs/rubric-model-switching.md` menyebut versi basi — `opus (4.7)`, `sonnet (4.6)`,
`haiku (4.5)` — padahal keluarga model sekarang Claude 5. Selain itu `gaspol-brainstorm`
dan `gaspol-plan`, dua skill yang paling berat penalarannya, **tidak punya baris rubrik
sama sekali** (keduanya jalan di sesi utama, ikut `/model` aktif). Perlu ticket sendiri.

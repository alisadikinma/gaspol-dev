> **For Claude:** REQUIRED SKILL: Use gaspol-execute to implement this plan.
> **CRITICAL:** This plan specifies real integrations. During execution,
> NEVER substitute placeholders for real data sources without explicit
> user approval. If a data source doesn't exist yet, STOP and ask.
> **Progress ledger — HARD PER-PHASE GATE:** `.gaspol/progress/PROGRESS-IDS-1.md`. After EACH phase and **BEFORE** starting the next, STOP and do BOTH: (a) tick that phase's line in the `## Checklist` block, (b) append a line to the `## Log` block ending with the handoff cursor `— NEXT: <next phase, or DONE>`. This is **blocking**, like a test gate: no next phase until both are written. **Never batch updates at the end** — a crash mid-run must leave a truthful cursor, not a stale state. Update ONLY this file.
> **Self-contained:** this plan is the COMPLETE spec. It must be executable by an agent with **no other context** — a fresh post-`/compact` session, or an external executor in a separate process that cannot see this chat. Every file path, contract, and convention it needs is written here **verbatim**, not merely referenced.

**Ticket:** IDS-1
**Ledger:** .gaspol/progress/PROGRESS-IDS-1.md
**Spec:** docs/plans/2026-08-20-IDS-1-gaspol-output-naming-standard-spec.md

## Goal

Seragamkan tiga konvensi output gaspol dan hilangkan satu lubang kejujuran di gate
verifikasi. (1) Nama spec/plan dapat prefix tanggal `YYYY-MM-DD-<TICKET>-<topic>-{spec,plan}.md`
agar `docs/plans/` terurut kronologis dan sinkron dengan standar global operator. (2) Ledger
progress pindah ke `.gaspol/progress/PROGRESS-<TICKET>.md`, dijamin ada sejak plan ditulis,
dan berisi blok `## Checklist` per-fase yang dicentang tiap fase selesai. (3) Perintah
verifikasi berhenti di-hardcode ke npm/TypeScript — diturunkan dari file penanda stack lewat
script baru `detect-stack`, dengan aturan tegas: kalau tak terdeteksi, cetak `UNKNOWN` dan
STOP, jangan karang perintah.

Nomor 3 adalah yang paling berbahaya kalau dibiarkan: di project non-JS, `gaspol-verify`
Layer 1 sekarang memerintahkan `npm run build` / `npx tsc --noEmit` / `npm test` yang tidak
ada di project itu, sehingga executor berimprovisasi tepat di titik klaim "done" dibuat —
pelanggaran Iron Law 3 (no completion claim without evidence).

## Architecture Context

Repo ini adalah **plugin Claude Code berbasis markdown**, bukan aplikasi. Tidak ada
`package.json`, tidak ada `tsconfig.json`, tidak ada build step. Konsekuensi penting untuk
plan ini: "tes" di repo ini adalah **script bash mandiri**, dan `detect-stack` yang dibuat
di Phase A akan mencetak **nol baris** kalau dijalankan di repo ini sendiri — itu perilaku
yang benar dan diuji eksplisit.

Yang sudah ada dan dipakai ulang (jangan buat baru):

| Aset | Path | Peran |
|------|------|-------|
| Mint ticket | `skills/gaspol-execute/scripts/next-ticket` | baca `## gaspol Ticket Counter` di CLAUDE.md, naikkan `Last ticket:`, cetak id baru |
| Scan ledger aktif | `skills/gaspol-execute/scripts/scan-active-ledgers` | glob `progress-*.md`, cetak yang baris non-kosong terakhirnya tidak berakhir `NEXT: DONE` |
| Pola tes script | `tests/ticket-scripts/test-next-ticket.sh`, `tests/ticket-scripts/test-scan-active-ledgers.sh` | bash `set -euo pipefail`, fixture `mktemp -d`, `trap ... EXIT` |
| Tes trigger skill | `tests/skill-triggering/run-all.sh` | prompt niat naif harus memicu skill yang benar |
| Tes tekanan | `tests/pressure/run-all.sh` | skill rigid harus tahan rasionalisasi |
| Counter ticket repo ini | `CLAUDE.md` baris ~695 | `Prefix: IDS`, `Last ticket: IDS-1` |

Konvensi ledger yang BERLAKU SEKARANG (yang plan ini ubah): `.gaspol/progress/<slug>.md`
per-plan, fallback ke `.gaspol/progress.md` bersama. Baris ledger berakhir dengan handoff
cursor `— NEXT: <aksi>` atau `— WIP — <selesai sejauh ini> — BLOCKER: <yang mentok> — NEXT: <aksi resume persis>`.
`.gaspol/` sudah ada di `.gitignore` (baris terakhir kedua) — ledger tidak pernah ter-commit.

## Tech Stack

Bash 3.2+ (bawaan macOS, `/bin/bash`) — stdlib saja, nol dependensi. Markdown untuk semua
SKILL.md. Tidak ada package manager, tidak ada build, tidak ada CI di repo ini.

Semua script baru mengikuti kontrak yang sama dengan dua script yang sudah ada:
`#!/usr/bin/env bash`, `set -euo pipefail`, fungsi `usage()` ke stderr, flag `--self-test`,
exit 1 untuk usage error.

## Data Integration Map

| Kebutuhan | Sumber data | Ada? | Aksi |
|-----------|-------------|------|------|
| Nomor ticket | `## gaspol Ticket Counter` di CLAUDE.md + `scripts/next-ticket` | Ya | Pakai apa adanya |
| Deteksi ledger aktif | `scripts/scan-active-ledgers` | Ya | Perluas glob → case-insensitive |
| Resume cursor | baris `— NEXT:` terakhir di blok `## Log` | Ya | Semantik tak berubah |
| Daftar fase untuk checklist | heading `### Phase X:` di plan file ini | Ya | Diturunkan saat plan ditulis |
| Perintah verifikasi per stack | file penanda root (`package.json`, `composer.json`, `pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pubspec.yaml`) | Ya (file-nya) / **Tidak** (pembacanya) | Buat `scripts/detect-stack` |
| Penopang tiap perintah | key `scripts` di package.json, isi `vendor/bin/`, ada `tsconfig.json` | Ya | **Baca, jangan asumsikan** |

Kontrak anti-placeholder untuk plan ini: `detect-stack` **tidak boleh** mencetak perintah
yang penopangnya tak terbukti ada. Mencetak `npm run build` padahal `package.json` tak punya
key `"build"` adalah placeholder — sama kelasnya dengan `const data = []`.

## Phases

### Phase A: script `detect-stack`

**Estimated time:** 15 menit

**Files:**
- Create: `skills/gaspol-execute/scripts/detect-stack`
- Test: `tests/ticket-scripts/test-detect-stack.sh`

**Kontrak yang harus dipenuhi (verbatim):**

```text
detect-stack <project-root>
detect-stack --self-test

stdout   nol atau lebih baris, format "<level>: <perintah>"
         level ∈ static | lint | unit | build
         nol penanda ketemu → nol baris (BUKAN error)
exit 0   selalu, pada scan normal
exit 1   usage error (arg hilang / direktori tak ada)
```

Tabel deteksi (penanda di root → perintah):

| Penanda | static | lint | unit | build |
|---------|--------|------|------|-------|
| `package.json` + `tsconfig.json` | `npx tsc --noEmit` | `npm run lint` | `npm test` | `npm run build` |
| `composer.json` | `./vendor/bin/phpstan analyse` | `./vendor/bin/pint --test` | `php artisan test` | — |
| `pyproject.toml` atau `requirements.txt` | `mypy .` | `ruff check .` | `pytest` | — |
| `go.mod` | `go vet ./...` | — | `go test ./...` | `go build ./...` |
| `Cargo.toml` | `cargo check` | `cargo clippy` | `cargo test` | `cargo build` |
| `pubspec.yaml` | `dart analyze` | — | `flutter test` | `flutter build` |

Aturan penopang (INTI dari phase ini):
- Baris `npm *` hanya dicetak kalau key-nya benar-benar ada di `.scripts` package.json
  (`npm test` butuh key `"test"`, dst). `npx tsc --noEmit` butuh `tsconfig.json` ada.
- Baris `./vendor/bin/*` hanya dicetak kalau file binary-nya ada.
- Penanda stack ketemu TAPI penopang perintahnya tidak → cetak `<level>: UNKNOWN`.
- Lebih dari satu penanda ketemu (monorepo/poliglot) → cetak semua, tiap baris diberi
  awalan stack: `node/static: …`, `php/unit: …`.

**Steps:**
1. Write failing test for `detect-stack` printing `unit: npm test` for a fixture dir containing a `package.json` whose `.scripts.test` exists. Expected error: `bash: .../detect-stack: No such file or directory` (exit 127).
2. Run `bash tests/ticket-scripts/test-detect-stack.sh`, confirm it fails for that reason (bukan error sintaks di test-nya sendiri)
3. Implement `skills/gaspol-execute/scripts/detect-stack` per kontrak di atas; `chmod +x`
4. Extend the test with the remaining cases: `tsconfig.json` absent → no `static:` line; `package.json` without `.scripts.build` → `build: UNKNOWN`; empty dir → zero lines exit 0; `go.mod` fixture → 3 lines; monorepo fixture (`package.json` + `composer.json`) → prefixed lines
5. Add a `--self-test` branch mirroring `scan-active-ledgers`'s, covering the empty-dir and UNKNOWN cases
6. Run `bash tests/ticket-scripts/test-detect-stack.sh` and `bash skills/gaspol-execute/scripts/detect-stack --self-test`, confirm both pass
7. Commit: "feat(execute): detect-stack — derive verification commands from stack markers"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-detect-stack.sh` exit 0
- [ ] `bash skills/gaspol-execute/scripts/detect-stack --self-test` exit 0
- [ ] `bash skills/gaspol-execute/scripts/detect-stack .` prints **zero lines**, exit 0 (repo ini nol penanda — bukti script tidak mengarang)
- [ ] `bash -n skills/gaspol-execute/scripts/detect-stack` (syntax check) exit 0
- [ ] Nol komentar TODO/FIXME di script baru

---

### Phase B: glob ledger case-insensitive di `scan-active-ledgers`

**Estimated time:** 8 menit

**Files:**
- Modify: `skills/gaspol-execute/scripts/scan-active-ledgers`
- Modify: `tests/ticket-scripts/test-scan-active-ledgers.sh`

**Konteks:** fungsi `scan_dir()` sekarang berisi `shopt -s nullglob` lalu
`for file in "$dir"/progress-*.md`. Nama ledger baru huruf besar (`PROGRESS-IDS-1.md`),
dan di filesystem case-sensitive (Linux, CI) glob huruf kecil tidak akan menangkapnya.

**Steps:**
1. Write failing test for `scan-active-ledgers` listing an active ledger named `PROGRESS-IDS-1.md` (uppercase). Expected error: assertion fails — stdout kosong karena glob `progress-*.md` tidak cocok di FS case-sensitive.
2. Run `bash tests/ticket-scripts/test-scan-active-ledgers.sh`, confirm the new case fails

   **Sudah dibuktikan live 2026-08-20 di macOS/APFS** — jangan ragukan reproduksinya:
   dengan `.gaspol/progress/PROGRESS-IDS-1.md` ada dan aktif (baris terakhir
   `— NEXT: Phase A`), `bash skills/gaspol-execute/scripts/scan-active-ledgers .gaspol/progress`
   mencetak **nol baris**, exit 0. Bash mencocokkan glob sendiri secara case-sensitive,
   tak peduli filesystem-nya case-insensitive — jadi ini BUKAN bug yang cuma muncul di
   Linux/CI.
3. Change `shopt -s nullglob` to `shopt -s nullglob nocaseglob` and the matching `shopt -u nullglob` to `shopt -u nullglob nocaseglob` in `scan_dir()`
4. Add the same uppercase case to the script's `_self_test()`
5. Run `bash tests/ticket-scripts/test-scan-active-ledgers.sh` and `bash skills/gaspol-execute/scripts/scan-active-ledgers --self-test`, confirm both pass
6. Commit: "fix(execute): scan-active-ledgers matches PROGRESS-*.md case-insensitively"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-scan-active-ledgers.sh` exit 0
- [ ] `bash skills/gaspol-execute/scripts/scan-active-ledgers --self-test` exit 0
- [ ] Ledger lama huruf kecil (`progress-IND-79.md`) MASIH terdeteksi — backward-compatible, dibuktikan oleh kasus lama yang tetap ada di tes
- [ ] `bash -n skills/gaspol-execute/scripts/scan-active-ledgers` exit 0

---

### Phase C: konvensi nama file spec & plan

**Estimated time:** 12 menit

**Files:**
- Modify: `skills/gaspol-brainstorm/SKILL.md` (bagian Phase 6, sekitar baris 323)
- Modify: `skills/gaspol-plan/SKILL.md` (bagian "Save Plans To", baris ~44-60; langkah header ~82; contoh header ~98)
- Modify: `agents/plan-verifier.md` (baris 23)
- Modify: `skills/gaspol-finish/SKILL.md` (baris 56)
- Modify: `skills/gaspol-verify/plan-verification.md` (baris 10-12, 63, 271)
- Modify: `skills/gaspol-verify/SKILL.md` (baris 151)
- Test: `tests/ticket-scripts/test-naming-convention.sh` (baru — grep assertions)

**Konvensi baru (verbatim, pakai persis ini di semua file):**

```text
docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-spec.md
docs/plans/YYYY-MM-DD-<TICKET>-<kebab-topic>-plan.md
```

`YYYY-MM-DD` = tanggal file **dibuat**, bukan tanggal ticket dimint. Karena plan boleh
bertanggal beda dari spec-nya, `gaspol-plan` **wajib** mencari spec pendahulunya lewat glob,
bukan menyusun ulang nama dari tanggal:

```text
docs/plans/*-<TICKET>-*-spec.md
```

Kalau glob mengembalikan lebih dari satu file → STOP, tanya user. Jangan pilih sendiri.

Catatan migrasi yang harus ditulis di `skills/gaspol-plan/SKILL.md`: tujuh file lama di
`docs/plans/` (`2026-04-17-gaspol-improvements.md`, `2026-06-09-ecc-adoption-p0-security-eval.md`,
`2026-06-30-superpowers-adoption.md`, `2026-06-30-v1.6-sdd-review-harness.md`,
`2026-06-30-v1.7-visual-companion.md`, `2026-08-16-gaspol-workflow-hardening.md`,
`2026-08-16-gaspol-workflow-hardening-plan.md`) lahir sebelum ticket-minting ada dan
**tidak di-rename** — tak punya ticket untuk disisipkan, dan mengarangnya berarti menaruh
data palsu di nama file. Glob `*-<TICKET>-*-spec.md` otomatis aman terhadap file-file itu.

**Steps:**
1. Write failing test asserting `grep -q 'YYYY-MM-DD-<TICKET>-<kebab-topic>-spec.md' skills/gaspol-brainstorm/SKILL.md` succeeds. Expected error: `test-naming-convention.sh: assertion failed — brainstorm still writes docs/plans/<TICKET>-<kebab-topic>-spec.md` (exit 1)
2. Run `bash tests/ticket-scripts/test-naming-convention.sh`, confirm it fails for that reason
3. Update `skills/gaspol-brainstorm/SKILL.md` Phase 6 to the dated spec path
4. Update `skills/gaspol-plan/SKILL.md`: dated plan path, glob-based spec lookup (with the >1-match STOP rule), the migration note above, and the header example
5. Update the four remaining path references (`agents/plan-verifier.md`, `skills/gaspol-finish/SKILL.md`, `skills/gaspol-verify/plan-verification.md`, `skills/gaspol-verify/SKILL.md`) — note `plan-verification.md` currently shows the pre-ticket form `docs/plans/YYYY-MM-DD-feature-name.md`, which is doubly stale
6. Extend the test with one assertion per touched file, plus a negative assertion that `grep -rn 'docs/plans/<TICKET>-' skills/ agents/` returns nothing
7. Run `bash tests/ticket-scripts/test-naming-convention.sh`, confirm pass
8. Commit: "feat(brainstorm,plan): date-prefixed spec/plan filenames + glob-based spec lookup"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-naming-convention.sh` exit 0
- [ ] `grep -rn 'docs/plans/<TICKET>-' skills/ agents/` → nol hasil
- [ ] `grep -rn 'YYYY-MM-DD-feature-name' skills/` → nol hasil (bentuk pra-ticket sudah hilang)
- [ ] Aturan STOP-kalau-glob->1 tertulis eksplisit di `skills/gaspol-plan/SKILL.md`
- [ ] Catatan migrasi 7 file lama tertulis di `skills/gaspol-plan/SKILL.md`

---

### Phase D: format ledger `PROGRESS-<TICKET>.md` + gaspol-plan bikin skeleton

**Estimated time:** 15 menit

**Files:**
- Modify: `skills/gaspol-plan/SKILL.md` (langkah 4 derivasi ledger; blok header "Progress ledger"; tabel Red Flags baris ~298)
- Modify: `skills/gaspol-execute/SKILL.md` (baris ~53 perintah scan; ~101-102 resolusi ledger; ~242 pembuatan file; ~288 pesan resume)
- Modify: `skills/gaspol-execute/checkpoint-template.md` (baris ~72)
- Modify: `skills/gaspol-parallel/SKILL.md` (baris ~363-364, ~382)
- Test: extend `tests/ticket-scripts/test-naming-convention.sh`

**Format ledger (verbatim — pakai persis ini sebagai contoh di SKILL.md):**

```markdown
# PROGRESS — IDS-1: gaspol output naming standard

**Ticket:** IDS-1
**Plan:** docs/plans/2026-08-20-IDS-1-gaspol-output-naming-standard-plan.md

## Checklist
- [x] Phase A: script detect-stack — DONE
- [>] Phase B: glob ledger case-insensitive — DOING
- [ ] Phase C: konvensi nama file spec & plan
- [~] Phase D: contoh fase dibatalkan — DIBATALKAN (YAGNI, alasan di Log)

## Log
- 2026-08-20 Phase A done — `bash tests/ticket-scripts/test-detect-stack.sh` exit 0 — NEXT: Phase B
```

Empat state checklist:

| Marker | Arti | Syarat |
|--------|------|--------|
| `[ ]` | todo | — |
| `[>]` | sedang dikerjakan | diset saat fase mulai |
| `[x]` | selesai | tes fase itu hijau |
| `[~]` | dibatalkan / dilewati | **wajib** alasan singkat di baris itu + rincian di Log |

Aturan struktural yang WAJIB ditulis di SKILL.md: **`## Log` selalu blok terakhir.**
`scan-active-ledgers` membaca baris non-kosong terakhir file, jadi kalau ada blok lain di
bawah Log, deteksi aktif/selesai rusak.

Pembuat: **`gaspol-plan`**, saat plan ditulis — checklist berisi seluruh nama fase dalam
keadaan `[ ]`, plus satu baris Log awal:
`- <YYYY-MM-DD> plan ditulis — NEXT: Phase A`.

Gate baru untuk `gaspol-execute` dan `gaspol-parallel` (BLOCKING): selesai satu fase/task →
centang checklist **dan** tulis baris Log, **sebelum** yang berikutnya mulai.

Backward-compat: ledger lama (`.gaspol/progress/<slug>.md` dan `.gaspol/progress.md`) tetap
dibaca kalau plan menyebutnya; hanya penulisan baru yang pakai `PROGRESS-<TICKET>.md`.

**Steps:**
1. Write failing test asserting `grep -q 'PROGRESS-<TICKET>.md' skills/gaspol-plan/SKILL.md` and that the four-state marker table is present. Expected error: `assertion failed — gaspol-plan still derives .gaspol/progress/progress-<TICKET>.md` (exit 1)
2. Run `bash tests/ticket-scripts/test-naming-convention.sh`, confirm the new assertions fail
3. Update `skills/gaspol-plan/SKILL.md`: ledger path, the verbatim ledger template above, the four-state table, the "Log is always last" rule, and the instruction to CREATE the file at plan-write time
4. Update `skills/gaspol-execute/SKILL.md` + `checkpoint-template.md`: new path, and the per-phase tick-checklist-then-append-Log gate
5. Update `skills/gaspol-parallel/SKILL.md`: same path + per-task tick gate
6. Update the Red Flags row in `skills/gaspol-plan/SKILL.md` (~line 298) to name the new path
7. Run `bash tests/ticket-scripts/test-naming-convention.sh`, confirm pass
8. Commit: "feat(plan,execute,parallel): PROGRESS-<TICKET>.md ledger with per-phase checklist gate"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-naming-convention.sh` exit 0
- [ ] `grep -rn 'progress/progress-' skills/ agents/` → nol hasil
- [ ] Tabel 4 state (`[ ] [>] [x] [~]`) ada di `skills/gaspol-plan/SKILL.md`
- [ ] Aturan "`## Log` selalu blok terakhir" tertulis eksplisit
- [ ] Instruksi bikin ledger saat plan ditulis ada di `skills/gaspol-plan/SKILL.md`
- [ ] Gate centang-per-fase ada di execute DAN parallel

---

### Phase E: wire `detect-stack` ke gate verifikasi

**Estimated time:** 12 menit

**Files:**
- Modify: `skills/gaspol-verify/SKILL.md` (Layer 1, baris ~52-82)
- Modify: `skills/gaspol-parallel/SKILL.md` (Validation Ladder, baris ~196-202)
- Modify: `skills/gaspol-plan/SKILL.md` (bagian Phase Structure — blok Verification)
- Modify: `skills/gaspol-execute/implementer-prompt.md`
- Test: extend `tests/ticket-scripts/test-naming-convention.sh`

**Perluasan cakupan disetujui user 2026-08-20 (hard-stop `gaspol-auto`, bukan perubahan diam-diam):**
Phase A menyelesaikan cek penopang hanya untuk node (key di `.scripts` package.json) dan php
(binary di `vendor/bin/`), sesuai tabel yang ditulis plan ini. Akibatnya `pytest`, `mypy`,
`ruff`, `go test`, `cargo test`, `flutter test` selalu dicetak begitu file penandanya ada —
tanpa bukti tool-nya terpasang. Itu kelas masalah yang sama dengan yang IDS-1 bunuh, cuma
bergeser satu tingkat. Phase E karena itu JUGA menambahkan ke `detect-stack`: cek
`command -v <binary>` untuk level python/go/rust/flutter; tidak ditemukan → cetak
`<level>: UNKNOWN`. Tambah kasus tes untuk itu di `tests/ticket-scripts/test-detect-stack.sh`.

**Yang berubah:**

`gaspol-verify` Layer 1 sekarang memuat blok perintah npm hardcoded (`npm run build` L56,
`npx tsc --noEmit` L64, `npm test -- --watchAll=false` L72, `npm run lint` L82). Ganti
menjadi: jalankan `skills/gaspol-execute/scripts/detect-stack <project-root>`, lalu
jalankan setiap baris yang dicetaknya. Perlakuan hasil:

- Baris `<level>: <perintah>` → jalankan, exit code harus 0
- Baris `<level>: UNKNOWN` → **STOP dan tanya user** perintah apa yang benar. Jangan tebak,
  jangan lewati diam-diam.
- **Nol baris** (tak ada penanda stack, seperti repo gaspol-dev sendiri) → tidak ada
  verifikasi otomatis yang bisa diturunkan; pakai perintah yang ditulis plan di blok
  `Verification` tiap fase. Catat eksplisit: "detect-stack: no stack markers, using
  plan-declared commands".

`gaspol-parallel` Validation Ladder L1 sekarang menyebut `tsc --noEmit` harfiah — ganti
jadi "perintah `static:` dari `detect-stack`", L2 jadi "perintah `unit:`", L3 jadi
"perintah `build:` (N/A eksplisit kalau tak dicetak)". L4/L5 tak berubah.

`gaspol-plan` harus menjalankan `detect-stack` saat plan ditulis dan menyalin perintah
hasilnya **verbatim** ke blok `Verification` tiap fase — plan wajib self-contained, jadi
perintahnya harus ada di plan, bukan cuma di script.

`implementer-prompt.md` harus memuat perintah ladder verbatim, karena subagent implementer
tidak bisa membaca script ini.

Live App Check di `gaspol-verify` (~L88-95) **tidak berubah** — ia menyala dari
"UI/user-visible", bukan dari stack.

**Steps:**
1. Write failing test asserting `grep -q 'detect-stack' skills/gaspol-verify/SKILL.md` succeeds and that `grep -c 'npm run build' skills/gaspol-verify/SKILL.md` is 0 outside example blocks. Expected error: `assertion failed — verify Layer 1 still hardcodes npm commands` (exit 1)
2. Run `bash tests/ticket-scripts/test-naming-convention.sh`, confirm the new assertions fail
3. Rewrite `gaspol-verify` Layer 1 per the three result cases above
4. Update `gaspol-parallel` Validation Ladder rows L1-L3
5. Update `gaspol-plan` Phase Structure so the Verification block is filled from `detect-stack` output verbatim
6. Update `implementer-prompt.md` to carry the ladder commands verbatim
7. Run `bash tests/ticket-scripts/test-naming-convention.sh`, confirm pass
8. Commit: "feat(verify,parallel,plan): derive verification commands from detect-stack, not hardcoded npm"

**Verification:**
- [ ] `bash tests/ticket-scripts/test-naming-convention.sh` exit 0
- [ ] `detect-stack` disebut di `gaspol-verify/SKILL.md`, `gaspol-parallel/SKILL.md`, `gaspol-plan/SKILL.md`
- [ ] Tiga kasus hasil (perintah / `UNKNOWN` → STOP / nol baris → pakai perintah plan) tertulis eksplisit di `gaspol-verify/SKILL.md`
- [ ] `npm run build` / `npx tsc --noEmit` di `gaspol-verify/SKILL.md` hanya muncul sebagai **contoh keluaran** `detect-stack`, bukan perintah wajib
- [ ] Live App Check masih utuh di `gaspol-verify/SKILL.md`
- [ ] `implementer-prompt.md` memuat perintah ladder verbatim

---

### Phase F: gerbang akhir — sinkron dokumentasi + suite penuh

**Estimated time:** 12 menit

**Files:**
- Modify: `CLAUDE.md` (baris ~321-322 konvensi ledger; ~449 Phase 6 brainstorm; ~519 path plan; tabel Architecture untuk script baru)
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (bump versi)

**Steps:**
1. Write failing test asserting `grep -q 'PROGRESS-<TICKET>.md' CLAUDE.md` and `grep -q 'detect-stack' CLAUDE.md`. Expected error: `assertion failed — CLAUDE.md still documents .gaspol/progress/<slug>.md` (exit 1)
2. Run `bash tests/ticket-scripts/test-naming-convention.sh`, confirm the new assertions fail
3. Update `CLAUDE.md`: konvensi nama file, format ledger + 4 state, baris `detect-stack` di tabel Architecture, dan bagian verifikasi Layer 1
4. Tambah entri CHANGELOG untuk IDS-1
5. Bump versi di `plugin.json` + `marketplace.json` + footer `CLAUDE.md` (1.12.0 → 1.13.0 — perubahan konvensi + script baru, bukan perbaikan bug)
6. Run the FULL suite: `bash tests/ticket-scripts/test-detect-stack.sh`, `bash tests/ticket-scripts/test-scan-active-ledgers.sh`, `bash tests/ticket-scripts/test-next-ticket.sh`, `bash tests/ticket-scripts/test-naming-convention.sh`, `bash tests/skill-triggering/run-all.sh`, `bash tests/pressure/run-all.sh`
7. Commit: "chore: sync CLAUDE.md/CHANGELOG/version for IDS-1 naming + ledger + detect-stack"

**Verification:**
- [ ] Lima dari enam perintah tes di langkah 6 exit 0 — kutip jumlah pass tiap suite, jangan
      cuma bilang "hijau". **Pengecualian yang diketahui dan diterima: `tests/pressure/run-all.sh`
      exit 1.** Suite itu memanggil CLI `claude` sungguhan dan stokastik — dua pengukuran di
      branch ini memberi 3/9 dengan komposisi kegagalan berbeda (satu run: keenam gagal
      `triggered=NO`; run lain: dua di antaranya kapitulasi asli pada `gaspol-security-review`
      dan `gaspol-execute` over-build). Merahnya mendahului IDS-1: `tests/pressure/` tak
      tersentuh ticket ini, nol baris `description:` frontmatter berubah di ketujuh commit
      (frontmatter yang menggerakkan trigger), dan `gaspol-security-review/SKILL.md` tak ada
      di diff sama sekali. Pengukuran baseline di `cd8bd1a` memberi 1/9. Perbaikan suite ini
      adalah ticket tersendiri, BUKAN cakupan IDS-1.
- [ ] `grep -rn 'progress/progress-\|docs/plans/<TICKET>-' skills/ agents/ CLAUDE.md` → nol hasil
- [ ] Versi sama persis di `plugin.json`, `marketplace.json`, footer `CLAUDE.md`
- [ ] Nol komentar TODO/FIXME/placeholder di semua file yang disentuh IDS-1
- [ ] `git status` bersih setelah commit terakhir

## Catatan eksekusi

**Urutan wajib.** Phase E bergantung pada script dari Phase A. Phase D bergantung pada
path ledger dari Phase C tidak bertabrakan. Phase F harus terakhir — ia mengklaim seluruh
suite hijau.

**ponytail:** nol dependensi baru, nol framework tes baru. Tes memakai pola bash yang sudah
dipakai dua script existing. `test-naming-convention.sh` sengaja satu file berisi assertion
grep untuk Phase C/D/E/F, bukan empat file terpisah — assertion-nya sejenis dan satu file
lebih murah dibaca daripada empat.

**Yang TIDAK dikerjakan plan ini** (sudah diputuskan, jangan dihidupkan lagi): tidak ada
lapisan PRD; tidak ada taksonomi layer frontend/backend/integration; tujuh file lama di
`docs/plans/` tidak di-rename. Rubrik model yang basi (`docs/rubric-model-switching.md`
menyebut opus 4.7 / sonnet 4.6 / haiku 4.5, dan brainstorm+plan tak punya baris rubrik)
adalah ticket terpisah — **jangan** disentuh di sini.

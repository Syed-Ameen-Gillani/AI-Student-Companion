# Student Companion requirement status

## Built

- [x] Android Flutter app with Material 3 phone navigation, tablet rail, light/dark theme, and first-launch setup.
- [x] SQLite schema version 3 with migration, local repository and AI service contracts, and user-provided key in secure storage.
- [x] Offline notes, tasks, saved conversations, search/filter/sort, due dates, and local Home counts.
- [x] Gemini REST client, model setting, bounded history, Markdown, copy/retry, and actionable network/API errors.
- [x] Notes AI previews and structured, validated Assistant note/task drafts that require editable confirmation and Save.
- [x] PDF/TXT import into app storage, text extraction, chunking, lexical retrieval, selected documents, and saved source excerpts.
- [x] Versioned backup and restore with document hash checks, rollback on failed restore, key exclusion, theme and data controls.
- [x] Dependency lockfile, README, architecture overview, and Android debug APK.

## Verified

- [x] Dart formatting, Flutter static analysis, and unit/widget tests.
- [x] Android note/task persistence after widget restart.
- [x] Android text PDF import, page reference, retrieval, unrelated-query rejection, and file/chunk deletion.
- [x] Android document chat saves a valid citation and does not call Gemini when no relevant excerpt exists. AI response was mocked for this deterministic test.
- [x] Android Assistant note draft writes only after Save; an invalid action leaves notes untouched. AI response was mocked.
- [x] Android backup, reset, restore, and corrupt-backup rejection without data loss.
- [x] Android phone and tablet-width navigation layout.
- [x] One direct live request to Gemini 3.8 Flash returned a nonempty response with the local key.
- [x] On the Android emulator, Settings saved the key from the ignored local `.env` file to secure storage and Test connection succeeded with Gemini 3.5 Flash-Lite.
- [x] A live Assistant question returned a Gemini answer; the question and answer remained in conversation history after force stopping and relaunching the app.
- [x] The Android file picker imported a sample TXT file, and a live Documents question returned an answer with a saved source marker.

## Still unverified or limited

- [ ] Sourced answers from Gemini using an actual academic paper. The live on-device document test used a short original TXT sample, while the PDF import integration used a generated text PDF.
- [ ] Android backup share sheet has not been tested interactively on the emulator; backup/restore behavior passed Android integration tests.
- [ ] Release signing, unique Android application ID, and other platforms. This build is Android debug only.

Retrieval is lexical and can miss conceptual matches. Scanned PDFs, DOCX, notifications, sync, and multiple accounts are intentionally outside this version.

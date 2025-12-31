# PetOps

iOS app to manage a pet’s complete lifecycle: profile, medical timeline, medications, vaccines, vet visits, documents, reminders, and costs — with AI-assisted document ingestion (on-device or cloud).

## Goals
- Offline-first: everything works without internet
- User-owned storage: Core Data + CloudKit sync (iCloud)
- Auditability: AI suggestions are reviewed before committing to the database
- Privacy-first: on-device AI default; cloud AI is explicit opt-in

## Core Features (Planned)
- Multi-pet profiles
- Unified timeline (visits, vaccines, meds, symptoms, labs, procedures, notes)
- Reminders (med schedules, vaccine due dates, follow-ups)
- Document vault (scan, OCR, tag, search)
- Expenses & reports (monthly/yearly + CSV export)
- Vet Pack export (PDF summary + attachments)

## AI Modes
### On-device
- OCR + deterministic extraction (baseline)
- On-device LLM features when available (feature-flagged by OS/device)

### Cloud (ChatGPT/OpenAI)
- Structured extraction using JSON Schemas
- Redaction preview + explicit opt-in
- Never writes directly to the DB; proposals only

## Tech Stack
- Swift + SwiftUI
- Core Data + CloudKit (NSPersistentCloudKitContainer)
- VisionKit scanning + OCR
- StoreKit 2 (optional premium)
- Optional backend: entitlements + MCP connector for ChatGPT

## Repo Structure (WIP)
- App: SwiftUI screens + navigation
- Persistence: Core Data stack + repositories
- DocIngestion: scan/OCR pipeline + review UI
- Reminders: scheduling + local notifications
- Exports: PDF/CSV generation
- AIKit: orchestrator + providers

## Local Setup
- Open `PetOps.xcodeproj`
- Select a simulator
- Run (⌘R)

## Privacy
Pet data is stored locally and may sync via the user’s iCloud account. Cloud AI is off by default and requires explicit consent per feature.

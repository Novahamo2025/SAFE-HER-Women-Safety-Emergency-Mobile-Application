# SafeHer: Women Safety & Emergency Response Platform

A privacy-focused, mission-critical mobile safety application ecosystem designed to provide rapid emergency alerting, live location sharing, safe journey tracking, and automated escalation.

---

## 🏗️ System Architecture

SafeHer is built as a multi-tier, decoupled system:

```
┌───────────────────────────────────────────────────────────────┐
│              SafeHer Mobile Client (Flutter)                  │
│  - Offline-first 3-second SOS Trigger                         │
│  - Device-Native Carrier SMS Intent (Zero-DLT immediate p2p)  │
│  - Android FOREGROUND_SERVICE_LOCATION (Continuous GPS)       │
│  - OEM Battery Optimization Whitelist deep links              │
│  - Strobe flashlight, loud siren, and local evidence vault   │
└───────────────────────────────┬───────────────────────────────┘
                                │ HTTPS REST / WebSocket
                                ▼
┌───────────────────────────────────────────────────────────────┐
│            SafeHer Backend (Spring Boot 3.3, Java 21)         │
│  - Spring Security 6 with stateless JWT authentication        │
│  - @Scheduled (60s) Safety Escalation Engine                  │
│  - Dual-channel notifications (SMS Gateway + Firebase FCM)    │
│  - Complete Audit Trail and Data Retention Engine             │
└────────────────┬──────────────────────────────┬───────────────┘
                 │                              │
                 ▼                              ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│     PostgreSQL Database      │ │ React Admin Portal (Vite/TS) │
│ (10 Core Normalized Tables)  │ │ (Emergency HUD & Monitoring) │
└──────────────────────────────┘ └──────────────────────────────┘
```

---

## 🛡️ Key Architectural Solutions

1. **Google Play Compliance:** Uses `FOREGROUND_SERVICE_LOCATION` with a persistent sticky notification during active emergencies/Safe Walk. Avoids invasive `ACCESS_BACKGROUND_LOCATION` review rejections.
2. **Dual-Channel Alerting:** 
   - **Native Device SMS:** Fires immediately from user's carrier SIM to emergency contacts (zero DLT wait, works with zero mobile data).
   - **Server Gateway SMS (MSG91/Gupshup):** Handled by Spring Boot scheduler for automatic Safe Walk / Check-In escalation.
3. **Offline-First Persistence:** Pressing SOS persists the emergency event to local encrypted storage instantly, before any network handshake.
4. **OEM Battery-Killer Defense:** Onboarding steps guide users on Xiaomi (MIUI/HyperOS), Vivo, Oppo, and OnePlus to whitelist the app from background kills.
5. **Server-Side Escalation:** Scheduled background jobs check for overdue journeys every 60s and alert contacts even if the user's phone runs out of battery.

---

## 📁 Repository Structure

```text
C:\Users\srina\Downloads\SafeHer/
├── safeher-database/         # PostgreSQL DDL migration scripts (10 tables)
├── safeher-backend/          # Spring Boot (Java 21) REST & WebSocket API
├── safeher-mobile/           # Flutter (Dart) Android & iOS Mobile Application
└── safeher-admin/            # React + TypeScript (Vite) Admin Monitoring Dashboard
```

---

## 🚀 Quick Start Guide

### 1. Database Setup
Ensure PostgreSQL is running, then execute the schema:
```bash
psql -U postgres -d postgres -c "CREATE DATABASE safeher;"
psql -U postgres -d safeher -f safeher-database/V1__init_schema.sql
psql -U postgres -d safeher -f safeher-database/V2__seed_data.sql
```

### 2. Spring Boot Backend
```bash
cd safeher-backend
# Run with Maven wrapper
./mvnw spring-boot:run
# Server starts at http://localhost:8080
```

### 3. Flutter Mobile Application
```bash
cd safeher-mobile
flutter pub get
flutter run
```

### 4. React Admin Dashboard
```bash
cd safeher-admin
npm install
npm run dev
# Dashboard available at http://localhost:5173
```

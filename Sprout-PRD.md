# 🌱 SPROUT TRACK — PRODUCT REQUIREMENTS DOCUMENT
## Version 3.0 | June 2026
### From Idea to Bankable Platform

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Product Philosophy](#2-product-philosophy)
3. [User Personas](#3-user-personas)
4. [Core Modules](#4-core-modules)
5. [Features: Current vs. Target](#5-features-current-vs-target)
6. [AI & Automation Roadmap (PENDED)](#6-ai--automation-roadmap-pended)
7. [Receipt Verification System](#7-receipt-verification-system)
8. [Revenue Model](#8-revenue-model)
9. [Go-to-Market Strategy](#9-go-to-market-strategy)
10. [Technical Architecture](#10-technical-architecture)
11. [Execution Roadmap](#11-execution-roadmap)
12. [Success Metrics](#12-success-metrics)
13. [Risk & Mitigation](#13-risk--mitigation)
14. [Appendices](#14-appendices)

---

## 1. EXECUTIVE SUMMARY

### What Sprout Is
Sprout Track is a **business growth platform** for Nigerian small and medium enterprises (SMEs). It combines inventory management, invoicing, expense tracking, and financial intelligence into one web-first mobile app.

### What Sprout Is Not
- Not an accounting app for accountants
- Not a QuickBooks clone
- Not a bank-dependent platform

### The Core Insight
> Nigerian SME owners don't wake up wanting accounting software. They wake up wanting to know: *"Can I pay my supplier today? Who owes me money? What should I reorder?"*

Sprout answers these questions in 5 seconds, works in any browser, and turns daily operations into bankable financial records.

### The Long-Term Vision
Become the **system of record** for Nigerian SME financial data — enabling credit access, supplier trust, and business growth.

---

## 2. PRODUCT PHILOSOPHY

### The 5 Principles

| Principle | What It Means | Anti-Pattern |
|-----------|-------------|--------------|
| **Workflows, not features** | End-to-end: customer calls → check stock → quote → invoice → payment → reorder | Modular features that don't connect |
| **Business language, not accounting** | "How much did I make?" not "Net profit margin" | "Accounts receivable aging" |
| **Web-first PWA, always** | Works in any browser. Installable as app. No download needed. | "Download our app from the app store" |
| **Decisions, not reports** | "Reorder rice by Thursday" not "Stock: 12 units" | Dashboards with no actionable output |
| **Trust through transparency** | Every receipt verifiable. Every number explainable. | Black-box algorithms users don't understand |

### The Vibe-Coding Manifesto
- Ship the smallest version that demonstrates value
- Show 5 real users. Watch them. Fix what confuses them.
- If you can't explain it to a shop owner in Lagos Island, don't build it
- Perfect is the enemy of shipped

---

## 3. USER PERSONAS

### Primary: Mama Ngozi (Micro-Retailer)
- **Business:** Sells rice, beans, oil from a small shop in Ibadan
- **Tech:** ₦45,000 Android phone, basic smartphone browser
- **Pain:** Doesn't know if she's profitable. Runs out of stock unexpectedly. Customers owe her money but she forgets who.
- **Goal:** Know if she made money today. Don't run out of rice.
- **Bank:** Personal account, checks balance at ATM weekly

### Secondary: Emeka (Distributor)
- **Business:** Supplies 30+ retailers with packaged goods
- **Tech:** ₦120,000 Samsung, 4G, uses WhatsApp Business
- **Pain:** 15 outstanding invoices. Doesn't know who paid, who hasn't. Manual reconciliation takes 6 hours every weekend.
- **Goal:** Collect money faster. Know cash position without checking 3 bank apps.
- **Bank:** 2 business accounts, checks daily

### Tertiary: Aisha (Growing Retail Chain)
- **Business:** 3 locations, 8 employees, applying for bank loan
- **Tech:** iPad + phones, good internet
- **Pain:** No financial records for loan application. Employees steal stock. Can't compare location performance.
- **Goal:** Bank-ready P&L. Multi-location visibility. Employee accountability.
- **Bank:** Corporate accounts, relationship manager

---

## 4. CORE MODULES

### Module 1: Inventory Management

**Purpose:** Know what you have, what it's worth, and what to reorder.

**Current State:**
- Products with name, description, SKU, cost price, quantity
- Stock movement tracking (in/out/adjustment)
- Low-stock alerts at static threshold

**Target State:**

| Feature | Priority | Description |
|---------|----------|-------------|
| **Selling price** | P0 | Price charged to customer. Enables margin calculation. |
| **Weighted Average Cost** | P0 | Running average: (total cost) / (total quantity). Accurate COGS. |
| **Margin display** | P0 | `margin = (selling - cost) / selling × 100`. Per product, per category. |
| **Smart reorder** | P1 | "Reorder by Thursday — 3 left, you sell 8/week." Velocity-based. |
| **Supplier tracking** | P1 | Who supplied what, at what price, when. |
| **Dead stock flag** | P2 | "Not sold in 90 days." Free up capital. |
| **Batch/expiry (FEFO)** | P2 | For perishables: food, medicine, cosmetics. |

**User Flow:**
```
Add Product → Enter name, cost price, selling price, initial stock
            → Set reorder threshold (optional, AI suggests later)
            → Save

Daily Use:  → Check "Stock" tab → see quantities, margins
            → Red alert: "Reorder Rice 50kg — 3 left, 8/week velocity"
            → Tap alert → create purchase order → supplier contacted
```

---

### Module 2: Invoice & Receipt Management

**Purpose:** Get paid. Track who owes what. Look professional.

**Current State:**
- Invoices and receipts created together (conflated)
- Basic printable PDF
- No payment tracking depth

**Target State:**

| Feature | Priority | Description |
|---------|----------|-------------|
| **Separate invoice vs. receipt** | P0 | Invoice = "you owe me." Receipt = "I got paid." Sales receipt = immediate payment. |
| **Payment tracking** | P0 | Partial payments, overpayments, write-offs. Payment history per invoice. |
| **Invoice aging** | P0 | Current, 1-30, 31-60, 61-90, 90+ days. Color-coded. |
| **Auto inventory deduction** | P0 | Invoice created → stock deducted. Invoice cancelled → stock restored. |
| **Branded templates** | P1 | Logo, business colors, tagline. #1 driver of ICT adoption. |
| **Bulk reminders** | P1 | One-click: remind all 90+ day overdue customers via WhatsApp/SMS. |
| **Recurring invoices** | P2 | Weekly/monthly retainers. Auto-generate, auto-send. |

**Invoice Lifecycle:**
```
DRAFT → SENT → VIEWED → PARTIALLY PAID → PAID → OVERDUE → WRITTEN OFF
   ↑       ↑        ↑            ↑           ↑        ↑         ↑
  Edit   Share   Opened     Record payment  Done   Reminder  Reason
```

**User Flow:**
```
Customer calls for 10 bags rice
→ Check stock: "12 available, ₦3,200/bag"
→ Create quote: 10 × ₦3,200 = ₦32,000
→ Customer approves → convert to invoice
→ Stock auto-deducted: 12 → 2
→ Send via WhatsApp
→ Customer pays ₦20,000 → record partial payment
→ Balance: ₦12,000 → reminder in 7 days
→ Full payment → receipt generated → customer history updated
```

---

### Module 3: Customer Management (CRM)

**Purpose:** Remember customers. Predict behavior. Protect revenue.

**Current State:**
- Name, phone, email, address
- Purchase history linked to invoices
- Running balance

**Target State:**

| Feature | Priority | Description |
|---------|----------|-------------|
| **Auto-segmentation** | P1 | VIP (>₦500K lifetime), Regular, At-Risk (slowing purchases), Dormant (>90 days). |
| **Credit limits** | P1 | Soft warning at 80%. Hard stop at 100% (configurable). |
| **Payment behavior** | P1 | "Average payment: 6 days. Current invoice: 12 days — unusual." |
| **Customer profitability** | P3 | LTV vs. cost-to-serve (returns, complaints, collection effort). |

---

### Module 4: Expense Tracking

**Purpose:** Know where money goes. Stay within budget.

**Current State:**
- Amount, date, description
- Minimal/no categorization

**Target State:**

| Feature | Priority | Description |
|---------|----------|-------------|
| **Categories** | P0 | Rent, Salaries, Utilities, Transport, Marketing, Inventory Purchase, Other. |
| **Monthly budgets** | P0 | Set per category. Track vs. actual. Alert at 80%. |
| **Auto-categorization** | P1 | Learn from user corrections. "FUEL STATION → Transport." |
| **Receipt photo** | P2 | Capture + OCR. Tax compliance + audit proof. |
| **Recurring templates** | P2 | Rent, salaries, subscriptions. Auto-generate monthly. |
| **Split expenses** | P3 | One receipt: ₦50K total → ₦30K inventory, ₦20K transport. |

---

### Module 5: Business Dashboard

**Purpose:** One glance. One decision. One action.

**Current State:**
- Revenue, Expenses, Net Profit, Stock Value cards
- Cash flow chart (often empty)
- All zeros for new users

**Target State:**

| Feature | Priority | Description |
|---------|----------|-------------|
| **Cash Position** | P0 | Manual entry: cash on hand + bank balances. #1 survival metric. |
| **Money Owed to Me** | P0 | Total outstanding + aging breakdown + top debtors. |
| **Business Health Score** | P0 | 0-100. Weighted: cash runway (30%), profit trend (25%), receivables (20%), inventory health (15%), expense control (10%). |
| **"3 Things to Do Today"** | P0 | Actionable alerts: "Invoice ABC Store — ₦150K overdue." "Reorder rice — 3 left." |
| **Demo data toggle** | P0 | "See how Sprout works" → populate with sample data. "Start fresh" → clear. |
| **Last updated timestamp** | P1 | "Data as of 2 mins ago." Trust signal. |
| **Color psychology fix** | P1 | Expenses down = green arrow. Good trends = green regardless of direction. |

**Dashboard Layout (Top to Bottom):**
```
┌─────────────────────────────────────────┐
│  🟢 Business Health: 78/100              │
│  "You're doing well! 2 things to fix."   │
├─────────────────────────────────────────┤
│  💰 Cash Position    │  💳 Money Owed   │
│  ₦245,000            │  ₦420,000        │
│  ▼ 12% vs last week  │  ⚠️ ₦200K overdue│
├─────────────────────────────────────────┤
│  📈 Revenue          │  📉 Expenses      │
│  ₦870K               │  ₦498K            │
│  ▲ +18.4%            │  ▼ -6.2% (good)   │
├─────────────────────────────────────────┤
│  🔔 TODAY'S PRIORITIES                  │
│  • Call ABC Store — ₦150K, 5 days late  │
│  • Reorder Rice 50kg — 3 left           │
│  • Review transport — 60% over budget   │
├─────────────────────────────────────────┤
│  📊 Cash Flow (Income vs Expenses)      │
│  [Last 6 months — all populated]        │
└─────────────────────────────────────────┘
```

---

### Module 6: Financial Reporting

**Purpose:** Turn operations into bankable records.

**Current State:**
- Sales reports
- Basic P&L
- Inventory reports

**Target State:**

| Feature | Priority | Description |
|---------|----------|-------------|
| **Export formats** | P1 | Excel, CSV, PDF. Accountant-ready. |
| **Tax tagging** | P2 | VAT, CIT, PAYE categories for compliance. |
| **Loan Readiness Score** | P1 | 0-100 based on: record completeness, consistency, history depth, revenue trend, expense control. |
| **Bank-specific templates** | P2 | Co-branded with Zenith, GTBank, etc. |
| **Historical comparison** | P2 | YoY, QoQ, rolling 12-month. |

---

### Module 7: Receipt Verification

**Purpose:** Fraud-proof. Publicly verifiable. Trust-building.

**Current State:**
- QR code on receipts
- Unique receipt number

**Target State:**

| Feature | Priority | Description |
|---------|----------|-------------|
| **Cryptographic signing** | P1 | ECDSA signature on every receipt. Private key in HSM/KMS. |
| **Public verification site** | P1 | `verify.sprout.ng/[receipt_id]` — no login needed. |
| **Immutable audit trail** | P2 | Void = new record with reference. Never delete. Hash chain optional. |
| **Duplicate scan detection** | P2 | "This QR was scanned 3 times." Not invalid, just flagged. |

**Architecture:**
- Main app: creates receipt, signs with private key (AWS KMS)
- Verification site: separate domain, read-only, re-verifies signature on every request
- If verification DB compromised: signatures still valid, main DB is source of truth

---

### Module 8: Web-First PWA

**Purpose:** Business management accessible from any device, anywhere, instantly.

**Current State:**
- Core functionality works in browser
- Data syncs to cloud in real-time
- Installable as PWA for home screen access

**Target State:**

| Feature | Priority | Description |
|---------|----------|-------------|
| **PWA install prompt** | P0 | "Add to Home Screen" banner. One-tap install. Feels like native app. |
| **Service worker caching** | P1 | Cache static assets. Fast load on repeat visits. |
| **Background sync** | P1 | Queue actions when connection drops. Auto-retry when back. |
| **Connection-aware UI** | P1 | Show "Saving..." / "Saved" / "Connection lost — will retry" states. |
| **Responsive design** | P0 | Works on ₦45K Android (5.5") to iPad Pro (12.9"). |
| **Cross-device sync** | P0 | Login on phone, see same data on tablet, laptop, desktop. |
| **Share via URL** | P2 | Send invoice link via WhatsApp. Recipient views in browser. |

---

## 5. FEATURES: CURRENT VS. TARGET

| Module | Current | Target | Gap | Priority |
|--------|---------|--------|-----|----------|
| Inventory | Cost price only | Cost + selling + WAC + margin + smart reorder | Selling price, WAC, margin, smart reorder | P0 |
| Invoices | Conflated with receipts | Separate + payment tracking + aging + auto-deduction | Separation, payments, aging | P0 |
| CRM | Static records | Auto-segment + credit limits + payment behavior | Segmentation, credit limits | P1 |
| Expenses | Basic recording | Categories + budgets + auto-categorization | Categories, budgets | P0 |
| Dashboard | 4 cards, zeros | Cash + receivables + health score + alerts + demo data | Cash position, receivables, health score, demo data | P0 |
| Reports | Basic summaries | Export + tax + loan readiness + bank templates | Export, loan readiness | P1 |
| Verification | QR + number | Crypto-signed + public site + immutable | Signing, verification site | P1 |
| Web | Works web | Sync status + smart priority + conflict resolution | Sync status, conflicts | P1 |

---

## 6. AI & AUTOMATION ROADMAP (PENDED)

> **Status:** AI and automation features are **pended** (deferred) until core product-market fit is achieved. They are documented here for future reference but are NOT part of the immediate execution plan.
>
> **Trigger for activation:** 500+ active users with 3+ months of consistent data, and explicit user requests for automation.

### Tier 1: Build When Activated (Low Complexity, High Impact)

| Feature | Module | What It Does | AI Layer |
|---------|--------|-------------|----------|
| Smart Reorder Alerts | Inventory | "Reorder by Thursday — 3 left, 8/week velocity" | Velocity calculation + simple prediction |
| Auto-Categorization | Expenses | "FUEL STATION → Transport" | Keyword matching + learning from corrections |
| Business Health Score | Dashboard | 0-100 composite score | Weighted formula on 5 metrics |
| Payment Prediction | Invoices | "67% chance late based on history" | Customer average payment time |
| Auto-Follow-Up | Invoices | Send WhatsApp/SMS at optimal time | Timing based on customer response history |

### Tier 2: Build Later (Medium Complexity)

| Feature | Module | What It Does | AI Layer |
|---------|--------|-------------|----------|
| Cash Flow Forecast | Dashboard | "You'll run low in 3 weeks" | Time-series on 3-6 months of data |
| Anomaly Detection | Expenses | "Transport 3x normal this month" | Statistical outlier on category trends |
| Customer Segmentation | CRM | Auto-tag VIP/Regular/At-Risk/Dormant | RFM clustering (Recency, Frequency, Monetary) |
| Demand Forecasting | Inventory | "You'll sell 200 units next month" | Time-series + seasonality |

### Tier 3: Build Much Later (High Complexity)

| Feature | Module | What It Does | AI Layer |
|---------|--------|-------------|----------|
| Loan Readiness Score | Reports | "Your records qualify for ₦500K" | Classification on record quality |
| Dynamic Pricing | Inventory | "Raise price 5% — demand strong" | Price elasticity model |
| Natural Language Queries | Dashboard | "How much did I make last month?" | LLM + structured query (only if user demand proven) |

### Don't Build (Ever)
- Chatbots
- Voice assistants
- Predictive analytics needing 2+ years of data
- Anything requiring LLM API call per user action

---

## 7. RECEIPT VERIFICATION SYSTEM

### Architecture Principles

| Principle | Implementation |
|-----------|---------------|
| Complete isolation | Separate domain, hosting, database from main app |
| Read-only | No write endpoints. Zero. None. |
| Cryptographic signing | Every receipt signed at creation with HSM/KMS |
| Signature verification | Verification app re-verifies on every request |
| Immutable receipts | Void and reissue, never update or delete |

### Key Management

| Stage | Solution | Cost | When |
|-------|----------|------|------|
| Start | AWS KMS | ~$1/month + $0.03/10K signatures | Now |
| Scale | Cloud HSM | ~$730-1,050/month | 10,000+ daily receipts |
| Enterprise | Dedicated HSM | ~$4,000/month | Bank-grade compliance |

### Verification Site Specs

| Component | Main App | Verification Site |
|-----------|----------|-------------------|
| Domain | app.sprout.ng | verify.sprout.ng |
| Hosting | Vercel/Render | Cloudflare Pages (static) |
| Backend | FastAPI | Cloudflare Workers (read-only) |
| Database | Supabase PostgreSQL | Separate Supabase project or read replica |
| Auth | JWT sessions | None — fully public |
| Write endpoints | Yes | **No. Zero. Nada.** |
| Admin panel | Yes | **No admin panel** |

---

## 8. REVENUE MODEL

### Phase 1: Freemium SaaS (Month 1-12)

| Tier | Price | Features |
|------|-------|----------|
| **Free** | ₦0 | 50 products, 100 invoices/month, basic dashboard, manual cash tracking |
| **Pro** | ₦3,000/month | Unlimited products/invoices, advanced reports, expense budgets, branded invoices, health score |
| **Enterprise** | ₦10,000/month | Multi-location, multi-user roles, API access, priority support |

### Phase 2: B2B Partnerships (Month 12+)

| Partner | What They Get | What You Get |
|---------|--------------|--------------|
| Zenith Bank SME-GMB | Pre-qualified SME borrowers with 6+ months of clean records | Per-lead fee (₦500-2,000) or revenue share |
| Microfinance banks | Digital record verification for loan applicants | Distribution + licensing fee |
| Opay/Paga | Business management layer on payment platform | Transaction data + user base |

### Phase 3: Transaction Revenue (Year 2+)

| Stream | How It Works |
|--------|-------------|
| Invoice payments | 1.5% fee when customer pays via Sprout |
| Expense cards | Virtual cards, interchange fee |
| Insurance | Business insurance partnerships, commission |

### Unit Economics (Year 1)

| Metric | Value |
|--------|-------|
| CAC | ₦500 (WhatsApp, referrals, agent network) |
| ARPU | ₦3,000/month (Pro tier average) |
| LTV | ₦36,000 (12-month retention @ 80%) |
| LTV/CAC | 72x |
| Gross Margin | 85% |

---

## 9. GO-TO-MARKET STRATEGY

### Distribution Channels

| Channel | Strategy | Timeline |
|---------|----------|----------|
| **Word-of-mouth** | Referral program: "Refer a friend, get 1 month free" | Month 1 |
| **WhatsApp Business** | Broadcast updates, onboarding support, payment reminders | Month 1 |
| **Agent network** | Partner with CAC registration agents, market associations | Month 3 |
| **Trade associations** | NASME, NASSI partnerships | Month 6 |
| **Bank partnerships** | Co-branded SME onboarding with Zenith, GTBank | Month 12 |

### User Onboarding Flow

```
Download → "Welcome to Sprout! Let's grow your business."
        → Step 1: Add your first product (demo data shown)
        → Step 2: Create your first invoice (demo data shown)
        → Step 3: Record your first expense (demo data shown)
        → "You're all set! Here's your Business Health Score: 72/100"
        → Dashboard with demo data + toggle "Start with my own data"
```

### Messaging Framework

| Don't Say | Do Say |
|-----------|--------|
| "Accounting software" | "Business growth platform" |
| "Net profit" | "How much you made" |
| "Accounts receivable" | "Money owed to you" |
| "Inventory valuation" | "What your stock is worth" |
| "Financial reporting" | "Records for your bank loan" |

---

## 10. TECHNICAL ARCHITECTURE

### Current Stack

| Layer | Technology | Status |
|-------|-----------|--------|
| Frontend | Flutter (PWA) | ✅ Built |
| Backend | FastAPI | ✅ Built |
| Database | Supabase PostgreSQL | ✅ Built |
| Storage | Supabase Storage | ✅ Built |
| Caching | Redis | ✅ Built |

### Target Additions

| Component | Purpose | Timeline |
|-----------|---------|----------|
| AWS KMS | Receipt cryptographic signing | Month 3 |
| Cloudflare Pages | Static verification site | Month 3 |
| Cloudflare Workers | Read-only verification API | Month 3 |

### Data Model Principles
- All transactions live in cloud PostgreSQL, cached locally for speed
- Receipts are immutable: void and reissue, never update
- Verification DB is read-only, separate from main DB
- All user data encrypted at rest (Supabase default)

---

## 11. EXECUTION ROADMAP

### Sprint 1: Foundation Fixes (Weeks 1-2)

| Ticket | Feature | Acceptance Criteria |
|--------|---------|---------------------|
| 1.1 | Add `selling_price` to products | Field exists, backfilled from cost × 1.2 |
| 1.2 | Add `margin_percent` computed field | Displayed on product card |
| 1.3 | Implement WAC calculation | Accurate COGS on every sale |
| 1.4 | Add expense categories | 8 categories, user can add custom |
| 1.5 | Add monthly budgets | Set per category, track vs. actual |
| 1.6 | Fix dashboard: Cash Position (manual) | Top-left card, manual entry |
| 1.7 | Add "Money Owed to Me" card | Total outstanding + aging |
| 1.8 | Add Business Health Score | 0-100, weighted formula |
| 1.9 | Add "3 Things to Do Today" | Actionable alerts |
| 1.10 | Progressive onboarding with demo data | 3 steps, demo toggle |

**Goal:** New user sees value in 5 minutes. Existing user sees immediate improvements.

---

### Sprint 2: Intelligence Layer (Weeks 3-4)

| Ticket | Feature | Acceptance Criteria |
|--------|---------|---------------------|
| 2.1 | Smart reorder alerts | Velocity-based, not static threshold |
| 2.2 | Auto-categorization v1 | 80% accuracy on common merchants |
| 2.3 | Payment prediction | Average payment time per customer |
| 2.4 | Auto-follow-up for overdue | WhatsApp/SMS template, one-click send |
| 2.5 | Branded invoice templates | Logo upload, color picker, tagline |

**Goal:** Users save 5+ hours/week on manual tasks.

---

### Sprint 3: Verification System (Weeks 5-6)

| Ticket | Feature | Acceptance Criteria |
|--------|---------|---------------------|
| 3.1 | AWS KMS signing key | Key created, never exposed |
| 3.2 | Receipt signature on creation | Every new receipt signed |
| 3.3 | Separate verification DB | Read-only, public-safe fields only |
| 3.4 | Cloudflare Worker API | Verify signature on every request |
| 3.5 | Static verification page | `verify.sprout.ng/[id]`, no login |
| 3.6 | End-to-end test | Create → scan → verify → show details |

**Goal:** Any receipt verifiable by anyone, anywhere, instantly.

---

### Sprint 4: Growth & Polish (Weeks 7-8)

| Ticket | Feature | Acceptance Criteria |
|--------|---------|---------------------|
| 4.1 | Referral program | "Refer a friend, get 1 month free" |
| 4.2 | WhatsApp Business integration | Broadcast, support, reminders |
| 4.3 | Expense receipt photo capture | Camera + gallery, optional OCR |
| 4.4 | Customer segmentation auto-tag | VIP, Regular, At-Risk, Dormant |
| 4.5 | Credit limits | Soft warning, hard stop configurable |

**Goal:** 500 active users, 50 Pro conversions.

---

### Sprint 5: Scale & Optimization (Months 3-6)

| Ticket | Feature | Acceptance Criteria |
|--------|---------|---------------------|
| 5.1 | Loan Readiness Score v1 | Based on operational data (no bank needed) |
| 5.2 | Export formats (Excel/CSV/PDF) | Accountant-ready, bank-friendly |
| 5.3 | Tax tagging | VAT, CIT, PAYE categories |
| 5.4 | Historical comparison | YoY, QoQ, rolling 12-month |
| 5.5 | Multi-user roles (Enterprise) | Owner, Manager, Salesperson permissions |

**Goal:** First bank partnership conversation. 2,000 active users.

---

### AI & Automation Activation (TBD — Pended)

**Trigger:** 500+ active users with 3+ months of consistent data + explicit user requests for automation.

**First AI Features to Activate:**
1. Smart reorder alerts (velocity-based)
2. Auto-categorization (learning from corrections)
3. Business Health Score (weighted formula)
4. Payment prediction (customer history)
5. Auto-follow-up (optimal timing)

---

## 12. SUCCESS METRICS

### Month 1-3: Product-Market Fit

| Metric | Target |
|--------|--------|
| Active users (weekly) | 100 |
| Time to first value | <5 minutes |
| Demo-to-real conversion | >60% |
| Support tickets per user | <0.5 |

### Month 4-6: Retention & Revenue

| Metric | Target |
|--------|--------|
| Active users | 500 |
| Pro conversions | 50 (10%) |
| Monthly churn | <10% |
| Net Promoter Score | >40 |

### Month 7-12: Scale & Partnerships

| Metric | Target |
|--------|--------|
| Active users | 2,000 |
| Pro users | 300 |
| First bank partnership conversation | 1 |
| Monthly recurring revenue | ₦900,000 |

### Year 2: Platform

| Metric | Target |
|--------|--------|
| Active users | 10,000 |
| Pro users | 1,500 |
| Loan applications via Sprout | 100 |
| Loans approved | 30 |
| B2B revenue | 20% of total |

---

## 13. RISK & MITIGATION

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| User churn from empty states | High | High | Demo data, progressive onboarding |
| Price sensitivity in Nigeria | High | Medium | Freemium, B2B subsidization |
| Engineering bottleneck | High | High | Hire senior Flutter dev with $20K |
| Competitive response from global player | Low | High | Move fast, own Nigerian market |
| Slow load on low-end devices | High | High | Service worker caching, lazy loading, image optimization |
| AI features built too early | Medium | Medium | Pended until 500+ users with 3+ months data |
| Verification site compromise | Low | Medium | Read-only, signature verification, separate infra |

---

## 14. APPENDICES

### A. Glossary (Business Language, Not Accounting)

| Don't Use | Do Use |
|-----------|--------|
| Accounts receivable | Money owed to me |
| Accounts payable | Money I owe |
| COGS | What it cost me to sell |
| Gross margin | Profit per sale |
| Net profit | How much I made |
| Inventory valuation | What my stock is worth |
| Depreciation | Wear and tear |
| Equity | What I own |
| Liquidity | Cash I can use now |

### B. Competitive Comparison

| Feature | Sprout | QuickBooks | Wave | Excel |
|---------|--------|-----------|------|-------|
| Price | Freemium | $$$ | Free | Free |
| Inventory | ✅ Built-in | 💰 Add-on | ❌ No | ❌ Manual |
| Web Access | ✅ Any browser | ❌ App only | ❌ App only | ✅ N/A |
| NGN Native | ✅ Yes | ❌ Convert | ❌ Convert | ❌ Manual |
| Loan Ready | ✅ Score | ❌ No | ❌ No | ❌ No |
| Mobile-First | ✅ PWA | ❌ Desktop | ❌ Desktop | ❌ N/A |
| Receipt Verify | ✅ Crypto | ❌ PDF | ❌ PDF | ❌ Paper |

### C. User Survey Questions (To Validate Features)

1. Do you currently check your bank balance daily?
2. What's your biggest pain point in managing your business?
3. How do you currently track who owes you money?
4. Would you pay ₦3,000/month for unlimited invoices, reports, and branded templates?
5. Would you trust an app that shows your profit per product?

### D. Technical Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Costing method | Weighted Average | Simpler than FIFO, IFRS-compliant, smooth margins |
| Bank integration | Pended (Month 12+ optional) | Most users don't need it; focus on core first |
| Receipt signing | AWS KMS | $1/month, sufficient until 10K+ daily receipts |
| Verification hosting | Cloudflare Pages | Static, CDN-backed, zero attack surface |
| AI approach | Pended (rule-based + learning) | No LLM APIs; fast, cheap, explainable; build when user data exists |

### E. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | June 2026 | Product Team | Initial PRD |
| 2.0 | June 2026 | AI Strategist | Consolidated research, added bank integration |
| 3.0 | June 2026 | AI Strategist | **Removed bank integration as core**, **pended AI/automation**, focused on manual-first approach |

**Next Review:** July 2026 or after Sprint 2 completion.

---

> This is your single source of truth. Update it as you ship. Add learnings as you learn. Cross things out when they're done.
>
> Now build. 🌱

# Document Q&A Chatbot — Setup Guide

An AI-powered chatbot that reads your company's documents and answers questions about them — grounded in your actual files, not generic AI knowledge.

> This repository is a **portfolio showcase**. It documents how this system works and how to set it up, but the working n8n workflow file (`.json`) is not included here — it's delivered directly to clients who purchase it via خمسات, مستقل, or my store. If you're interested in this for your business, reach out through one of those platforms.

---

## Table of Contents

1. [What This Does](#1-what-this-does)
2. [Architecture Overview](#2-architecture-overview)
3. [What You'll Need](#3-what-youll-need)
4. [Part A — Google Drive & OAuth Setup](#part-a--google-drive--oauth-setup)
5. [Part B — Google Gemini API Key](#part-b--google-gemini-api-key)
6. [Part C — Supabase Setup](#part-c--supabase-setup)
7. [Part D — Import & Connect in n8n](#part-d--import--connect-in-n8n)
8. [Part E — Activate & Test](#part-e--activate--test)
9. [Troubleshooting](#9-troubleshooting)
10. [Limitations & What's Not Included](#10-limitations--whats-not-included)
11. [Costs to Expect](#11-costs-to-expect)
12. [Data Privacy — Where Your Documents Live](#12-data-privacy--where-your-documents-live)
13. [Success Checklist](#13-success-checklist)
14. [Support](#14-support)

---

## 1. What This Does

You keep your documents in a Google Drive folder. Whenever you add or update a file there, the system automatically:

1. Reads the document
2. Breaks it into small, meaningful chunks
3. Converts each chunk into a searchable format (an "embedding")
4. Stores it in a database

Then, anyone with the chat link can ask questions in plain language, and the AI answers using only the information found in your actual documents — not made-up or generic answers.

---

## 2. Architecture Overview

```
Google Drive (your documents)
        │
        ▼
n8n (automation engine — watches folder, processes files)
        │
        ▼
Supabase (database — stores document content + search index)
        │
        ▼
Google Gemini (AI — reads chunks, writes answers)
        │
        ▼
Chat interface (where you ask questions)
```

Two independent paths run through the same system:
- **Upload path**: Drive → n8n → Supabase (fills the knowledge base)
- **Chat path**: You → n8n → Supabase → Gemini → Answer (uses the knowledge base)

---

## 3. What You'll Need

- A Google account (for Drive + Gemini API)
- A free [Supabase](https://supabase.com) account
- Access to an n8n instance (self-hosted or n8n Cloud)
- The workflow file (`.json`) provided at purchase
- About 30–45 minutes for first-time setup

---

## Part A — Google Drive & OAuth Setup

This system reads files from a Google Drive folder you control. To let n8n access it securely, you'll create your own free Google Cloud project — this is a one-time setup, and it means **you own this connection**, not a third party.

### A1. Create a Google Cloud Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with the Google account you want the chatbot to use
3. Click the project dropdown (top left) → **New Project**
4. Name it anything (e.g. "Document Chatbot") → **Create**

### A2. Enable the Google Drive API

1. In the search bar at the top, type **"Google Drive API"**
2. Click it, then click **Enable**

### A3. Create OAuth Credentials

1. In the left sidebar, go to **APIs & Services → Credentials**
2. Click **Create Credentials → OAuth client ID**
3. If prompted, configure the **OAuth consent screen** first:
   - User type: **External**
   - Fill in app name, your email, and save
   - Under "Test users," add your own email
4. Back in Credentials, choose **Application type: Web application**
5. Under **Authorized redirect URIs**, add your n8n instance's OAuth callback URL (found in n8n when you start creating the Google Drive credential — n8n shows you the exact URL to paste here)
6. Click **Create** — you'll be shown a **Client ID** and **Client Secret**. Copy both somewhere safe.

### A4. Create Your Documents Folder

1. Go to [drive.google.com](https://drive.google.com)
2. Create a new folder (e.g. "Chatbot Documents")
3. This is where you'll add files for the chatbot to learn from

### A5. A Note on the "Unverified App" Screen

Since this is your own personal OAuth app (not a public, Google-verified product), when you sign in you may see a screen saying **"Google hasn't verified this app."** This is expected and safe — click **Advanced → Go to [your app name] (unsafe)** to proceed. This warning exists for all small, personal-use Google apps and does not mean anything is wrong.

---

## Part B — Google Gemini API Key

1. Go to [aistudio.google.com](https://aistudio.google.com)
2. Sign in with your Google account
3. Click **Get API key → Create API key**
4. Copy the key somewhere safe

---

## Part C — Supabase Setup

Supabase is where your document content and search index live. No prior database experience needed — you'll paste one script and click Run.

### C1. Create Your Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in or sign up (free)
2. Click **New Project**
3. Name it, set a database password (save it somewhere safe), pick a region close to you
4. Click **Create new project** — wait 1–2 minutes

### C2. Run the Setup Script

1. In the left sidebar, click **SQL Editor → New query**
2. Open the `supabase_setup.sql` file provided with your purchase
3. Copy its entire contents and paste into the query box
4. Click **Run**
5. You should see **"Success. No rows returned."** — that means it worked

**What this script does, in plain terms:**
- Turns on `pgvector`, a feature that lets Supabase store and search AI "embeddings" (numeric fingerprints of your document chunks)
- Creates a table called `company_documents` — like a spreadsheet with columns for the chunk's text, its metadata, and its embedding
- Creates a search function that the chatbot calls to find the most relevant chunks for any question

**If asked about Row Level Security (RLS):** choose to enable it. This is the secure default — it locks the table so only your backend (via a special key) can access it, and it will not affect how your chatbot works.

### C3. Get Your Supabase Credentials

1. Left sidebar → gear icon (**Project Settings**) → **API**
2. Copy the **Project URL** (looks like `https://xxxxx.supabase.co`)
3. Copy the **Secret key** (not the "Publishable key" — the Secret key is required for full read/write access). Treat this like a password.

---

## Part D — Import & Connect in n8n

### D1. Import the Workflow

1. In n8n, click **Add workflow → Import from File**
2. Select the `.json` file provided with your purchase

### D2. Create Your Credentials

You'll create 3 credentials in n8n, each used once but applied across multiple nodes automatically:

| Credential type | Where to get it | Used in |
|---|---|---|
| Google Drive OAuth2 API | Part A (Client ID + Secret) | 3 nodes |
| Google Gemini (PaLM) Api | Part B (API key) | 3 nodes |
| Supabase API | Part C (Project URL + Secret key) | 2 nodes |

To create each: **Credentials → Add Credential**, search for the type, paste in your values, save.

### D3. Connect Every Node

Open the workflow canvas. Any node labeled **"REPLACE: ..."** needs your credential selected from its dropdown. Click each one, choose the credential you just created.

### D4. Point the Drive Triggers at Your Folder

1. Open **"Google Drive File Created"**
2. Find the **Folder to Watch** field, click it, and select your documents folder from Part A4
3. Repeat for **"Google Drive File Updated"**

---

## Part E — Activate & Test

1. Toggle the workflow to **Active** (top right)
2. Add a test document to your Google Drive folder
3. Wait about a minute (the system checks for new files every minute)
4. In Supabase, go to **Table Editor → company_documents** — you should see new rows appear
5. Open the **"When chat message received"** node and open the chat
6. Ask a question you know the answer to from your test document
7. You should get an accurate, grounded answer

---

## 9. Troubleshooting

**"Table not found in schema cache" right after running the SQL script**
Supabase's API sometimes takes a few seconds to recognize a new table. Wait ~30 seconds and try again.

**"Expected X dimensions, not Y" error**
This means the embedding model produced a different-sized output than the database expects. The provided SQL script is already sized correctly for the embedding model used in this workflow — this shouldn't occur unless the embedding model was changed. If it does, let your developer know.

**"Could not find the function public.match_documents"**
The Supabase search function must be named exactly `match_documents` — this is a fixed requirement of the n8n node itself (it isn't customizable), and the provided SQL script already names it correctly. If you modified the SQL script, make sure this function name wasn't changed.

**Chat says "No documents have been uploaded yet"**
Add a document to your Google Drive folder and wait a minute for it to process before asking questions.

**A node shows a red error icon**
Almost always a missing or incorrect credential. Revisit Part D2–D3.

**Google sign-in shows "unverified app"**
Expected — see Part A5.

---

## 10. Limitations & What's Not Included

- **No bulk upload** — files are processed one at a time as they're added to Drive; there's no built-in tool to import hundreds of existing files at once (this can be added as a separate one-time batch job if needed)
- **Deleting a file from Drive does not remove it from the knowledge base** — outdated information must currently be removed manually from the Supabase table, or as a future enhancement
- **No login/access control on the chat link** — anyone with the link can ask questions; anyone with Drive folder access can add documents. For customer-facing or sensitive use cases, additional access controls can be added
- **Single AI model** — currently powered by Google Gemini; switching to another AI provider (e.g. OpenAI) requires reconfiguring the embedding and chat model nodes
- **Text-based documents only** — works best with PDFs, Word docs, and text files; scanned images or handwriting are not automatically read (OCR is not included)

---

## 11. Costs to Expect

This system runs on free tiers for light use, with these general limits:

- **Supabase free tier**: generous storage/database limits for small-to-medium knowledge bases; paid tier starts if you exceed free limits (check Supabase's current pricing)
- **Google Gemini API**: free tier available with rate limits; cost scales with number of questions asked and documents processed if you exceed free limits
- **n8n**: free if self-hosted (per your existing setup); n8n Cloud has its own pricing if used instead

For a small business with a modest number of documents and moderate daily questions, this is very likely to stay within free tiers. Heavier use (thousands of documents, high daily chat volume) may incur small ongoing costs from Supabase and/or Google.

---

## 12. Data Privacy — Where Your Documents Live

- **Original files**: stay in your own Google Drive — never copied elsewhere
- **Extracted text + search index**: stored in your own Supabase project (a database you control, not a shared/third-party database)
- **Questions and answers**: processed through Google's Gemini API to generate responses; Google's standard API data-handling terms apply
- No data is sent to or stored on the developer's infrastructure — everything lives in accounts you own and control

---

## 13. Success Checklist

- [ ] Google Cloud project created, Drive API enabled, OAuth credentials created
- [ ] Supabase project created, setup script run successfully
- [ ] Gemini API key obtained
- [ ] Workflow imported into n8n
- [ ] All 3 credentials created and connected (no red error icons)
- [ ] Drive folder selected in both trigger nodes
- [ ] Workflow activated
- [ ] Test document uploaded and confirmed in Supabase Table Editor
- [ ] Test question asked in chat and answered correctly

---

## 14. Support

This setup is covered by the support window agreed at purchase (see your خمسات/مستقل order details). If you run into an issue not covered above, reach out with a screenshot of the exact error message for the fastest help.

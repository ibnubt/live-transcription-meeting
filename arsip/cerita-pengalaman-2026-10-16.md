# Story Bank — ONLY for questions about my own experience

USE THIS FILE ONLY when the interviewer explicitly asks about my experience: "tell me about a time…", "describe a situation…", "in your current/previous role…", "what's the largest system you've built?", "have you ever…?", "give me an example from your work", "tell me about yourself", "what was your impact?".
For every other question (how would you design…, how do you handle…, what happens if…, which isolation level…, coding), answer from best practice and DO NOT mention any project, company or number from this file.

Each story has: Facts (what actually happened and my role), Depth (engineering angles I can discuss as my approach; present these as approach, not as past events). Full original notes: arsip/cerita-pengalaman-lengkap.md.

Numbers I can quote:
- 9+ years of experience (since 2016; at PT PLN Icon Plus since Sep 2019); I lead a team of 5 engineers.
- Battery Swapping: piloted with hundreds of stations, now more than 5,000 stations in operation (always say "more than 5,000"; never round it up to 6,000 or any other number); every station sends a heartbeat every 8 seconds → about 625 messages per second, roughly 54 million per day.
- Power Monitoring: device heartbeat every 8 seconds, same as the battery swapping stations.
- AI E-Arsip (document archive RAG): thousands of documents; this is where the OCR reliability fix and the Redis queue happened.
- AI Legal Assistant: the full case corpus of one of Indonesia's highest legal institutions, from its founding until today. Never name the institution; always say "one of Indonesia's highest legal institutions".
- Executive Dashboard: used across all General Affairs divisions at PLN, hundreds of users; 5 General Affairs functions + 1 consolidated executive view.
- AI CCTV Analytics: one edge computing server processes 4 to 8 cameras.
- AI Lab: open to all PLN Group employees.
- NVIDIA H200 GPU infrastructure; a Qwen3-30B request of 44,569 tokens hit a configured 32,768-token context limit.
No other figures are recorded; never invent percentages or before/after numbers.

## Most impressive projects first (by scale and impact)
1. E — Battery Swapping: more than 5,000 stations, about 625 messages per second, end-to-end architecture (hardware to dashboard).
2. K — AI Legal Assistant: full case corpus of one of Indonesia's highest legal institutions, on-premise LLM on NVIDIA H200 for data privacy.
3. I — AI CCTV Analytics: edge inference, one server per 4–8 cameras, scales by adding edge servers.
4. A/B — AI E-Arsip: thousands of documents, Redis queue, per-page OCR quality control.
5. J — AI Lab: open to all PLN Group employees.
Use these for "tell me about yourself", "a project you're proud of", "your biggest impact", "your largest system". The Executive Dashboard (G) is only for stakeholder, ambiguity or product questions.

## Which story for which experience question (pick one I haven't told yet in this conversation)
- "A production incident / something that failed" → A (OCR reliability), E (device/transaction state)
- "A technical decision you made / a trade-off" → B (async queue), K (local LLM for privacy), F (frontend data volume)
- "A design that didn't scale / what would you do differently" → E2 (battery swapping lessons)
- "Your largest or most complex system / a project you're proud of / your biggest impact" → E (more than 5,000 stations), K (legal corpus on H200), I (edge CCTV)
- "Your full stack work / something you owned end to end" → E (end to end, hardware to dashboard), F (Power Monitoring), L (ICONNet)
- "Working with stakeholders / ambiguity" → G (Executive Dashboard), H (energy platforms), M (Step Up Challenge)
- "Leading or mentoring" → N (tech lead), J (AI Lab)
- "Integrating many data sources" → H, D
- "AI in production" → A, C, K, I

## A — AI E-Arsip ingestion reliability: OCR page flags and quality gate
- Facts: In AI E-Arsip, our document archive RAG platform with thousands of documents, OCR failed often because compute resources were limited (embedding was not the failing step). Whole-document pass/fail hid where processing broke, especially in multi-page files. I added per-page success/failure flags and a document-level quality threshold that decides whether a document may enter the knowledge base. Result: we could see exactly which pages failed, and incomplete documents were flagged instead of silently polluting search.
- Depth: treat partial success as a first-class state; make failures visible per unit of work; quality gates before data enters a shared store; bound OCR concurrency to available resources; metrics like failed pages per document and share of documents blocked by the gate; next step: targeted re-processing of failed pages only.

## B — AI E-Arsip: async document pipeline with a Redis queue
- Facts: In AI E-Arsip, document processing (OCR, chunking, embedding) runs through a Redis queue instead of inside API requests. I worked on the platform architecture and the OCR status and quality controls.
- Depth (my design approach): queues give at-least-once delivery, so workers must be safe to re-run, using document ID plus page number as the unique key; retries with exponential backoff only for transient errors; a dead-letter queue for poison documents; an explicit job state machine (queued → processing → done / partial / failed); ack or visibility timeouts so crashed workers release jobs; limit worker concurrency to GPU/CPU capacity as backpressure; track queue depth and per-stage latency. Trade-off: async isolates heavy work and keeps APIs responsive, but adds state tracking, harder debugging and eventual consistency for the user.

## C — LLM serving and GPU capacity (H200)
- Facts: I planned NVIDIA H200 infrastructure for on-premise LLMs and evaluated vLLM and SGLang with models like Qwen2.5-32B and Qwen3-30B for Indonesian-language RAG. Real incident: a 44,569-token request hit the 32,768-token configured context limit, which taught us to control prompt budgets and validate effective context.
- Depth: separate answer quality from serving performance; measure time to first token, tokens per second and p95 latency under realistic RAG prompts; data parallelism for more concurrent users when the model fits one replica, tensor parallelism when it doesn't fit one GPU, pipeline parallelism across nodes; choose the smallest model that meets the quality bar; ramp load until p95 or errors cross the target.

## D — Event-driven microservices and high-volume data pipelines
- Facts: At PLN Icon Plus I architect backend microservices and high-volume data pipelines using REST APIs, MQTT and Kafka, with containerized deployment, for IoT and monitoring platforms.
- Depth: MQTT at the device edge (QoS levels, retained state), Kafka as the durable backbone; partition by device or station ID to keep ordering per device; scale with consumer groups; consumers that are safe to retry, with a unique key per message, because a message can arrive twice; replay from Kafka offsets to recover or backfill; schema versioning between producers and consumers; consumer lag as the key health metric; backpressure instead of dropping data.

## E — Battery Swapping Station: device state and transactions
- Facts: As solution architect and researcher, I built the end-to-end platform with the team: hardware and firmware communication, backend services, operational dashboard, real-time station synchronization, battery health monitoring and user transactions. We piloted with hundreds of stations and it now runs more than 5,000 stations, each sending a heartbeat every 8 seconds (about 625 messages per second). I modeled each swap as a state machine (requested → slot unlocked → battery swapped → confirmed) and put a unique request key on every transaction so a retried request never charges twice.
- Depth (my design approach): the device is the truth for physical state, the backend is the truth for the transaction; timeouts plus a reconciliation job for lost device messages; design for stations going offline and syncing later.

## E2 — Battery Swapping: lessons learned and the design I'd use now
- Facts: Our first ingestion design was simpler and not optimal for growth from a pilot of hundreds of stations to more than 5,000. Present everything below as what I learned and how I would design it now ("If I rebuilt it today…", "The design I recommend now…"), never as already built.
- Telemetry path: stations publish heartbeats and state over MQTT (TLS with per-station credentials, topic ACLs, QoS 1). The MQTT broker cluster bridges into Kafka, keyed by station ID so each station's messages stay in order. Consumer groups scale horizontally. One consumer keeps the latest state per station in Redis for the live dashboard; another writes history to a time-series store with rollups (raw → 1-minute → hourly).
- Load: about 625 heartbeats per second is modest for Kafka, so the design has roughly 10x headroom; the real risk is bursts when thousands of stations reconnect at once, so stations reconnect with random jitter and Kafka absorbs the burst while consumers catch up.
- Offline detection: MQTT last-will message plus a heartbeat timeout (for example, three missed heartbeats, about 24 seconds) marks a station offline; on reconnect the station sends a full state snapshot and the backend reconciles.
- Transaction path, kept separate from telemetry: a direct API call with a unique request key per transaction; the swap state machine is stored in PostgreSQL with transactions and optimistic locking; commands go to the station over MQTT with a correlation ID and must be acknowledged; no ack within the timeout → a reconciliation job checks the real station state. Transaction events leave through an outbox table, so the database and Kafka never disagree.
- Observability: consumer lag, connected stations, messages per second, offline count, p95 command round-trip time, failed or reconciled swaps.
- Lesson: separate high-volume telemetry from low-volume, high-value transactions; they need different consistency and scaling.

## F — Power Monitoring System: React + Express, high-frequency data
- Facts: As full stack and IoT engineer, I built a React frontend and Express.js backend that visualize high-frequency electrical data for proactive load monitoring. Devices send a heartbeat every 8 seconds. I aggregate and downsample on the server so the browser only gets what the chart can show, and I push updates to the browser instead of heavy polling.
- Depth: throttle re-renders and window the chart data; keep raw data for drill-down; time-series friendly storage and indexes.

## G — Executive Dashboard, General Affairs PLN Head Office (2026)
- Facts: As solution architect and developer, I designed and built centralized monitoring for 5 General Affairs functions plus 1 consolidated executive view: architecture, data structures, cross-functional KPIs, drill-down views and monitoring workflows. I worked with business stakeholders to turn operational requirements into clear metrics. It is used across all General Affairs divisions at PLN, by hundreds of people. The hard part was one consistent view across departments, not the charts.
- Depth: agree on KPI definitions before building; one data contract per function; pre-aggregate for fast executive views with drill-down to detail; role-based access; scaffold functions incrementally while the first one goes live.

## H — Energy platforms: Smart & Green Building (2026) and HI+ Energy Dashboard (2021)
- Facts: Smart & Green Building: as solution architect and developer, I integrated solar PV and IoT building data into energy performance, efficiency indicators and estimated avoided carbon; I defined the flow from field devices to data services, calculations and the dashboard. HI+ Energy (full stack developer): energy monitoring, billing transparency, carbon footprint, green energy engagement.
- Depth: a canonical data model with consistent units; one ingestion adapter per source; data quality checks at ingestion; a calculation layer separate from presentation so formulas can change safely.

## I — AI CCTV Analytics for PLN (2026)
- Facts: As solution architect, I designed the architecture of an AI CCTV analytics platform: facial recognition, crowd detection, restricted-area intrusion and configurable analytics, with integration, processing, infrastructure and dashboard requirements for scalable, centralized monitoring. Inference runs on edge computing servers; one server processes 4 to 8 cameras, so capacity scales by adding edge servers.
- Depth: edge inference saves bandwidth and keeps raw video local, at the cost of managing many edge nodes; stream processing per camera; event store for detections; alert deduplication and cooldowns; privacy and access control for face data.

## J — AI Lab PLN Group (2025)
- Facts: As solution architect and technical lead, I led an AI experimentation lab for PLN Group employees: a modular environment with safety hazard detection, enterprise chatbot experiments and an interactive terminal playground, plus workshop enablement and technical standards. It is open to all PLN Group employees.
- Depth: modular, isolated environments so use cases don't break each other; standards that let non-experts experiment safely.

## K — AI PLN Mobile RAG assistant (2025), AI Legal Assistant (2024) and AI E-Arsip (2024)
- Facts: I led a RAG customer service assistant integrated with the PLN Mobile app (AI engine, retrieval layer, mobile backend). The AI Legal Assistant does semantic search over the full case corpus of one of Indonesia's highest legal institutions, from its founding until today; the data arrives already processed into text, so there is no OCR in that pipeline. I defined a local LLM on NVIDIA H200 because of data privacy. AI E-Arsip turned a static archive of thousands of documents into a searchable knowledge platform (chunking, embeddings, vector retrieval).
- Never name the legal institution.
- Depth: trade-off of local LLM versus cloud API: privacy and control versus capacity planning and operations cost; clean API boundary between the AI service and the app backend; for a long legal corpus, chunk by legal structure (case, section, verdict) and keep citations to the source case so answers are traceable.

## L — ICONNet Website and Backoffice (2021)
- Facts: As full stack developer, I built the customer-facing website and the internal backoffice for customer registration and service workflows.
- Depth: start from the customer journey; make the handoff between customer app and operations reliable; validation and status tracking end to end.

## M — Step Up Challenge PLN (2026)
- Facts: As solution architect and developer, I designed and built a gamified employee platform for PLN General Affairs to encourage stair use and reduce elevator load: event workflow, participation mechanism, progress tracking, leaderboard and gamification.
- Depth: turning a business campaign into product rules; fairness and anti-cheating in scoring; simple UX for broad adoption.

## N — Technical leadership
- Facts: Senior Software Engineer, Solution Architect and Technical Lead at PT PLN Icon Plus since Sep 2019. I lead a team of 5 engineers. I mentor engineers, run code reviews, define technical standards, and coordinate stakeholders, developers, infrastructure teams and users from requirements to deployment, while staying hands-on.
- Depth: explain the why behind architecture choices; review for risk, not style; standards as defaults with escape hatches; enable the team rather than decide everything.

## Stack
JavaScript, TypeScript, React, Vue, Node.js, Express.js, NestJS, Python, SQL, REST APIs, microservices, MQTT, Kafka, Redis, Docker, CI/CD, Git, Linux, AWS, GCP, on-premise servers, NVIDIA H200; RAG: OCR, chunking, embeddings, vector databases (Milvus), PostgreSQL, MinIO, vLLM.

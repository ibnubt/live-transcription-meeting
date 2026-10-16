# Experience Story Bank — Full-Stack, AI Systems, IoT & Energy Platforms (Interview)

> Purpose: factual story bank to help answer Senior Full Stack Engineer interviews **selecting the most relevant real engineering experience across AI, full-stack products, IoT, and energy systems**. Supplement the CV rather than replace it.
> Confidence labels: **Confirmed** = supplied in CV or directly clarified by candidate; **Needs validation** = not yet established. Never present hypothetical implementations as past production facts.
> Interview responses: first-person conversational English; 50–90 words ordinarily; directly answer the question.

## Agent selection rules

- **Do not over-prioritize AI.** Choose the project with the strongest factual match to the exact question: AI for OCR/RAG/GPU issues; Executive Dashboard for stakeholder alignment and product ownership; energy/EMS for complex data integrations; Power Monitoring for React/Node.js; Battery Swapping for device state and operational transactions.
- Prioritize **OCR page-level failure flagging + document quality threshold** for real incidents and debugging; **Redis document queue** for asynchronous backend architecture; **RAG retrieval and GPU inference** for performance and distributed-systems discussions, without manufacturing benchmarks.
- Tie the AI example back to ordinary software-engineering fundamentals: worker isolation, bounded resources, job state, API responsiveness, consistency, observability, and maintainability.
- Treat full-stack, IoT, energy, and AI projects as equally valid stories. Use Executive Dashboard, React/Express Power Monitoring, HI+ Energy/EMS, Smart & Green Building, and ICONNet for frontend, APIs, customer workflows, integration and end-to-end delivery. Avoid repeatedly choosing the same AI story.
- Do not claim embedding failed; the user explicitly said the real repeated failures were in **OCR because of resource limits**.
- **Confirmed:** Redis is used for document queuing; page-by-page OCR status flags and a document quality threshold were implemented. **Not established:** Redis queue framework, retry semantics, idempotency strategy, exact threshold value, benchmark improvements, team size, or specific AI incident timeline. Do not assert them as historical facts.
- A high-level architecture component in the background (PostgreSQL, MinIO, Milvus, vLLM, NVIDIA H200) does **not** prove it was involved in a particular failure fix. Distinguish system context from firsthand changes.

## Preferred interview topic mapping

| Interview question | Primary real story | Angle |
|---|---|---|
| Production incident / root cause | OCR failure | Limited resources; page-level failure visibility; quality gate |
| Technical decision / trade-offs | Redis queue + quality gate | Async workload isolation and reliability versus complexity |
| Scale / performance | LLM Inference Performance Engineering + AI document pipeline | Framework selection, Bahasa Indonesia evaluation, DP/TP/PP, stress-test criteria; discuss measured results only if confirmed |
| Reliability / retries / duplicate jobs | Redis queue and OCR status | Explain what was actually implemented, avoid implying unconfirmed retries/upserts |
| Backend APIs / system design | AI service integration | Processing separation and service boundaries |
| Full-stack ownership / React | Power Monitoring / Executive Dashboard | Concrete user-facing work, React/Express only where established |
| Leadership / collaboration | Executive Dashboard, AI Lab and technical leadership | Architecture, implementation, stakeholder communication and mentoring without invented specifics |
| Multi-source integration / energy domain | HI+ Energy/EMS + Smart & Green Building | Energy usage, PV, IoT, billing, environmental metrics and dashboard usability |
| Operational product integration | Battery Swapping Station | Device telemetry, station state, transactions and dashboard integration |

## Story 1 — Enterprise RAG: OCR Failures and Page-Level Quality Control

**Interview angles:** actual production problem; root cause; incident response; fault isolation; prevention; data quality.

- **Context / problem (Confirmed directly by candidate):** Document OCR frequently failed because compute resources were inadequate. Whole-document success/failure wasn't sufficiently informative, particularly for multi-page inputs. Candidate explicitly stated embedding was **not** the failing step.
- **Diagnosis (Confirmed):** Resource limitations impacted OCR; processing completeness and resulting knowledge quality were concerns. **Precise memory/GPU utilization, error codes and incident timeline: Needs validation.**
- **Actions (Confirmed):** Added success/failure flagging for individual pages; defined a document-level quality threshold determining whether a document was acceptable for entry into the knowledge base.
- **Technology context (Confirmed across user discussion):** Redis for document queue; OCR in RAG ingestion; broader platform uses PostgreSQL, MinIO, Milvus, NVIDIA H200 infrastructure and AI services. **Do not claim each storage service was specifically used to implement page flags or thresholds without validation.**
- **Outcome (Confirmed at design/functional level):** Better visibility and control over incomplete OCR results; low-quality documents could be flagged rather than silently entering knowledge. **Do not claim OCR crashes stopped, throughput improved by X%, or automatic page-level retries were implemented.**
- **Short English narrative:** "A real reliability issue I dealt with was OCR failing on some pages because our processing resources were limited. Rather than treating the entire document as one success-or-failure unit, I added page-level status flags so we could see exactly where the process broke down. I also introduced a document-level quality threshold before content could enter our RAG knowledge base. That didn't magically eliminate resource failures, but it improved fault visibility and prevented incomplete processing from becoming a data-quality problem."
- **Follow-up details needed:** flag schema; threshold definition and numeric value; how many pages or documents were affected; how failed pages were recovered; observability/logging; before/after acceptance or failure rate.

## Story 2 — Enterprise RAG: Redis Queue and Asynchronous Processing

**Interview angles:** architecture decision; throughput vs reliability; API responsiveness; failure isolation.

- **Context (Confirmed):** RAG ingestion involved OCR, chunking and embeddings; processing large documents is resource intensive.
- **Architecture (Confirmed directly by candidate):** Redis was used as a queue for document processing.
- **Trade-offs (General engineering rationale, not a documented historical decision):** Synchronous API processing is simpler operationally but risks tying long tasks to request lifetimes; asynchronous queues improve workload separation and resilience but add complexity in observability, job ownership, state management and retries.
- **Personal ownership:** Candidate worked on platform architecture and OCR status/quality controls. **Who specifically chose Redis and whether synchronous processing was genuinely evaluated before deployment: Needs validation.**
- **Outcome:** Document work could be managed through queue-based processing; **do not assert specific throughput or API latency improvement**.
- **Short English narrative:** "On our RAG platform, we used Redis to queue document processing jobs instead of treating long-running OCR and embedding work like a normal short API request. The benefit was clearer separation between user-facing operations and heavier processing workloads. The trade-off is that background processing needs careful state tracking and failure handling. In practice, I focused particularly on page-level OCR statuses and document acceptance thresholds, so the pipeline could make reliable decisions even when processing resources were constrained."
- **Follow-up details needed:** BullMQ vs Redis Streams vs custom implementation; worker concurrency; actual retry mechanics; acknowledgment/visibility timeout; duplicate prevention; dead-letter handling; queue-depth/processing metrics.

## Story 3 — Enterprise RAG: Retrieval and GPU Inference Performance

**Interview angles:** scaling, bottleneck investigation, platform architecture, AI/backend integration.

- **Context (Confirmed):** Designed or led enterprise RAG systems using OCR, chunking, embeddings, vector retrieval and local LLMs, with NVIDIA H200 GPU infrastructure planning; hands-on AI engineering recently. Previous discussions cover Milvus, Redis, PostgreSQL, MinIO, and vLLM serving.
- **Engineering decisions (Confirmed broadly):** Considered processing-stage architecture and retrieval design, integration of backend services, inference infrastructure and capacity.
- **Do not invent:** A specific measured regression, concrete optimization result, concurrency benchmark, GPU allocation improvement or production fix unless separately confirmed. **Embedding failure is expressly not a real incident in the previously discussed pipeline.**
- **Short English narrative:** "A more recent part of my engineering work has been optimizing the design of enterprise RAG services. These aren't just model problems: document ingestion, retrieval, APIs, and GPU inference all affect end-to-end performance. I've worked on architecture involving vector search, caching, and H200-based inference infrastructure. I try to look at the complete request path and separate processing bottlenecks from user-facing latency. I would only quote performance improvements when I have benchmark results to support them."
- **Follow-up details needed:** actual model and serving stack per project; baseline vs result (p50/p95 latency, throughput, tokens/sec, concurrent users); retrieval accuracy metrics; inference optimizations personally shipped.

## Story 12 — LLM Inference Performance Engineering: Serving Framework, Indonesian Model Evaluation & Multi-GPU Scaling

**Interview angles:** hands-on AI infrastructure research; technical judgment; benchmarking; GPU performance; model-quality versus latency; stress testing; production readiness.

### Situation and ownership

- **Established background:** Candidate worked hands-on with enterprise RAG/LLM applications, local inference systems, H200 GPU infrastructure, and explored **vLLM and SGLang**. Previous technical discussions include Qwen2.5-32B, Qwen3-30B, serving limitations and model context behavior.
- **Focus of this research story:** Identify a model-and-serving configuration that delivers acceptable **Bahasa Indonesia answer quality** and predictable response performance under realistic enterprise RAG workloads. This is a *research/evaluation workstream*, not evidence of one measured production win.
- **Important evidence boundary:** Neither a complete head-to-head benchmark nor measured winning DP/TP/PP settings, token-per-second improvements, p95 latency, concurrency capacity or Indonesian accuracy scores were provided. The evaluation matrix and conclusions below are **recommended engineering methodology and hypotheses**, not verified past results. Do not say “I achieved X% faster inference” without data.

### A. Serving framework research — vLLM vs SGLang

**Research question:** Which framework offers the best balance of effective throughput, TTFT, token streaming responsiveness, KV-cache management, deployment simplicity, and stability for the selected LLM and hardware?

| Dimension | What to compare | Interpretation |
|---|---|---|
| Core inference | Model support, quantization, batching, memory footprint | Model must run reliably before tuning speed |
| User responsiveness | TTFT p50/p95, ITL/TPOT p50/p95, end-to-end p95 | A fast aggregate throughput can still feel slow to end users |
| Capacity | Requests/sec, output tokens/sec, sustainable concurrent sessions | Test at the same prompt and output lengths |
| Long context | KV-cache growth, prefix reuse, OOM behavior | RAG workloads often have large and variable contexts |
| Reliability | Timeout/error rate, queue behavior, worker health/restarts | Peak throughput is not production readiness |
| Operations | Configuration, metrics, deployment effort, upgrade compatibility | Simpler operations may beat marginal speed gains |

**Engineering conclusion (conditional):** Keep vLLM as a strong baseline because of its mature serving features and distributed-parallelism support; benchmark SGLang using **identical models, precisions, prompts and load profiles**. Select the framework only after comparing quality-preserving latency, throughput and operational stability. Neither framework is universally fastest. See official benchmark guidance: https://docs.sglang.ai/developer_guide/bench_serving and scaling docs: https://docs.vllm.ai/en/stable/serving/parallelism_scaling/ .

### B. Model selection with Bahasa Indonesia evaluation

**Model candidates to compare (from known project discussions, not an exhaustive current leaderboard):** Qwen2.5-32B and Qwen3-30B, with other models introduced only if available/licensed for deployment. Keep embedding-model evaluation separate from generation-model evaluation.

**Evaluation design:** Build a held-out **Indonesian** enterprise-style set: factual Q&A, long-document retrieval, legal/technical terminology, ambiguous questions, multi-hop reasoning, instructions requiring citations, and requests where the correct answer is abstention. Include natural Indonesian, formal Bahasa Indonesia and mixed Indonesian-English terminology. Evaluate with same retrieved context, prompt template, decoding settings and context budget.

- **Quality:** grounded factual correctness, evidence/citation faithfulness, completeness, Indonesian instruction following, abstention on missing information; track error categories manually on sampled cases.
- **Performance:** TTFT, output tokens/sec, end-to-end latency and GPU memory consumption under short and long contexts.
- **Trade-off:** A smaller/faster model is not automatically better if it hallucinates more or fails Indonesian-domain tasks; a larger model is not automatically better if it breaches latency/concurrency requirements.
- **Known anecdote:** A Qwen3-30B request exceeded a 32,768-token configured context limit (44,569 requested tokens). This illustrates the need for effective-context validation and controlled prompt budgets; it is **not** evidence that the model is generally inferior or that a wider context is always achievable.

**Engineering conclusion (conditional):** Choose the **smallest model meeting a predefined Indonesian task-quality threshold and p95 latency target**, not the model with the highest parameter count. Keep published benchmark scores separate from real evaluations on the organization's tasks. **No verified winning model or quality percentages are available yet.**

### C. GPU scaling research — DP / TP / PP

| Strategy | Purpose | Main benefit | Main cost / trade-off | Decision heuristic |
|---|---|---|---|---|
| **DP — Data Parallelism** | Replicate model on separate GPU sets to handle independent requests | Scale throughput and concurrency | Replicated model memory, load balancing, independent KV caches | Favor when the model fits per replica and user concurrency is the bottleneck |
| **TP — Tensor Parallelism** | Shard layers/tensors across GPUs | Fit larger models and parallelize computation | Collective communication overhead, GPU-interconnect dependence | Favor when single-GPU memory is insufficient and fast local interconnect is available |
| **PP — Pipeline Parallelism** | Split model layers into stages across GPUs or nodes | Fit model across stages/nodes | Pipeline bubbles, schedule complexity; single-request latency may suffer | Consider when model distribution requires stages or multi-node topology makes it suitable |

**Experiment design:** Keep total GPU budget fixed and compare feasible layouts (e.g. 1 replica at TP=2 versus 2 replicas at TP=1 **only if the model fits in both layouts**). For cross-node studies test PP with actual interconnect topology. Record p50/p95 TTFT/ITL, throughput, max stable concurrency, OOMs, GPU memory, utilization and request error rate. Do not assume all TP/PP/DP combinations are feasible or efficient for a given model.

**Engineering conclusion (conditional):** **DP for aggregate request capacity, TP for model-size/memory and intra-node compute distribution, PP when model staging across devices/nodes is warranted.** Determine the actual best configuration empirically; more GPUs or a larger TP number do **not** guarantee better single-request latency. Official references: https://docs.vllm.ai/en/stable/serving/parallelism_scaling/ and https://docs.vllm.ai/en/latest/serving/data_parallel_deployment/ .

### D. Load test and stress test methodology

1. **Baseline:** Fix model revision, framework version, GPU type/count, precision, prompt template, decoding parameters and GPU occupancy.
2. **Represent real traffic:** Short queries, long RAG contexts, and varied output lengths; isolated cold-start and warm-cache tests.
3. **Ramp up:** Increase concurrent users and arrival rates in steps until p95 latency, timeout rate, queue backlog, or memory crosses the agreed SLO.
4. **Observe:** TTFT, ITL/TPOT, end-to-end latency, requests/sec, input/output tokens/sec, GPU memory/utilization, KV-cache pressure, failures, OOM, and recovery behavior.
5. **Soak and fault test:** Sustained load; burst traffic; worker restart and temporary downstream unavailability, **only if actually performed**.
6. **Compare fairly:** Repeat runs and report a configuration matrix; an average tokens/sec number by itself is insufficient.

**Engineering conclusion:** The production-ready configuration is the **highest sustainable throughput while keeping quality, p95 latency, error rate and GPU utilization within acceptable limits**. Peak synthetic throughput should not be presented as proven production capacity.

### E. Interview narrative — short, credible English (70–100 words)

"One area I've been working on is LLM inference performance for our on-premise AI platforms. The challenge isn't just getting a model to run on H200 GPUs; it's finding the right balance between Indonesian-language answer quality, latency, and concurrent users. I've explored serving options such as vLLM and SGLang, along with how data, tensor, and pipeline parallelism affect GPU usage. My approach is to benchmark realistic RAG prompts, measure time to first token, throughput and tail latency, and evaluate answer quality separately. I prefer choosing the simplest configuration that consistently meets both quality and performance requirements."

### F. Agent answer guardrails

- **Can say:** involved in research/evaluation of serving frameworks, model quality, inference performance, H200 platform and DP/TP/PP trade-offs, where supported by prior discussion.
- **Cannot claim without candidate confirmation:** which framework won, exact DP/TP/PP settings actually deployed, model rankings for Bahasa Indonesia, conducted stress/soak tests, concrete measured bottlenecks, any percentage of improvement or specific numbers of users supported.
- If the interviewer asks "What were your results?", give the decision criteria and **state that specific benchmark figures are not available in the present knowledge**, rather than invent metrics. Ask candidate for actual experiment artifacts to make this story evidence-rich.

**Benchmark evidence to add:** tested framework versions; exact model revisions; model quantization; hardware allocation; DP/TP/PP matrix; Indonesian evaluation dataset and scoring rubric; quality scores; max output lengths; TTFT p50/p95; ITL p50/p95; tokens/s; stable concurrency; OOM and error rates; date of trials; winning deployment configuration and reason.

---

## Story 4 — Technical Leadership: Architecture, Reviews, Mentoring

**Interview angles:** mentoring; disagreement; ownership; technical standards; leading without abandoning coding.

- **Context (Confirmed):** Senior Software Engineer / Solution Architect / Technical Lead at PLN Icon Plus since Sep 2019; works with multidisciplinary teams and stakeholders.
- **Actions (Confirmed):** Mentors engineers, conducts code reviews, defines technical standards, coordinates requirements to deployment, and works on complex backend architecture and AI integration.
- **Outcome (Confirmed at responsibility level):** Supported software quality, scalability, maintainability and coordinated delivery. **No team size or quantitative mentoring outcome documented.**
- **Short English narrative:** "As my responsibilities grew, I started contributing more to system architecture, code reviews, and mentoring. I still prefer to stay close to implementation because it helps me make practical technical decisions. When working with a team, I try to make the reasoning behind an architectural choice clear, encourage constructive reviews, and avoid unnecessary complexity. To me, technical leadership is about enabling the team to deliver reliable software, not just making all the decisions myself."
- **Follow-up details needed:** specific mentoring situation, team size and roles, exact disagreement and resolution, hard deadline and scope negotiation, measurable improvement.

---

## Additional stack inventory (global experience, not project-specific proof)

**Confirmed in CV or candidate statements:** JavaScript, TypeScript, React, Vue, Node.js, Express.js, NestJS, Python, SQL, REST APIs, microservices, Docker, CI/CD, Git, Linux, AWS, GCP, MQTT, Kafka, NVIDIA H200; Redis document queue; page-level OCR flagging; document quality thresholds. Broader prior platform discussions include PostgreSQL, Redis, Milvus, MinIO and vLLM.

**Important distinction:** NestJS is on the CV as a skill, but no concrete NestJS project was linked to it in the provided CV. Do not attach it to Executive Dashboard or Power Monitoring without additional evidence.

### Missing evidence intake checklist

| Area | Fill with verifiable details |
|---|---|
| Executive Dashboard | frontend / backend / database; user count; project duration; API ownership |
| RAG OCR | page status values; document quality threshold number; failure logs; real recovery/retry behavior; before/after measures |
| Redis queue | BullMQ / Streams / custom; worker concurrency; retry and dedupe mechanisms |
| AI performance | model / serving version; latency p50/p95; throughput; GPU utilization; before/after comparisons |
| Full-stack testing | Jest / Vitest / Cypress / Playwright / integration testing actually used |
| Persistence & caching | PostgreSQL / MySQL / Redis usage per project; indexing and transaction cases actually solved |
| Team / deadlines | team size; a genuinely difficult delivery date; concrete dispute and resolution |
| Outcomes | adoption, uptime, number of users, reduced failures, reduced processing time, all supported by evidence |

## Agent rules for behavioral questions

1. Choose **one** best-fit real story, not three weak ones.
2. Briefly answer: **situation → personal action → why that approach → real outcome**.
3. Prefer 50–90 words, up to 120 only when technically necessary.
4. Never present a hypothetical failure as something experienced in production.
5. Never fabricate numeric metrics, team size, tools or individual ownership.
6. Distinguish **implemented**, **designed**, **proposed**, and **would do**.
7. If a question requests specifics absent from this bank, answer what is confirmed and explicitly avoid the unsupported detail; ask candidate for more evidence when appropriate.
8. Vary stories to fit each question. Prioritize full-stack examples for product questions and AI stories for reliability/performance questions.

## Story 5 — Executive Dashboard PLN: End-to-End Product & Stakeholder Ownership

**Interview angles:** personally owned feature; full stack; stakeholder communication; architecture; translating ambiguity into software.

- **Context / problem (Confirmed):** Management needed a centralized overview across five General Affairs functions plus one consolidated executive view. Operational data and indicators needed to be translated into useful management dashboards.
- **Personal ownership (Confirmed):** Solution Architect and Developer; designed and developed the dashboard; defined the architecture, data visualization, cross-functional indicators, drill-down views, and monitoring workflows; collaborated with business stakeholders to structure metrics and data.
- **Actions (Confirmed):** Worked from business requirements to dashboard and data architecture; designed KPI presentation and drill-down; integrated information from different business functions through application workflows.
- **Technologies:** Dashboard/API integration is supported. **Exact frontend framework, backend framework, database, hosting, caching, testing tools, and deployment details for THIS project: Needs validation.** Do not assert React/NestJS specifically for this project without confirmation.
- **Outcome (Confirmed):** Delivered a centralized executive monitoring solution / management decision-support dashboard. **No quantified time saving or performance improvement established.**
- **Trade-off / challenge:** Harmonizing complex cross-department requirements into one usable view is supported; do not invent a production outage or a dispute.
- **Short English narrative:** "One project I owned was an executive dashboard for PLN. The challenge was bringing several General Affairs functions into one management view without overwhelming users with disconnected reports. I worked across requirements, dashboard architecture, data structures, visualization, and integration, including KPI tracking and drill-down workflows. The most important part wasn't just building charts—it was making the data consistent and useful for decision-making."
- **Follow-up details needed:** frontend/backend/database names; specific APIs written personally; team size; production users; query/latency figures; challenging stakeholder disagreement and resolution.

## Story 6 — Power Monitoring System: React + Express Full-Stack Development

**Interview angles:** specific feature owned; React, Node.js, APIs; IoT data; end-to-end product development.

- **Context (Confirmed from CV):** A power-monitoring product visualized high-frequency electrical data and supported proactive load monitoring.
- **Personal ownership (Confirmed):** Full Stack and IoT Engineer; developed a full-stack dashboard.
- **Stack (Confirmed):** React frontend and Express.js backend (Node.js ecosystem).
- **Outcome (Confirmed):** Users could visualize electrical data in the dashboard for load monitoring.
- **Potential complexity (Needs validation):** Exact ingestion frequency, persistence choice, API endpoints, caching, charts, alerting, throughput or incident remediation.
- **Short English narrative:** "One clear full-stack example is a Power Monitoring System where I built a React dashboard with an Express.js backend. The goal was to turn high-frequency electrical measurements into something operations teams could understand and use for proactive load monitoring. I worked on the application side across visualization and the services connecting it to monitoring data. It was a good example of why frontend experience matters alongside API and data-flow design."
- **Follow-up details needed:** exact endpoints/CRUD; data transport; database; deployment; testing; production scale; state management; performance outcomes.

## Story 7 — Battery Swapping Station: Device State and Transaction Integration

**Interview angles:** distributed systems; physical-device integration; consistency; end-to-end systems ownership.

- **Context (Confirmed from CV):** An end-to-end battery swapping station platform spanning firmware/hardware communication, backend services, operational dashboards, real-time station synchronization, battery health monitoring and user transaction processing.
- **Personal ownership (Confirmed):** Solution Architect and Researcher; built the end-to-end platform with the team.
- **Technical complexity (Confirmed):** System state spans physical devices, backend services, and dashboards, requiring coordination and synchronization.
- **Not confirmed:** A particular duplicate-payment incident, idempotency key design, transaction locks, database transaction boundaries, retries, broker semantics, or compensation workflow. Do NOT turn such patterns into accomplishments without candidate verification.
- **Short English narrative:** "One interesting system I worked on was a battery swapping platform that connected physical stations to backend services and an operational dashboard. We had to coordinate device communication, battery status, real-time synchronization, and user transactions. That made me think carefully about the boundary between software state and what was actually happening on a physical device. It was a valuable experience in integration-heavy backend architecture and reliability."
- **Follow-up details needed:** database, messaging protocol, exact consistency problem, retry and dedupe strategies actually implemented, measurable result.

## Story 8 — ICONNet Website and Backoffice: Customer Workflow Ownership

**Interview angles:** SaaS-like user journeys; frontend/backend integration; business feature delivery.

- **Context (Confirmed):** Customer-facing website and internal backoffice to support customer registration and service workflows.
- **Personal ownership (Confirmed):** Full Stack Developer; built customer-facing and administrative applications.
- **Outcome (Confirmed):** Applications supported registration and related service processes.
- **Not confirmed:** Exact frameworks for THIS project, database choice, scale, a specific bug, a duplicate-registration incident, transaction handling, or KPI improvement.
- **Short English narrative:** "Earlier in my career, I worked on ICONNet's customer-facing website and internal backoffice. The important part was connecting the customer registration journey with the operational workflows behind it. I enjoyed working across the application rather than treating frontend and backend as separate concerns. That experience helped shape how I design features today: start with the actual user journey and make the integrations reliable and maintainable."
- **Follow-up details needed:** exact personal feature ownership; frontend/backend stack; database; transaction edge cases; rollout result; usage metrics.


## Story 9 — HI+ Energy Dashboard / Energy Management System (EMS): Electricity, Billing and Sustainability

**Interview angles:** end-to-end energy product; domain-driven features; full-stack dashboards; data visualization; integrating multiple kinds of data; business value.

- **Context (Confirmed from CV):** The HI+ Energy Dashboard (2021) supported energy monitoring, carbon footprint tracking, billing transparency, and green energy engagement. Candidate was **Full Stack Developer**.
- **Related domain context (Clarified by candidate):** Their HI+ Energy / EMS experience covers electrical usage data and a broader energy ecosystem with photovoltaic (PV), IoT, and a green/carbon dashboard. **Exact system boundaries and whether all integrations were in the 2021 HI+ release or later related implementations need validation.**
- **Personal contribution (Confirmed):** Built dashboard functionality for monitoring electricity and related sustainability/billing metrics. Do not assert personally implemented every PV gateway, device driver, billing connector, or carbon formula without confirmation.
- **Engineering story:** Users need to understand energy consumption alongside billing, PV production, IoT monitoring and sustainability information. The architectural challenge is to make heterogeneous measurements and calculations understandable in coherent user experiences while maintaining sensible data provenance and units.
- **Stack:** Full-stack development confirmed; **frameworks, APIs, time-series database, data interval, ingestion transport, deployment and caching for HI+ specifically: Needs validation**. Do not automatically assume React/Express from a different project.
- **Outcome (Confirmed):** Built a dashboard covering electricity monitoring, billing transparency, carbon footprint and green energy use. **No confirmed quantified efficiency, emissions reduction, savings, or user counts.**
- **Short English narrative:** "One energy product I worked on was HI+ Energy Dashboard, where I contributed as a full-stack developer. The goal was to make electricity usage understandable beyond just raw readings, including energy monitoring, billing visibility, and carbon footprint information. My broader energy platform work also involves PV data, IoT integration, and green dashboards. What I liked about this space was turning different operational datasets into a useful product for users, rather than just showing disconnected charts."
- **Follow-up details needed:** Was the HI+ dashboard formally called EMS? Which PV and IoT integrations belonged to HI+ versus the 2026 Smart & Green Building project? Exact frameworks, database, APIs, electric units (kWh/kW), billing model, emissions factors, timeseries frequency, release/users, quantified impact.

## Story 10 — Smart & Green Building Platform: PV, IoT and Carbon Metrics

**Interview angles:** complex API integrations; full-stack visualization; cross-domain data models; analytics; sustainability products; design choices.

- **Context (Confirmed from CV):** The 2026 Smart and Green Building Platform for PLN was designed/developed as a building monitoring dashboard integrating solar photovoltaic data and IoT-based building information. It helped users monitor energy performance, calculate efficiency indicators, and estimate avoided carbon emissions.
- **Personal contribution (Confirmed):** Solution Architect and Developer; defined integration flows between field devices, data services, analytical calculations and management dashboards; developed/designed dashboard features.
- **Engineering challenge (Supported as design concern):** Data originates from multiple technologies and has different meanings; showing PV production, energy usage, building context and emissions estimates in the same product calls for consistent measurement definitions and interpretable presentation. **Do not claim a specific production failure or fix** without firsthand confirmation.
- **Architecture (Confirmed at high level):** Field devices / IoT sources → data services and calculations → dashboard. Exact protocols, database, cloud environment, frontend/backend frameworks and security implementation are **not confirmed** for this project.
- **Outcome (Confirmed):** Energy monitoring and sustainability-oriented dashboard capability; efficiency indicators and carbon avoidance estimates. Do not invent CO₂ reductions or percentage improvements.
- **Short English narrative:** "Another related project is PLN's Smart and Green Building platform. I worked on the architecture and dashboard development, bringing together solar PV and IoT building data into energy monitoring and sustainability views. It wasn't just about charting sensor data; we needed the information to make sense to users, including efficiency indicators and estimated avoided carbon emissions. I worked on how field data, backend services, calculations and the dashboard fit together as one product."
- **Follow-up details needed:** IoT device types, protocol (MQTT etc., if used), PV data source/inverter APIs, the avoided-emissions calculation basis, persistence/data refresh frequency, feature ownership, deployments and impact.

## Story 11 — Electricity-to-Carbon Product Continuum: Connecting HI+, EMS and Green Building

**Important:** This is a **cross-project narrative**, not a claim that HI+, EMS and Smart & Green Building were a single deployed application.

- **Problem framing:** Electricity data alone is difficult for nontechnical users to act on. Combining usage, billing, PV generation, IoT telemetry, energy performance and carbon indicators improves operational and management visibility.
- **Work actually supported:** HI+ Energy Dashboard (energy, billing, carbon footprint, full-stack delivery); Power Monitoring System (React + Express, high-frequency electrical data); Smart & Green Building (PV, IoT, efficiency, avoided emissions and architecture). The candidate has specifically asked to emphasize these related domains together.
- **Narrative (English):** "A recurring theme in my work has been turning energy data into useful software. I worked on HI+ Energy Dashboard for electricity monitoring, billing visibility, and carbon footprint information. I also built a React and Express power monitoring dashboard, and more recently worked on PLN's Smart and Green Building platform integrating PV and IoT data with energy-efficiency and carbon indicators. These were related efforts rather than one monolithic product, but they taught me a lot about full-stack integration, data modeling, and designing dashboards people can actually use."
- **Do not merge project-specific tech stacks or metrics** across these distinct projects.

## Evidence and specificity checklist (fill only with actual knowledge)

| Project | Stack/data details to confirm | Real metrics/outcomes to confirm |
|---|---|---|
| HI+ Energy / EMS | UI framework, backend, DB, electricity feeds, billing, PV scope, IoT devices, carbon formula | Users/sites, refresh frequency, monitored energy, reduction/savings if actually measured |
| Smart & Green Building | PV source, IoT protocol, APIs, DB, dashboard stack, calculation method | Sites, data volume, latency, dashboard usage, estimated avoided CO₂ with verified assumptions |
| Executive Dashboard | Specific frontend/backend, APIs, DB, data aggregation | Number of users, update interval, time saved if actually measured |
| Battery Swapping | Transaction DB, messaging, hardware interface, retry/dedup design | Stations, transactions, uptime, recovery time if measured |
| Power Monitoring | React state/chart libraries, Express APIs, ingestion and DB | Sample rate, devices, scale, response times |
| RAG/OCR | Redis queue type, real retry mechanism, page flag schema, threshold rule | Documents/pages, failed OCR rate, before/after quality metrics |

## Final agent interview selection rule

Before responding: (1) identify what the interviewer is actually testing; (2) select the strongest *verified* example, whether AI, Executive Dashboard, HI+/EMS, PV/IoT/green building, battery swapping, Power Monitoring, or ICONNet; (3) answer in conversational **first-person English**, ideally **50–90 words**, with situation → personal action → reasoning/trade-off → result; (4) never invent tech stacks, incidents, personal ownership, numbers, or a single merged product that did not exist.

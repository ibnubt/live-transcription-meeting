# Prep notes for the Wasimil AI Engineer role (my approach, best practice)

These are approaches I can explain; they are not claims about past projects.

## Applied ML for hotels
- Demand forecasting (occupancy, room nights, rate): features are seasonality, day of week, holidays and local events, booking pace (bookings on the books at N days before arrival), lead time, cancellations, price. Start with a strong simple baseline (same day last year + pace), then gradient boosting or Prophet per hotel; for many small hotels, one global model with hotel features beats one model each. Validate with time-based backtesting, never random splits; track MAPE or WAPE per horizon. Cold start for new hotels: borrow from similar hotels by region and size.
- Recommendation (upsells, packages, which guests to target): begin with rules and popularity, then content-based features (room type, stay purpose, past purchases), then collaborative filtering when there's enough interaction data. Evaluate offline with precision@k, then an A/B test on conversion; watch for popularity bias.
- Guest segmentation: RFM (recency, frequency, monetary) as an explainable baseline, then k-means or HDBSCAN on stay and spend features; name each segment in plain words so marketers can act on it; refresh monthly and check the segments stay stable.
- Matching (e.g. duplicate guest profiles): blocking on name/phone/email keys, a similarity score, a threshold tuned on labeled pairs, and human review for the uncertain middle.
- LLM vs classic ML: use LLMs to explain insights and write summaries; use classic ML for the numbers themselves, because it is cheaper, testable and stable.

## GraphQL / Hasura with strict permissions for an AI agent
- The agent never has its own authority: every tool call runs with the end user's JWT; Hasura applies row and column permissions from claims like x-hasura-role, x-hasura-user-id and a hotel or tenant ID. No admin secret in the tool layer.
- MCP tool layer: a small set of typed, narrow tools (e.g. get_occupancy(hotel_id, date_range)) with validated arguments and allowlisted queries, instead of letting the model write free GraphQL. Add query depth and row limits so one request can't scan everything.
- Identity lives in the server-side request context, never in the prompt, so prompt injection can't change who the user is.
- Audit: log every tool call with user, tenant and arguments in Langfuse; alert on permission errors.
- Tests: automated checks that user A can never read hotel B's data through any tool, including through follow-up questions in the same chat.

## Production LLM features
- Cost: measure tokens and cost per feature first, then cache repeated answers, trim context, route easy requests to smaller models, set per-tenant budgets, and evaluate quality before and after each change.
- Reliability: timeouts, retries with backoff, fallback model, structured output validation, and an evaluation set per feature (offline evals plus Langfuse traces in production).
- JP/EN: detect language per message, keep retrieval language-aware, and evaluate Japanese answers with native-speaker samples.
- Streaming chat: SSE or WebSocket streaming, short-term memory (trimmed history) plus long-term memory (summaries), and charts generated from data tools, not invented by the model.

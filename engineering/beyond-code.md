# Engineering is more than just code

> The backend / system-design concepts an AI usually *won't* add unless you ask — the "common
> missing pieces" once a site grows past static HTML. Extracted from a community topic list and
> expanded with web research + cited sources. Each entry says what it is, why it matters, when to
> reach for it, and — honestly — when it's overkill (e.g. don't run Kubernetes for a static site).

## Categories

1. **Containers & orchestration** — Containerisation, Docker, Kubernetes
2. **Cloud, serverless, deployment & CI/CD** — Cloud (IaaS / PaaS / SaaS), Serverless, AWS Lambda, Deployments (blue-green / canary / rolling), Staging environments, CI/CD
3. **AWS managed building blocks** — SQS (Simple Queue Service), S3 (object storage), DynamoDB
4. **Messaging, queues & real-time communication** — Kafka / RabbitMQ (message brokers), WebSockets, Long polling vs short polling, RPC (gRPC)
5. **Databases & data scaling** — Databases (SQL vs NoSQL), Embedded database (SQLite), Sharding, Partitioning, Caching (Redis / CDN)
6. **Networking, delivery, access control & encryption** — Load balancer, Proxy / reverse proxy, Firewall (network & WAF), FTP / SFTP, Encryption (TLS in transit, at rest)
7. **Performance, scalability & reliability** — Optimisation, QPS (queries per second), Throughput, Availability (SLA / uptime), Rate limiting, Error logging / observability
8. **Dev workflow, tooling & ML** — git / GitHub, git cherry-pick, PyCharm (IDE), TensorFlow (ML framework)

---

## Containers & orchestration

Containers package an app plus its exact dependencies into a portable, isolated unit that runs the same on your laptop, a server, or any cloud. Docker is the most common tool for building and running them; Kubernetes is the heavyweight system for running many containers across many machines automatically. For a static GitHub Pages site behind Cloudflare, none of this is needed at all. The moment you start hosting a Flask backend or a database, containers become genuinely useful for "it works the same everywhere" deployment, while Kubernetes stays overkill until you have real scale, multiple services, and an ops budget.

### Containerisation

**What it is.** Containerisation packages an application together with everything it needs to run (code, runtime, system libraries, config) into one isolated unit called a container. Unlike a virtual machine, a container does not bundle a full guest operating system; instead all containers on a host share that host's OS kernel, so a container is essentially an isolated process (using kernel features like namespaces and cgroups) with its own filesystem view. That makes container images measurable in megabytes and able to start in roughly a second or less, versus VM images of several gigabytes that boot a full OS in tens of seconds.

**Why it matters.** It kills the 'works on my machine' problem: the same image runs identically on your laptop, a teammate's machine, a data center, or any cloud, because the dependencies travel inside the container rather than being installed on the host. Because containers are lightweight and share the kernel, you can also pack far more of them onto a given server than VMs, lowering hosting cost.

**When to use it.** Reach for it once you have a backend or service to deploy (your Flask app, a worker, a database) and want repeatable, portable deploys. Do NOT containerise a static GitHub Pages site, that is purely HTML/CSS/JS served by GitHub/Cloudflare with no runtime to package, so a container adds zero value. Also note the tradeoff vs VMs: because containers share the host kernel, their isolation is a weaker security boundary than a VM's hypervisor/hardware isolation, and a kernel exploit can in principle escape the container; for hard security or multi-tenant isolation, VMs (or VM-backed/microVM container services like Fargate or Fly Machines) still have the edge. In practice the two are combined, containers running on top of VMs.

**Relevance / when it's worth it.** Directly relevant as you grow toward backend/DB hosting. For your Flask apps and any database, a container gives you a reproducible deploy artifact and easy local dev that mirrors production. It is irrelevant to your static Pages sites, and only tangentially relevant to Electron (Electron ships a desktop binary to end users; containers are a server-side packaging tool, not a desktop distribution mechanism).

**Sources:** <https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/> · <https://aws.amazon.com/compare/the-difference-between-containers-and-virtual-machines/>

### Docker

**What it is.** Docker is the most widely used platform for building and running containers. You write a Dockerfile (a short recipe of build steps), which produces a read-only, layered image; a running instance of that image is a container. The Docker Engine has a client-server design: a background daemon (dockerd) manages images, containers, networks, and volumes, and the docker CLI talks to it via the Docker API. Images are pushed to and pulled from registries such as Docker Hub (the default), so you can share or deploy them anywhere.

**Why it matters.** Docker turns 'set up the server, install the right Python version, install these system libs, pray' into 'build one image, run it anywhere'. It standardises how a whole team builds and ships software and shrinks the gap between code finished and code running in production. Layered images make rebuilds and pulls fast because unchanged layers are cached and only changed layers are rebuilt.

**When to use it.** Use Docker to package and deploy a real backend, to get a local dev environment that closely matches production, or to pin a database/Redis version for local work. For a single small Flask app you can also use Docker Compose (a YAML file describing app + DB + cache together) instead of hand-wiring containers. Do NOT bother for a static Pages site, there is no server process to containerise. And remember Docker itself builds/runs containers on one host; it is not a multi-machine scaling system (that is what orchestrators like Kubernetes or Docker Swarm add).

**Relevance / when it's worth it.** High value as your first real backend step. Dockerising a Flask app plus its Postgres/Redis with a Compose file gives you reproducible local dev and a clean deploy artifact for a VPS or a managed container host (Fly.io, Render, AWS ECS/Fargate). Many backend hosting platforms accept a Dockerfile directly. Not useful for static Pages; for Electron you might use Docker only in CI to build the app, not to ship it.

**Sources:** <https://docs.docker.com/get-started/docker-overview/> · <https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/>

### Kubernetes

**What it is.** Kubernetes (often 'K8s') is an open-source platform, originally built and open-sourced by Google in 2014 and now governed by the CNCF, that automates deploying, scaling, and managing containerised apps across a cluster of machines. You declare the desired state (run 3 copies of this image, expose it here) and Kubernetes' control loops continuously drive the actual state to match. It provides self-healing (restarts/replaces failed containers), service discovery and load balancing, storage orchestration, automated rollouts and rollbacks, horizontal autoscaling, secret/config management, and bin-packing of containers onto nodes.

**Why it matters.** It solves the operational problems that appear when you run many containers in production: containers crash and must be replaced, traffic must be load balanced, deploys need safe rollout and rollback, and capacity must scale up and down. Kubernetes provides a consistent, declarative framework for all of this across many servers and clouds, which is why it became the industry standard for large, multi-service systems.

**When to use it.** Use it when you genuinely have scale: many services, multiple machines, high-availability needs, and an ops budget to run it. For almost everything smaller it is overkill, and the official docs are blunt that Kubernetes is NOT a traditional all-inclusive PaaS, does NOT build/deploy source code or run CI/CD for you, and does NOT provide databases, message buses, caches, or logging/monitoring as built-in services, you assemble those yourself, which is real complexity. Simpler alternatives first: Docker Compose for one host, Docker Swarm or HashiCorp Nomad for light clustering, or managed serverless containers like AWS Fargate/ECS, Google Cloud Run, Fly.io, or Render that hide the orchestration entirely.

**Relevance / when it's worth it.** Currently overkill for your stack. A static Pages site has nothing to orchestrate, and a single Flask app plus a database is far better served by Docker Compose or a managed container/PaaS host than by a Kubernetes cluster you must operate and secure. Worth understanding conceptually as the destination if a project grows into many services with real traffic, but the honest near-term path is Docker + a managed host, and reaching for Kubernetes (or managed K8s like EKS/GKE) only when that clearly stops scaling.

**Sources:** <https://kubernetes.io/docs/concepts/overview/> · <https://encore.dev/articles/kubernetes-alternatives>

**Key references:** [What is a container? - Docker Docs](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/) · [What is Docker? (Docker overview) - Docker Docs](https://docs.docker.com/get-started/docker-overview/) · [Overview / What is Kubernetes - Kubernetes Docs](https://kubernetes.io/docs/concepts/overview/) · [Containers vs. Virtual Machines - AWS](https://aws.amazon.com/compare/the-difference-between-containers-and-virtual-machines/) · [Kubernetes Alternatives for Small Teams - Encore](https://encore.dev/articles/kubernetes-alternatives)

---

## Cloud, serverless, deployment & CI/CD

This cluster covers how code gets from your machine to users running reliably: where it runs (cloud service models and serverless), how you ship changes safely (deployment strategies and staging), and how you automate that pipeline (CI/CD). For a maker shipping static GitHub Pages sites behind Cloudflare, most of this is already handled for free, so the honest framing is "you don't need this yet." But the moment a Flask app, a database, or paying users enter the picture, these concepts stop being enterprise jargon and become the difference between a 2 a.m. outage and a non-event. The guidance below is deliberately honest about which tools are overkill for a static site versus genuinely load-bearing once you have a backend and a DB.

### Cloud (IaaS / PaaS / SaaS)

**What it is.** "The cloud" just means renting someone else's computers over the internet instead of owning hardware. It comes in three layers of abstraction. IaaS (Infrastructure as a Service) gives you raw virtual machines, storage, and networking that you configure yourself (e.g. AWS EC2, a DigitalOcean droplet, a Hetzner VPS). PaaS (Platform as a Service) hides the servers and OS so you just push code and the platform runs and scales it (e.g. Heroku, Render, Railway, Fly.io, AWS Elastic Beanstalk). SaaS (Software as a Service) is finished software you simply use, managing nothing underneath (e.g. Gmail, Notion, and arguably GitHub Pages itself).

**Why it matters.** The model you pick decides how much undifferentiated work (patching the OS, capacity planning, scaling) you do versus the provider, which directly trades off control against your time. As you move IaaS to PaaS to SaaS, responsibility shifts from you to the vendor, so picking the right layer is the single biggest lever on operational burden for a solo maker.

**When to use it.** Reach for PaaS first when you outgrow static hosting (a Render or Fly.io deploy of a Flask app is far less work than babysitting a Linux VM). Use IaaS only when you need control PaaS won't give you (custom networking, specific OS packages, cost at scale) and you're willing to own patching and security. Prefer SaaS for anything that isn't your core product (auth, email, error tracking, the database itself via a managed service). For a static GitHub Pages site you are effectively already on SaaS plus a CDN, so IaaS/PaaS is overkill until you add a real backend.

**Relevance / when it's worth it.** GitHub Pages + Cloudflare is SaaS + CDN: zero servers to manage, which is exactly right for static HTML/CSS/JS. The growth path is NOT to jump to raw IaaS VMs but to put Flask on a PaaS (Render/Railway/Fly.io) and use a managed (SaaS) database. Electron apps are desktop, not cloud, but any sync/license backend they need follows the same PaaS-first logic.

**Sources:** <https://aws.amazon.com/types-of-cloud-computing/> · <https://www.redhat.com/en/topics/cloud-computing/iaas-vs-paas-vs-saas>

### Serverless

**What it is.** Serverless is a cloud execution model where the provider fully manages the infrastructure and runs your code on demand, so you never provision or maintain servers. Despite the name there are still servers, you just don't see or manage them. AWS frames serverless around four tenets: no server management, automatic scaling (including down to zero when idle), pay-for-value billing (you pay per request / per millisecond of execution, nothing while idle), and built-in fault tolerance across availability zones. It spans more than functions: serverless databases (DynamoDB, Aurora Serverless), queues (SQS — a managed message queue, not a pub/sub broker like SNS), and storage (S3) follow the same model.

**Why it matters.** It removes nearly all operational overhead and the idle-cost problem: a low-traffic side project can cost literally pennies because you pay only when code actually runs. That makes it ideal for spiky, unpredictable, or event-driven workloads where keeping a server running 24/7 would be wasteful.

**When to use it.** Use serverless for event-driven and bursty work: webhooks, form handlers, image/file processing, scheduled jobs (cron), light APIs, and glue between services. Avoid it (or prefer a small always-on PaaS instance) for long-running processes, anything needing persistent in-memory state or long-lived connections (e.g. WebSocket servers), latency-sensitive paths hurt by cold starts, and steady high-traffic workloads where a reserved server is cheaper per request. A common misconception: serverless is not automatically cheaper at scale; past a certain steady load a plain server wins on cost.

**Relevance / when it's worth it.** For a static site, serverless is the natural way to add the few dynamic bits you can't do client-side: a contact form, a Stripe webhook, an API key proxy. Cloudflare Workers/Pages Functions sit directly in front of your existing Cloudflare-hosted site and are the lowest-friction option. As you grow toward a backend, serverless functions are a fine first step, but a full Flask app with a DB is often simpler to run as one always-on PaaS service than to chop into many functions.

**Sources:** <https://docs.aws.amazon.com/serverless/latest/devguide/serverless-core.html> · <https://aws.amazon.com/what-is/serverless-computing/>

### AWS Lambda

**What it is.** AWS Lambda is the most established serverless compute service: you upload a function (Python, Node.js, etc.), an event triggers it (an HTTP request via API Gateway, a file landing in S3, a queue message, a schedule), and AWS runs it on managed compute, scaling from zero to thousands of concurrent executions automatically. You pay per request plus per-millisecond of compute, with nothing charged while idle. Standard functions run up to 15 minutes; newer "durable" functions extend to long, stateful multi-step workflows (up to one year, checkpointing their progress). The well-known catch is the cold start: the first invocation after idle has extra latency while AWS spins up the environment (mitigated by SnapStart / provisioned concurrency).

**Why it matters.** It is the canonical example of serverless and the default building block for event-driven backends on AWS, integrating natively with a wide range of AWS services. It lets a solo maker run real backend logic with no servers to patch and a bill that's effectively free at low volume.

**When to use it.** Good for: API backends behind API Gateway, S3-triggered file processing, scheduled tasks, stream and queue processing, and webhook handlers. Avoid for: standard functions exceeding the 15-minute limit, code needing persistent local state or long-lived connections, latency-critical endpoints where cold starts hurt, or very large/complex dependency bundles. Misconception to correct: Lambda functions are stateless and ephemeral; never rely on local disk or in-memory data persisting between invocations, use S3/DynamoDB/a DB for state. Simpler alternative for a beginner: Cloudflare Workers or a Render/Railway service avoid AWS's IAM/VPC learning curve.

**Relevance / when it's worth it.** Probably overkill as a first move for a static-site maker, mainly because of AWS's setup complexity (IAM roles, API Gateway, VPC). For the reader's stack, a Cloudflare Worker is usually the faster path to the same result. Lambda becomes genuinely worth learning once you're already committed to AWS (e.g. using RDS/DynamoDB) and want event-driven glue around those services.

**Sources:** <https://docs.aws.amazon.com/lambda/latest/dg/welcome.html> · <https://aws.amazon.com/lambda/>

### Deployments (blue-green / canary / rolling)

**What it is.** These are strategies for releasing a new version without taking the site down or exposing every user to a bad release at once. Blue-green runs two identical production environments; you deploy to the idle one (green), then flip all traffic over instantly, with rollback being an instant flip back to blue. Rolling replaces instances a few at a time (stop one, deploy new version, health-check, move on) so old and new run side by side during the rollout. Canary releases the new version to a small slice of traffic first (the canary group), watches metrics, then ramps to 100% if healthy, otherwise rolls back having exposed only a few users. AWS classifies canary as a more risk-averse form of blue/green deployment.

**Why it matters.** They turn a risky all-at-once "big bang" release into a controlled, observable, reversible one. AWS's Well-Architected Framework (OPS06-BP03) explicitly flags deploying an unsuccessful change to all of production at once as an anti-pattern because a single defect then hits every customer simultaneously and recovery is slow.

**When to use it.** Use canary when you have enough traffic and good metrics to detect problems on a small slice, it's the most risk-averse and the standard for high-stakes user-facing services. Use blue-green when you want instant rollback and can afford briefly running two full environments (note: database schema changes complicate the clean flip). Use rolling as the cheap default that needs no extra infrastructure but rolls back more slowly and runs mixed versions during the transition. When NOT to bother: for a static site, a personal project, or anything with no real traffic, plain redeploy is fine; these strategies pay off once downtime or a bad release actually costs you users or money.

**Relevance / when it's worth it.** Entirely overkill for static GitHub Pages, where a push just updates files behind a CDN and rollback is `git revert`. They start to matter once you have a live Flask backend and a database serving real users. Most PaaS platforms (Render, Fly.io, etc.) give you health-checked rolling deploys essentially for free, which is the right amount of sophistication for the reader's growth stage; reach for blue-green/canary only when an outage genuinely hurts.

**Sources:** <https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_deploy_mgmt_sys.html> · <https://docs.aws.amazon.com/whitepapers/latest/overview-deployment-options/canary-deployments.html>

### Staging environments

**What it is.** A staging (or pre-production) environment is an environment for testing that closely resembles production, where you exercise changes before real users see them. Its value comes from production parity: same OS, same dependency versions, same config, and ideally a realistic (often anonymized) copy of the database, so bugs that only appear with production-like data, migrations, or integrations get caught here instead of in front of customers. It's where you run integration tests, QA, migration dry-runs, and final manual checks.

**Why it matters.** It's the safety net between "works on my machine" and "works for users." The classic failure it prevents is a database migration or config change that passes locally but breaks against real-shaped data, by running it in staging first you find that out without an outage or data loss.

**When to use it.** Worth having once you have a backend and especially a database with schema migrations, or any integration (payments, third-party APIs) you can't safely exercise in production. The honest caveat: staging only helps to the degree it matches production; a stale, drifted staging environment gives false confidence and is a known anti-pattern. When NOT to: a static site needs no staging in the classic sense, a preview/branch deploy is enough; and even for small backends, ephemeral per-pull-request preview environments are often a lighter, more reliable substitute for one long-lived shared staging box.

**Relevance / when it's worth it.** For static GitHub Pages, you already get this informally via Cloudflare Pages / Netlify-style deploy previews or a separate gh-pages branch, no dedicated staging needed. It becomes genuinely useful when your Flask app gains a database: a staging instance (or per-PR preview) lets you rehearse migrations and integration changes safely. For Electron apps, the analogue is a beta/release channel so testers hit new builds before everyone auto-updates.

**Sources:** <https://en.wikipedia.org/wiki/Deployment_environment> · <https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_dev_integ_test_val_chg.html>

### CI/CD

**What it is.** CI/CD automates the path from a code commit to a deployed change. Continuous Integration (CI) means every push automatically builds the project and runs the test suite, so broken code is caught within minutes instead of at release time. Continuous Delivery (CD) keeps the tested build always ready to ship and deploys it with a manual click/approval. Continuous Deployment (the other CD) goes one step further and pushes every change that passes the pipeline straight to production with no human in the loop. The two CDs are commonly confused; the only difference is whether a human approves the final release.

**Why it matters.** It catches bugs early, makes releases small/frequent/low-risk, and removes error-prone manual steps, turning deployment from a stressful event into a routine, repeatable, automated one. It's also the foundation the deployment strategies above run on: blue-green/canary/rolling are automated by your CI/CD pipeline.

**When to use it.** Use CI (automated build + tests on every push) as soon as you have any tests or more than one contributor, the payoff is high and the cost is low. Add automated deployment (CD) once manual deploys become frequent or error-prone. Lean toward continuous delivery (manual approval) for anything with real users until you trust your test coverage; full continuous deployment suits mature pipelines with strong automated checks. When NOT to over-invest: don't build an elaborate multi-stage pipeline for a one-page static site, a single auto-deploy step is plenty.

**Relevance / when it's worth it.** You're already benefiting from CI/CD whether you realize it or not: pushing to GitHub Pages is a tiny CD pipeline, and Cloudflare Pages/most PaaS platforms auto-build-and-deploy on git push. The concrete next step for the reader's stack is adding GitHub Actions to run linting/tests on each push (CI) before the auto-deploy fires, and for Electron apps a CI workflow that builds and signs installers per-OS on tag. As the Flask backend and DB grow, the same pipeline is where you'd wire in migration steps and a staging deploy.

**Sources:** <https://about.gitlab.com/topics/ci-cd/> · <https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_deploy_mgmt_sys.html>

**Key references:** [Types of Cloud Computing: IaaS vs PaaS vs SaaS (AWS)](https://aws.amazon.com/types-of-cloud-computing/) · [What is AWS Lambda? (AWS Lambda Developer Guide)](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html) · [Serverless on AWS (AWS Lambda product page)](https://aws.amazon.com/lambda/) · [Serverless core concepts (AWS Serverless Developer Guide)](https://docs.aws.amazon.com/serverless/latest/devguide/serverless-core.html) · [What is Serverless Computing? (AWS)](https://aws.amazon.com/what-is/serverless-computing/) · [OPS06-BP03 Employ safe deployment strategies (AWS Well-Architected Framework)](https://docs.aws.amazon.com/wellarchitected/latest/framework/ops_mit_deploy_risks_deploy_mgmt_sys.html) · [Canary deployments (AWS Overview of Deployment Options whitepaper)](https://docs.aws.amazon.com/whitepapers/latest/overview-deployment-options/canary-deployments.html) · [What is CI/CD? (GitLab)](https://about.gitlab.com/topics/ci-cd/) · [Deployment environment (Wikipedia)](https://en.wikipedia.org/wiki/Deployment_environment)

---

## AWS managed building blocks

SQS, S3, and DynamoDB are three of AWS's foundational "managed building blocks": a message queue, an object store, and a NoSQL database. Each removes a category of operational work (running brokers, file servers, or database clusters) so you pay per use and let AWS handle durability, scaling, and patching. For a maker shipping static GitHub Pages sites, all three are overkill day-to-day, but each becomes genuinely useful the moment there's a real backend: S3 for user uploads and assets, SQS for offloading slow work from a Flask request, and DynamoDB for simple high-scale key-value data. The honest rule of thumb: reach for these when you have a concrete backend need they solve, not because "AWS" sounds production-grade.

### SQS (Simple Queue Service)

**What it is.** SQS is a fully managed message queue: producers send messages into a queue, and consumers pull them out and delete them when done. It's the AWS equivalent of running a queue broker (RabbitMQ, Redis lists, etc.) without operating any servers. Two flavors exist: Standard queues (nearly unlimited throughput, best-effort ordering, at-least-once delivery, so duplicates are possible) and FIFO queues (strict in-order delivery within a message group and de-duplication, capped at 300 API calls/sec, or 3,000 messages/sec with batching, and up to 30,000 messages/sec in high-throughput mode).

**Why it matters.** It decouples slow or unreliable work from your request/response path: instead of making a user wait while you send an email, resize an image, or call a flaky third-party API, you drop a message on the queue and a worker handles it later, so a spike or a downstream outage doesn't take your app down. Messages are stored redundantly across Availability Zones and retried via a visibility-timeout mechanism, with a dead-letter queue to catch messages that repeatedly fail.

**When to use it.** Reach for SQS once you have a backend with work that can happen asynchronously: background jobs, buffering bursts of traffic, fan-out via SNS+SQS, or smoothing load onto a downstream system. Do NOT use it for a static site (nothing to decouple), and don't over-reach for it on a small Flask app where a simpler in-process or library queue (Python's RQ/Celery on Redis, or even a background thread) is easier to run and debug. Common misconception: Standard SQS is not exactly-once and not strictly ordered, so design consumers to be idempotent (FIFO offers exactly-once processing and ordering within a message group, but is slower, use it only when ordering/de-dup genuinely matters). Also note SQS is point-to-point (a message is processed by a single consumer, not broadcast), use SNS or EventBridge for true pub/sub fan-out, and Kinesis/Kafka for high-volume event streaming with replay.

**Relevance / when it's worth it.** Irrelevant to the static GitHub Pages sites. It becomes useful as the Flask side grows: e.g., a contact form or upload endpoint that returns instantly while a worker does the slow part. Until you actually have a separate worker process and a reason to decouple, a lightweight task library or even a synchronous call is the simpler, correct choice.

**Sources:** <https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/welcome.html> · <https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-queue-types.html>

### S3 (object storage)

**What it is.** S3 is object storage: you put files ("objects") into named "buckets" and retrieve them by a unique key, over HTTPS. It is not a filesystem and not a database, there are no real folders (prefixes just look like folders) and no partial in-place edits; you replace a whole object at once. It's built for huge scale and very high durability, with features like versioning, lifecycle rules to tier data to cheaper storage classes (Glacier), and event notifications that can trigger Lambda/SQS/SNS when objects change.

**Why it matters.** It solves the 'where do I store user-uploaded files, images, backups, and large assets?' problem without running or scaling a file server, and it's cheap and pay-per-use. S3 now provides strong read-after-write consistency in all regions (a correction to the old 'S3 is eventually consistent' lore), so a successful upload is immediately readable. It also integrates with CloudFront/Cloudflare as a CDN origin.

**When to use it.** Use S3 for durable blob storage: user uploads, generated PDFs/exports, image assets, database backups, log archives, and as a cheap origin behind a CDN. Do NOT treat it as a database (no querying by value, no transactions across keys, last-writer-wins on concurrent PUTs to the same key) and do NOT use it as a mutable filesystem for an app that needs random writes. For purely static website hosting, S3 can serve a site, but note it does NOT run server-side code and the raw S3 website endpoint does NOT support HTTPS, you need CloudFront (or a front like Cloudflare) for HTTPS and a custom domain. For most small makers, GitHub Pages or Cloudflare Pages is simpler and cheaper than S3+CloudFront for the hosting itself.

**Relevance / when it's worth it.** This is the AWS building block most directly useful to this reader. The static sites are already well served by GitHub Pages + Cloudflare, so don't move hosting to S3 just for prestige. But the first time a Flask app needs to accept file uploads or store generated artifacts, or an Electron app needs cloud sync/backup of user files, S3 (often via a pre-signed upload URL so files go straight from browser to bucket) is the natural, low-ops answer, far better than stuffing binaries into a database or a server's local disk.

**Sources:** <https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html> · <https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html>

### DynamoDB

**What it is.** DynamoDB is a fully managed, serverless NoSQL database with key-value and document models and single-digit-millisecond reads/writes at almost any scale. You design around a primary key (a partition key, optionally plus a sort key) and access patterns, not around normalized tables and JOINs, there is no JOIN operator and you're expected to denormalize. It scales automatically (on-demand mode can even scale to zero cost when idle) and replicates across three Availability Zones, with optional multi-region global tables, point-in-time recovery, and change streams.

**Why it matters.** It removes nearly all database operations (no servers, patching, version upgrades, or capacity planning in on-demand mode) while delivering predictable low latency even under huge, spiky traffic, the classic shopping-cart/leaderboard/session-store workloads. For event-driven designs it emits a stream of item changes that can trigger Lambda. It also supports ACID transactions across items, correcting the misconception that 'NoSQL means no consistency.'

**When to use it.** Choose DynamoDB when your access patterns are simple and known up front (fetch/update by key), you need to scale writes hard, or you want zero database ops in a serverless stack (e.g., Lambda + API Gateway). Do NOT choose it when you need ad-hoc queries, flexible filtering, JOINs, reporting/analytics, or rich relational integrity, fighting DynamoDB to do relational work is a common and painful mistake. For most early-stage backends, a managed relational database (PostgreSQL via RDS/Aurora/Neon/Supabase, or even SQLite for a single small app) is the more flexible, more familiar default; reach for DynamoDB once a specific key-access, extreme-scale, or fully-serverless requirement justifies its rigid data-modeling discipline.

**Relevance / when it's worth it.** Overkill for static sites and unnecessary for a typical small Flask app, where Postgres or SQLite is friendlier and supports the ad-hoc queries you'll inevitably want. As the reader grows into backend/DB hosting, the pragmatic path is a managed Postgres first; DynamoDB earns its place later for a specific need like a high-write event log, session/token store, or a fully serverless feature where its always-free 25 GB tier and scale-to-zero pricing shine.

**Sources:** <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html> · <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html>

**Key references:** [What is Amazon Simple Queue Service? - AWS SQS Developer Guide](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/welcome.html) · [Amazon SQS queue types (Standard vs FIFO)](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-queue-types.html) · [What is Amazon S3? - AWS S3 User Guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) · [Amazon S3 website endpoints (HTTP-only; use CloudFront for HTTPS)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html) · [What is Amazon DynamoDB? - AWS DynamoDB Developer Guide](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html) · [DynamoDB core components (keys, items, tables)](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html)

---

## Messaging, queues & real-time communication

This cluster covers how parts of a system talk to each other beyond a single page-load request: brokers that decouple producers from consumers (Kafka/RabbitMQ), live browser-to-server channels (WebSockets and the polling techniques they replace), and typed service-to-service calls (gRPC). None of it matters for a purely static GitHub Pages site behind Cloudflare, where Cloudflare and the CDN already handle delivery. It starts to matter the moment you add a Flask backend with a database: queues let slow work (emails, image processing) run outside the request, real-time channels let the browser get live updates without hammering the server, and gRPC becomes relevant only once you have multiple internal services. The honest theme throughout is "earn the complexity": each tool solves a real problem but adds infrastructure you must run, monitor, and pay for, and a simpler alternative almost always exists for a one-app project.

### Kafka / RabbitMQ (message brokers)

**What it is.** A message broker is a server that sits between the code that produces work or events (a 'producer') and the code that handles it (a 'consumer'), holding messages in the middle so the two sides never have to be online at the same moment. RabbitMQ's traditional model is a queue/router: a 'smart broker' that pushes each message to a consumer and deletes it from the queue once acknowledged (ACK), with rich routing (exchanges, bindings, priority queues). Kafka is a distributed append-only log: producers append to partitioned topics, messages are retained for a configured period regardless of consumption, and 'smart consumers' pull and track their own position (offset), so the same data can be re-read or replayed by many consumers. Note: modern RabbitMQ also offers a 'Streams' queue type that is itself an append-only, retained, replayable log, narrowing the historical gap with Kafka.

**Why it matters.** They decouple slow or bursty work from the user-facing request: a Flask route can drop a 'send welcome email' or 'resize this upload' message onto a queue and return instantly, while a separate worker does the slow job, so traffic spikes queue up instead of crashing the app. Kafka's defining strength is letting many independent services react to the same stream of events and replay history because messages are retained, not deleted on consumption. Classic RabbitMQ queues delete a message once acknowledged and so cannot replay it, though RabbitMQ Streams now add a Kafka-like retained log for cases that need replay.

**When to use it.** Reach for RabbitMQ (or a lighter option) once your Flask app has background jobs: emails, PDF/image processing, webhook fan-out, or anything that would otherwise make a request hang. Choose RabbitMQ's classic queues for task queues with complex routing, priorities, and once-and-done processing; choose Kafka for high-throughput event streaming where many consumers replay the same data, e.g. analytics pipelines or event sourcing. When NOT to: a static GitHub Pages site has no server-side work, so a broker is pure overkill. Even for a small Flask app, the honest simpler alternatives are: a database-backed job table polled by a cron, or libraries like Celery/RQ/Dramatiq backed by Redis, which give you a working task queue without operating a full broker. Kafka in particular is heavy operationally and almost never justified for a solo maker's first backend.

**Relevance / when it's worth it.** Irrelevant to your static Cloudflare-fronted pages. Becomes genuinely useful as your Flask + DB backend grows and you need to move slow work off the request path; start with Redis + RQ/Celery, graduate to RabbitMQ if routing needs grow, and treat Kafka as a 'you'll know when you need it' tool you almost certainly don't yet. Electron apps don't need a broker either, though a desktop app's backend service might.

**Sources:** <https://aws.amazon.com/compare/the-difference-between-rabbitmq-and-kafka/> · <https://www.rabbitmq.com/docs/streams>

### WebSockets

**What it is.** WebSocket is a protocol that opens a single, long-lived, two-way (full-duplex) connection between a browser and a server, so either side can send messages at any time without starting a new HTTP request each time. It starts as an HTTP request that 'upgrades' to the WebSocket protocol (via the Upgrade header and a Sec-WebSocket-Key/Accept handshake), then stays open. URLs use ws:// (plain) or wss:// (TLS-encrypted, the WebSocket equivalent of HTTPS and what you should always use in production). In the browser you use the WebSocket API; a newer, experimental WebSocketStream adds automatic backpressure handling but has limited browser support and is not recommended for production.

**Why it matters.** It removes the fundamental limit of plain HTTP, where the server cannot speak unless the client asks first. With one persistent connection and tiny per-message overhead (no repeated headers/handshakes), WebSockets deliver the lowest-latency, true real-time, bidirectional updates, which is why chat, multiplayer games, live trading dashboards, and collaborative editors rely on them.

**When to use it.** Use WebSockets when the browser and server both need to push data continuously and interactively: chat, presence/typing indicators, multiplayer, collaborative documents, live cursors. When NOT to: if you only need the server to push to the client one-way (live scores, notifications, a progress feed, an LLM token stream), Server-Sent Events (SSE) over plain HTTP are simpler, auto-reconnect for free, and work better with proxies and CDNs. If updates are occasional, plain polling is even simpler. A common misconception is that WebSockets 'just work' once connected; the standard browser WebSocket API does not auto-reconnect and does not expose backpressure, and WebSockets need their own auth, heartbeat/ping, and reconnect logic, so don't adopt them unless the interactivity is real.

**Relevance / when it's worth it.** Not usable on static GitHub Pages, because WebSockets require a server holding the connection open, and Pages serves static files only; Cloudflare can proxy wss:// but there must be a backend behind it. Once you host a Flask backend you can add WebSockets via Flask-SocketIO or an ASGI server, but for most early features (live status, notifications) prefer SSE first. Electron apps frequently use WebSockets to talk to a backend or device, where the persistent connection is a natural fit.

**Sources:** <https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API> · <https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events>

### Long polling vs short polling

**What it is.** Both are ways to fake real-time updates using ordinary HTTP requests. Short polling: the client asks the server 'anything new?' on a fixed interval (say every few seconds) and the server replies immediately, even if the answer is 'no.' Long polling: the client asks, but the server holds the request open and only responds when new data actually exists (or a timeout fires); the client then immediately reopens a new request. Long polling feels closer to real-time and wastes fewer empty round-trips, at the cost of many connections sitting open on the server.

**Why it matters.** These are the lowest-common-denominator techniques for getting fresher data without any special protocol: they work through every proxy, firewall, and CDN, need no server upgrade, and run on plain HTTP that a static-leaning stack already understands. They are the fallback that real-time libraries (e.g. Socket.IO) drop down to when WebSockets are blocked.

**When to use it.** Use short polling when updates are infrequent and a few seconds of staleness is fine, and you value dead-simple code: dashboard refreshes, checking whether a background job finished, low-frequency status. Use long polling when you want near-real-time but cannot or don't want to run WebSockets/SSE. When NOT to: don't reach for either when a true push channel exists and updates are frequent. SSE beats both for one-way server-to-client streams (it auto-reconnects and is built for exactly this), and WebSockets beat both for high-frequency bidirectional traffic. A key misconception: short polling at a tight interval looks real-time but wastes bandwidth and server cycles on empty responses and adds latency up to one full interval, so it scales badly under load.

**Relevance / when it's worth it.** Highly relevant and underrated for your stack precisely because it needs no special server features: even a near-static page can short-poll a small JSON API or a Cloudflare Worker/KV endpoint to show fresh-ish data. For an early Flask backend, short polling a status endpoint is often the right first move before investing in SSE or WebSockets, and long polling is a reasonable step up if you need lower latency without new infrastructure.

**Sources:** <https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events> · <https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API>

### RPC (gRPC)

**What it is.** RPC (Remote Procedure Call) is the idea of calling a function that actually runs on another machine as if it were a local function. gRPC is Google's high-performance, open-source RPC framework: you describe your service and message types in a .proto file (Protocol Buffers), run a compiler to generate strongly-typed client 'stubs' and server skeletons in many languages, and then call remote methods directly. It runs over HTTP/2 with compact binary serialization and supports four call styles: unary (one request, one response), server streaming, client streaming, and bidirectional streaming, plus built-in deadlines/timeouts (DEADLINE_EXCEEDED) and cancellation.

**Why it matters.** It gives service-to-service communication a typed contract, automatic client/server code generation across languages, and much smaller, faster messages than JSON-over-REST, which is why it is a default choice for connecting microservices and for low-latency mobile-to-backend links. The .proto file is the single source of truth, so client and server can't silently drift apart.

**When to use it.** Use gRPC when you have multiple backend services (often in different languages) that call each other a lot and you want speed, strong typing, and streaming, or for chatty internal/mobile APIs where JSON overhead hurts. When NOT to: for a public web API consumed by browsers and third parties, a plain REST/JSON (or GraphQL) endpoint is simpler, human-readable, and universally supported. Crucially, browsers cannot speak raw gRPC directly: the browser Fetch API does not expose HTTP/2 framing and cannot read the HTTP/2 trailers where gRPC sends its final status (this is a Fetch/JavaScript limitation, not a lack of HTTP/2 in browsers, which have supported it for years). Browser clients therefore require a gRPC-Web layer plus a translating proxy (e.g. Envoy), an extra moving part, and client/bidirectional streaming from the browser remains limited. For a single Flask app there are no 'other services' to call, so gRPC solves a problem you don't have.

**Relevance / when it's worth it.** Overkill for static Pages and for a single Flask backend, and awkward for browser front-ends because of the gRPC-Web proxy requirement, so keep your public API as REST/JSON. gRPC only earns its place once you split your backend into several internal services that talk to each other privately. For an Electron app talking to its own local/remote service it's possible, but plain HTTP/JSON or WebSockets are usually the lower-friction choice until performance or strict typing genuinely demands gRPC.

**Sources:** <https://grpc.io/docs/what-is-grpc/introduction/> · <https://grpc.io/docs/what-is-grpc/core-concepts/>

**Key references:** [AWS: The Difference Between RabbitMQ and Kafka](https://aws.amazon.com/compare/the-difference-between-rabbitmq-and-kafka/) · [RabbitMQ: Streams and Superstreams (append-only, replayable queues)](https://www.rabbitmq.com/docs/streams) · [MDN: The WebSocket API (WebSockets)](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API) · [MDN: Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events) · [gRPC: Introduction to gRPC](https://grpc.io/docs/what-is-grpc/introduction/) · [gRPC: Core concepts, architecture and lifecycle](https://grpc.io/docs/what-is-grpc/core-concepts/)

---

## Databases & data scaling

This cluster covers how data is stored and how storage scales as a site grows from static pages into a real backend. For a maker shipping static GitHub Pages sites behind Cloudflare, almost all of "data scaling" (sharding, partitioning, Redis) is overkill: Cloudflare's CDN already gives you world-class edge caching for free, and you have no database to scale. The moment you stand up a Flask backend with persistent data, the picture changes: you pick a database paradigm (SQL is the right default; NoSQL is for specific access patterns), you very likely start with SQLite (a real SQL database in one file), and you add caching only when you measure a need. Sharding and partitioning are advanced techniques you should understand but will likely never need at a personal/small-business scale; knowing when they DON'T apply is as valuable as knowing what they are.

### Databases (SQL vs NoSQL)

**What it is.** SQL (relational) databases like PostgreSQL, MySQL, and SQLite store data in tables of rows and columns with an enforced schema, can join data across tables, and are queried with SQL. NoSQL is an umbrella for non-relational stores with flexible schemas. AWS groups them by data model: key-value (DynamoDB), document (MongoDB, DocumentDB; store JSON-like documents), graph (Neptune, for relationship-heavy data), in-memory (Redis/MemoryDB, ElastiCache; a Redis instance is typically a key-value store that happens to live in RAM), and search (OpenSearch). The core trade is structure and strong guarantees (SQL) versus schema flexibility and easy horizontal scale (NoSQL).

**Why it matters.** This is the foundational backend decision: it dictates how you model data, what guarantees you get (ACID transactions and referential integrity vs. relaxed/eventual consistency), and how the system scales. Choosing the wrong paradigm for your access patterns is expensive to undo later.

**When to use it.** Default to SQL (specifically PostgreSQL or SQLite) for almost every project: it handles structured data, complex queries, joins, and transactions, and a relational schema is the safest starting point when you don't yet know all your query patterns. Reach for a specific NoSQL store only when you have a concrete reason: a document store for genuinely schema-less/hierarchical data, a key-value store for simple high-throughput lookups, or a graph DB for relationship traversal. Correct two myths: NoSQL does NOT mean 'no schema planning' (you model around your access patterns up front, which is actually harder to change later), and NoSQL does NOT mean 'no consistency' (it strategically relaxes some ACID guarantees, not all). Hybrid use of both SQL and NoSQL is common and fine.

**Relevance / when it's worth it.** For static GitHub Pages sites there is no database at all, so this is N/A until you add a backend. Once you build a Flask app, start with SQL/Postgres (or SQLite) by default. You almost certainly do NOT need NoSQL for a personal or small-business app; the 'NoSQL scales better' argument only matters at a scale you won't hit. Flask pairs naturally with SQLAlchemy over a relational DB.

**Sources:** <https://aws.amazon.com/nosql/> · <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SQLtoNoSQL.html>

### Embedded database (SQLite)

**What it is.** SQLite is a full SQL database engine that runs in-process as a library: there is no separate server to install or manage, and the entire database (tables, indexes, the lot) lives in a single cross-platform file on disk. It is the most widely deployed database in the world, shipping inside phones, browsers, and desktop apps. Its 'serverless' means no server process, which is unrelated to cloud 'serverless' like AWS Lambda.

**Why it matters.** It removes essentially all database operations: no server to provision, configure, secure, back up (you just copy the file), or pay for. You get real SQL, transactions, and durability with zero infrastructure, which is ideal for getting a backend running fast and for apps that bundle their own data.

**When to use it.** Use SQLite for local/desktop apps (it is a great Electron app data store and file format), for development, and for low-to-medium-traffic websites. SQLite.org states any site that gets fewer than 100K hits/day should work fine on SQLite (their own site serves about 400K-500K HTTP requests/day, ~15-20% of them dynamic pages touching the database), and the practical file-size limit is huge (281 TB max). When NOT to use it: SQLite supports only one writer at a time per database file, so it is the wrong choice for write-intensive concurrent workloads or apps spread across multiple servers/machines (the data file and the app must share a disk). When you outgrow it, 'upgrade' to a client/server database like PostgreSQL; the SQL you wrote mostly carries over.

**Relevance / when it's worth it.** Highly relevant and the recommended starting point as you grow into backends. For a Flask app on a single host, SQLite is often all you need and avoids running a separate DB server. For Electron apps it is the natural embedded store. The main caveat for hosting: many cheap/PaaS hosts use ephemeral or read-only filesystems, so a SQLite file can be wiped on redeploy unless it sits on a persistent volume. That single-writer limit is the main reason to move to Postgres once you have real concurrent write traffic.

**Sources:** <https://sqlite.org/whentouse.html> · <https://sqlite.org/about.html>

### Sharding

**What it is.** Sharding stores one logical database across multiple physical machines by splitting rows into chunks called shards, each on its own database server. A shard key decides which shard a given row lives on. Common schemes are range-based (e.g. A-I, J-S), hash-based (even distribution but hard to add shards), directory-based (a lookup table), and geo-based. It is a horizontal scale-out technique for when one server can no longer hold or serve the data.

**Why it matters.** It is the way to scale a database beyond the capacity of a single machine: more storage, more write throughput, and resilience (one shard failing doesn't take down everything). It's the technique behind databases that serve enormous datasets and user counts.

**When to use it.** Only when a single server genuinely cannot cope: a dataset too large to fit one machine, write throughput one node can't sustain, or a need to keep data geographically close to users. Before sharding, exhaust the simpler options in order: optimize queries and indexes, scale the server up (bigger box), add read replicas, partition within one server, and add caching. Sharding's costs are steep: cross-shard queries and joins become hard or impossible, transactions across shards are painful, you risk hotspots (uneven shards), and most relational databases don't shard for you, so it's manual application complexity. Note: managed NoSQL like DynamoDB and tools like Vitess hide much of this, which is part of NoSQL's scaling appeal.

**Relevance / when it's worth it.** Overkill, and you should not build for it. A static site has nothing to shard, and a personal or small-business Flask/Postgres app will not approach single-server limits; modern hardware and managed Postgres handle very large workloads. Treat sharding as concept-level knowledge so you recognize it when reading system-design material, not as something to implement. If you ever truly needed this scale, a managed service would handle it for you.

**Sources:** <https://aws.amazon.com/what-is/database-sharding/> · <https://planetscale.com/blog/sharding-vs-partitioning-whats-the-difference>

### Partitioning

**What it is.** Partitioning splits one large table into smaller physical pieces (partitions) inside a single database server, while it still behaves as one logical table to your queries. PostgreSQL supports range (e.g. by date), list (by explicit values like region), and hash partitioning. This is a form of horizontal partitioning; sharding is essentially partitioning spread across multiple machines. (Vertical partitioning, splitting a table's columns into separate tables, is a related but distinct idea.)

**Why it matters.** On a very large table it can dramatically improve performance (queries scan only the relevant partition, and hot index portions fit in memory) and makes bulk maintenance cheap: dropping or detaching an old partition is near-instant versus a slow, VACUUM-heavy mass DELETE. It also lets you tier seldom-used data onto cheaper storage. Crucially, it stays on one server, so it avoids all of sharding's distributed complexity.

**When to use it.** Use it for genuinely large tables. The PostgreSQL rule of thumb is that the benefits are worthwhile only when a table would otherwise be very large, specifically when its size would exceed the database server's physical memory, and where the partition key matches your query patterns (e.g. time-series data partitioned by month, where you query recent data and archive old months). When NOT to use it: small tables (it just adds overhead and complexity) and workloads where queries can't be confined to a few partitions. The docs warn never to assume more partitions are better than fewer (or vice-versa) and recommend simulating your intended workload. As a scaling step it comes before sharding: optimize/index first, then partition within one DB, and only shard if you outgrow a single machine.

**Relevance / when it's worth it.** Not relevant to static sites, and not relevant to a typical small Flask app; your tables won't be big enough to benefit. It becomes useful only if you ever accumulate one genuinely huge table (think large time-series or event logs) on a single Postgres instance, where date-range partitioning makes pruning old data trivial. Until then, a plain indexed table is simpler and faster to work with.

**Sources:** <https://www.postgresql.org/docs/current/ddl-partitioning.html> · <https://planetscale.com/blog/sharding-vs-partitioning-whats-the-difference>

### Caching (Redis / CDN)

**What it is.** Caching keeps a copy of data in faster storage so you don't recompute or refetch it. Two distinct layers matter. A CDN (Cloudflare, CloudFront) caches HTTP responses, mainly static assets, at edge servers near users, governed by Cache-Control headers (e.g. public, max-age, immutable). An application/data cache like Redis is an in-memory key-value store (sub-millisecond reads) that sits between your app and your database to hold query results, sessions, or computed values.

**Why it matters.** Caching is the highest-leverage performance tool: a good strategy can cut latency dramatically and offload the majority of work from your origin/database. CDNs slash round-trip time by serving from a nearby edge; Redis spares your database from repeating expensive queries. The classic hard part is invalidation, keeping cached copies from going stale.

**When to use it.** CDN: use it for any static or cacheable content; it's almost always a win and effectively free. The standard pattern is long-lived immutable caching for versioned assets (Cache-Control: public, max-age=31536000, immutable on bundle.v123.js) plus cache-busting via versioned/hashed filenames, while HTML uses no-cache + ETag so it always revalidates (a 304 Not Modified when unchanged). Use private (or no-store) for personalized/authenticated responses so a shared cache never serves them to the wrong user. Redis: add it only after you measure a real database bottleneck. Common patterns: cache-aside / lazy loading (load into cache on a miss; only caches what's actually requested, but the first request is slower) and write-through (update the cache immediately on every DB write; fewer misses but caches data nobody reads). These two are typically combined and paired with a TTL so entries expire and stay fresh. When NOT to: don't add Redis preemptively; it's another moving part to run and a new source of stale-data bugs.

**Relevance / when it's worth it.** The CDN layer is directly and immediately relevant: your static GitHub Pages sites are already behind Cloudflare, which handles edge caching for you; the main thing to get right is setting sensible Cache-Control headers and cache-busting filenames so updates actually reach users. Redis is overkill for a static site (no backend to offload) and usually premature even for a small Flask app; start with database indexes and CDN caching, and reach for Redis only when profiling shows repeated expensive queries or you need a shared session/rate-limit store across multiple app instances.

**Sources:** <https://docs.aws.amazon.com/whitepapers/latest/database-caching-strategies-using-redis/caching-patterns.html> · <https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching>

**Key references:** [What is a NoSQL Database? - AWS](https://aws.amazon.com/nosql/) · [Appropriate Uses For SQLite - SQLite.org](https://sqlite.org/whentouse.html) · [What is Database Sharding? - AWS](https://aws.amazon.com/what-is/database-sharding/) · [Table Partitioning - PostgreSQL Documentation](https://www.postgresql.org/docs/current/ddl-partitioning.html) · [Caching patterns - Database Caching Strategies Using Redis (AWS Whitepaper)](https://docs.aws.amazon.com/whitepapers/latest/database-caching-strategies-using-redis/caching-patterns.html) · [HTTP Caching - MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching) · [Sharding vs. partitioning - PlanetScale](https://planetscale.com/blog/sharding-vs-partitioning-whats-the-difference)

---

## Networking, delivery, access control & encryption

These five concepts govern how traffic reaches your servers, how it is distributed and filtered, and how data is protected in motion and at rest. For a maker shipping static GitHub Pages sites behind Cloudflare, most of this is already handled for free at the edge (Cloudflare is your reverse proxy, your CDN, your TLS terminator, and your WAF). They become genuinely your responsibility the moment you stand up your own Flask/backend + database host: that's when load balancers, reverse proxies, firewalls/WAF rules, secure file transfer, and at-rest encryption shift from "overkill" to "table stakes." The guiding principle: don't build infrastructure to solve problems you don't have yet, but understand each so you recognize the moment you do.

### Load balancer

**What it is.** A load balancer is a single front-door endpoint that spreads incoming requests across multiple backend servers (instances, containers, IPs) and routes traffic only to healthy ones, scaling capacity without any one server becoming a bottleneck. The two common flavors are Layer 7 (application, e.g. AWS ALB) which can read HTTP and route by URL path, hostname, or header, and Layer 4 (network, e.g. AWS NLB) which routes raw TCP/UDP/TLS by IP and port at extreme throughput (millions of requests/sec) and can hold a static IP.

**Why it matters.** It is the foundation of high availability and horizontal scaling: if one backend dies or you add more capacity, the load balancer absorbs that transparently so users never see a dropped service. It also gives you a clean place to terminate TLS and run health checks.

**When to use it.** Reach for one once you run more than one backend instance, need zero-downtime deploys, or need to scale horizontally. Use an L7/ALB when you want content-based routing (path/host/header) or per-service health checks; use an L4/NLB for raw performance, non-HTTP protocols, or a static IP. When NOT to: a single small Flask box, a hobby app, or any static site needs none of this — a managed platform (Render, Fly.io, Railway, App Runner) or a single reverse proxy already covers the 'one server' case, and Cloudflare load-balancing is a simpler add-on if you only need failover.

**Relevance / when it's worth it.** Pure overkill for static GitHub Pages — Cloudflare's edge already distributes that globally. It becomes relevant only when your backend/DB hosting grows past one server or you want zero-downtime deploys; until then a managed host hides the load balancer from you entirely.

**Sources:** <https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html> · <https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html>

### Proxy / reverse proxy

**What it is.** A proxy is an intermediary that relays traffic. A forward proxy sits in front of clients and controls/masks their outbound requests to the internet (the client is configured to use it). A reverse proxy (e.g. NGINX, Caddy, Cloudflare) sits in front of your servers, receives client requests, and forwards them to one or more backends — hiding your infrastructure and presenting a single public endpoint. The core NGINX directive is proxy_pass, which forwards a matched location to a backend.

**Why it matters.** A reverse proxy is the Swiss-army layer of web ops: it gives you TLS termination (so your app never handles encryption), load balancing across backends, response caching, gzip/compression, rate limiting, and a place to add headers or auth — all in one high-performance hop in front of your app. It also lets you run several apps/domains behind one IP and port.

**When to use it.** Use a reverse proxy as soon as you self-host a backend: put NGINX or Caddy in front of Gunicorn/uvicorn so Flask isn't directly exposed and TLS is handled cleanly. A forward proxy is a different tool — for outbound egress control, corporate filtering, or anonymizing client requests — and most makers won't run one. When NOT to: for a static site or when your managed platform/Cloudflare already terminates TLS and proxies for you, a separate reverse proxy is redundant. Common misconception: a reverse proxy is not the same as a load balancer — a reverse proxy can do load balancing, but its job is broader (it's the front layer; load balancing is one feature).

**Relevance / when it's worth it.** Cloudflare in front of your GitHub Pages site IS a reverse proxy you already use — that's why your origin is hidden and TLS is automatic. The skill to learn is putting NGINX/Caddy in front of a self-hosted Flask app: it's the standard production pattern (never expose the dev server directly).

**Sources:** <https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/> · <https://www.f5.com/glossary/reverse-proxy>

### Firewall (network & WAF)

**What it is.** Firewalls filter traffic, but at two different layers. A network firewall (security groups, VPC/network ACLs, iptables, cloud network firewalls) works at L3/L4 — it allows or blocks by IP address, port, and protocol, and knows nothing about the content of a request. A Web Application Firewall (WAF) (AWS WAF, Cloudflare WAF) works at L7 — it inspects the actual HTTP/HTTPS request (headers, query strings, JSON body) and blocks application attacks like SQL injection and cross-site scripting (XSS), typically using managed rule sets aligned to the OWASP Top 10.

**Why it matters.** They defend against completely different threats and you generally want both. A network firewall shrinks your attack surface (e.g. 'only port 443 is open, database port is private'); a WAF stops malicious requests that are validly formed at the network level but hostile at the application level. A network firewall alone can't catch a SQL-injection string, and a WAF alone can't stop someone probing an open database port.

**When to use it.** Use a network firewall always once you host anything: lock inbound to the ports you actually serve and keep your DB unreachable from the public internet (this is the single highest-leverage control). Add a WAF once you have a backend that takes user input, handles auth, or touches a database. When NOT to / simpler alternative: a static site needs no WAF of its own — Cloudflare's free tier already gives you edge filtering and DDoS protection. Don't hand-write WAF rules first; start with the provider's managed OWASP rule group and only add custom rules for real, observed abuse.

**Relevance / when it's worth it.** For GitHub Pages behind Cloudflare you already have a WAF and DDoS shield at the edge — no action needed. The meaningful shift is your backend/DB phase: configure the host's network firewall/security groups so the database is private and only your app can reach it, and turn on a managed WAF in front of any input-taking Flask endpoint.

**Sources:** <https://docs.aws.amazon.com/waf/latest/developerguide/what-is-aws-waf.html> · <https://owasp.org/www-project-top-ten/>

### FTP / SFTP

**What it is.** These are protocols for moving files between machines. Plain FTP is the legacy original: it uses a separate control channel (port 21) and data channel and sends usernames, passwords, and file contents in clear text — anyone on the path can read them. SFTP runs file transfer over SSH on a single port (22), encrypting both authentication and data, and authenticates with passwords or SSH keys. FTPS is a different beast: classic FTP wrapped in TLS/SSL, still using multiple ports (e.g. 21/990 plus a data range).

**Why it matters.** Plain FTP is effectively never acceptable today — it leaks credentials. The practical distinction is SFTP vs FTPS: SFTP's single encrypted connection is far more firewall- and NAT-friendly (no juggling passive port ranges), uses SSH keys you may already manage, and is the de-facto default for secure file transfer on Linux.

**When to use it.** Use SFTP when you need ad-hoc or scheduled file transfer to a server you control (logs, backups, batch data drops), especially with SSH key auth. Use FTPS only when a vendor mandates it or you already run disciplined certificate management. When NOT to: for deploying a website or app, you almost never want any FTP variant — use git push (GitHub Pages), rsync over SSH, scp, or your platform's CI/CD deploy instead. Never use plain FTP. Common misconception: SFTP is not 'FTP with SSL' — that's FTPS; SFTP is an entirely separate SSH-based protocol.

**Relevance / when it's worth it.** Largely irrelevant to your current static-site flow, which deploys by git push, not file upload — a strict improvement over old FTP workflows. SFTP becomes useful once you run your own backend server: pulling DB backups, dropping in config, or shipping logs over an SSH connection you're already using.

**Sources:** <https://sftptogo.com/blog/what-is-the-difference-between-ftp-sftp-and-ftps/> · <https://sftptogo.com/blog/sftp-vs-ftps/>

### Encryption (TLS in transit, at rest)

**What it is.** Two distinct protections for two distinct moments in data's life. Encryption in transit (TLS) protects data while it moves over a network: TLS does a handshake to agree a cipher and a shared key, then encrypts every byte so an eavesdropper sees only ciphertext — this is what turns HTTP into HTTPS, and it also provides integrity (tamper detection) and server authentication. Encryption at rest protects data sitting on disk — databases, object storage, backups — typically with AES-256, so stolen or improperly accessed storage media are unreadable without the key.

**Why it matters.** They guard against entirely different attacks: in-transit encryption stops man-in-the-middle interception and network eavesdropping; at-rest encryption stops physical theft, a leaked disk image, or unauthorized storage access. A perfectly encrypted database is no defense against someone sniffing your API calls, and HTTPS does nothing for a stolen backup file — virtually every compliance regime expects both. Current guidance: TLS 1.2 minimum, TLS 1.3 preferred; AES-256 for data at rest.

**When to use it.** Always use TLS for anything served over a network — it's free and non-negotiable now (MDN: all sites should serve everything over HTTPS). Use at-rest encryption for any database, object store, or backup holding non-trivial or personal data — and prefer turning on the platform default rather than rolling your own crypto. When NOT to over-engineer: don't hand-roll encryption or manage your own keys before you need to; managed defaults (Cloudflare/Let's Encrypt TLS, S3 SSE-S3, RDS encryption) cover the vast majority of cases. Common misconception: HTTPS to your host does not mean your data is encrypted at rest — that's a separate setting you must enable.

**Relevance / when it's worth it.** TLS in transit is already done for you — Cloudflare/GitHub Pages serve your static sites over HTTPS automatically, and Flask behind a reverse proxy gets the same via Let's Encrypt. At-rest encryption is the new responsibility as you grow into DB hosting: it's usually a one-checkbox default (e.g. S3 encrypts every new object with AES-256 by default; RDS/managed Postgres offer encryption at creation) — enable it from day one because retrofitting it onto an existing database is far more work.

**Sources:** <https://developer.mozilla.org/en-US/docs/Web/Security/Transport_Layer_Security> · <https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html>

**Key references:** [AWS Elastic Load Balancing — What is an Application Load Balancer?](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) · [AWS Elastic Load Balancing — What is a Network Load Balancer?](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) · [NGINX Docs — Reverse Proxy (admin guide)](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) · [F5 Glossary — What is a Reverse Proxy?](https://www.f5.com/glossary/reverse-proxy) · [AWS WAF Developer Guide — What is AWS WAF?](https://docs.aws.amazon.com/waf/latest/developerguide/what-is-aws-waf.html) · [OWASP Top 10](https://owasp.org/www-project-top-ten/) · [SFTP To Go — Difference between FTP, SFTP, and FTPS](https://sftptogo.com/blog/what-is-the-difference-between-ftp-sftp-and-ftps/) · [SFTP To Go — SFTP vs FTPS: Ports, Security, Authentication, & Use Cases](https://sftptogo.com/blog/sftp-vs-ftps/) · [MDN — Transport Layer Security (TLS)](https://developer.mozilla.org/en-US/docs/Web/Security/Transport_Layer_Security) · [AWS S3 User Guide — Protecting data with server-side encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html)

---

## Performance, scalability & reliability

This cluster covers how you measure, protect, and improve a running system once it does real work for real users. For a maker shipping static GitHub Pages sites behind Cloudflare, most of this is happily solved for free by the CDN and never needs a second thought: a static site has no server to overload, no per-second budget, and effectively inherits Cloudflare's edge availability. The moment you add a Python/Flask backend or a hosted database, all six of these become live concerns, because now there is a process that can be slow, saturated, abused, or silently failing. The honest rule of thumb: optimise and rate-limit only after you can measure (observability first), set a realistic availability target instead of chasing "nines" you don't need, and reach for managed services (Cloudflare, a PaaS, a hosted DB) before building any of this machinery yourself.

### Optimisation

**What it is.** Making code or infrastructure do the same work faster, with less resource, or at lower cost. In practice it means measuring where time/resources actually go (profiling), fixing the biggest offenders first (algorithms, database queries/indexes, caching, fewer round trips), and re-measuring. AWS frames performance efficiency as an ongoing, data-driven practice: review across the whole stack (architecture, compute, data, networking) and keep choosing better options as workloads and available services evolve.

**Why it matters.** Slow pages lose users and cost money, but effort spent on the wrong thing is wasted. Knuth's famous line - 'premature optimization is the root of all evil' (from his 1974 paper) - is really an argument FOR measuring: the full quote says forget small efficiencies ~97% of the time, and programmers' intuition about the hot path is routinely wrong, so you must profile to find the critical ~3%.

**When to use it.** Optimise when a metric you actually care about is missing its target (e.g. p95 latency too high, a query is slow, a bill is too large) AND you have measured where the time goes. The simpler alternative almost always comes first: better algorithm/data-structure choice, an added DB index, or caching. Do NOT hand-optimise readable code on a hunch, and do NOT optimise a static site's JS for speed it doesn't need - ship clean code and let the CDN do the heavy lifting.

**Relevance / when it's worth it.** For static GitHub Pages behind Cloudflare, 'optimisation' is mostly caching + asset hygiene (minify, compress, set cache headers, lean images) - all of which Cloudflare/CDN handle for free; static content is cacheable by default. Once a Flask app or DB exists, the highest-leverage wins are almost always database indexes, caching expensive results, and reducing N+1 queries - found by profiling, not guessing.

**Sources:** <https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/welcome.html> · <https://ubiquity.acm.org/article.cfm?id=1513451>

### QPS (queries per second)

**What it is.** Queries Per Second - the number of requests/operations a system processes each second. It is a rate of work and is essentially application-level throughput measured in requests (or DB queries) per second. Related terms: RPS (requests/sec) for HTTP, TPS (transactions/sec) for databases.

**Why it matters.** QPS tells you how much load a system is handling and where its ceiling is. Capacity planning, load testing, autoscaling, and rate-limit thresholds are all expressed in QPS. It is the demand side of the equation that latency and availability targets must hold up under.

**When to use it.** Use QPS when sizing or load-testing a backend: 'can my Flask app sustain 200 QPS at acceptable latency?' It is the unit you load-test against and the unit you set rate limits in. The simpler alternative when you have little traffic is to not track it at all - a hobby site doing a few requests a minute has no QPS problem. Do NOT obsess over peak-QPS architectures before you have users; premature scaling is a form of premature optimisation.

**Relevance / when it's worth it.** Irrelevant for a static Pages site - Cloudflare's edge absorbs request volume and your origin serves almost nothing. It becomes very relevant the moment Flask is in the path: the single-threaded Flask dev server handles only on the order of ~125 RPS, while Gunicorn with a few workers reaches roughly 1,000+ RPS, so knowing your real QPS tells you how many workers (and how big a box) you actually need. (The dev server is also not production-grade for other reasons - use a real WSGI server like Gunicorn or Waitress.)

**Sources:** <https://sre.google/sre-book/service-level-objectives/> · <https://flask-limiter.readthedocs.io/>

### Throughput

**What it is.** The total amount of work a system completes per unit of time - requests/sec, queries/sec, bytes/sec, jobs/hour. It is the system's capacity or 'volume' metric, and is the sibling of latency (time for a single request). QPS is throughput expressed in queries.

**Why it matters.** Throughput vs latency is the core performance trade-off. They are not the same and often pull against each other: batching and concurrency raise throughput but can raise per-request latency; optimising for the fastest single response can cap total volume. Worked example: if each query needs 2 serial I/O ops, then at 1 ms per op a single worker tops out near ~500 QPS, but at 10 ms per op it caps near ~50 QPS - per-request latency directly bounds the throughput one worker can reach (you scale past it with concurrency/more workers).

**When to use it.** Reason about throughput when you need to handle volume: data pipelines, bulk jobs, or an API under sustained load. Batch/queue-oriented systems optimise for throughput and tolerate latency; interactive/real-time systems (a user clicking a button) optimise for latency. The simpler alternative for low-traffic apps: ignore throughput and just keep latency good for one user at a time. Do NOT add batching/queues to a low-volume app - you pay latency and complexity for capacity you don't use.

**Relevance / when it's worth it.** Static sites: throughput is the CDN's job, not yours. For Flask, throughput is governed mostly by worker count and worker type - sync workers for CPU-bound work, async/gevent workers for I/O-bound work can multiply requests/sec on the same hardware by yielding during I/O waits. For Electron apps it rarely matters (single-user desktop), and for a hosted DB it shows up as connection limits and queries/sec ceilings you should know before launch.

**Sources:** <https://sre.google/sre-book/service-level-objectives/> · <https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/welcome.html>

### Availability (SLA / uptime)

**What it is.** The share of time (or of well-formed requests) a service is working, usually written as a percentage and shorthanded in 'nines': 99% = 'two nines', 99.9% = 'three nines', 99.999% = 'five nines'. An SLI is the measured indicator (e.g. success rate), an SLO is your internal target for it, and an SLA is a contractual promise to customers with consequences (refunds/penalties) if you miss it. The easy test: ask 'what happens if it's missed?' - no consequence means it's an SLO, not an SLA.

**Why it matters.** It sets how much downtime is acceptable and how hard you must engineer. The cost of each extra nine rises steeply while the value to users approaches zero, so picking the right target saves enormous effort. Concretely: 99.9% allows ~43 minutes of downtime per month, while 99.99% allows only ~4 minutes - roughly a 10x jump in engineering rigour for a difference most apps' users never notice. Even Google deliberately does not promise 100% (e.g. Compute Engine's headline SLA for multi-zone instances is 99.99%, not 100%), because 100% is the wrong target - it's effectively impossible and not worth chasing.

**When to use it.** Set an explicit SLO once you have users who'd be hurt by downtime, and start LOOSE (you can tighten later); the error-budget idea says as long as you're above target you can keep shipping features rather than over-investing in reliability. The simpler alternative for a hobby/portfolio project: no formal SLA at all - 'best effort' is fine. Do NOT promise four/five nines for a side project; you'll be on call for uptime nobody is paying for.

**Relevance / when it's worth it.** A static GitHub Pages site behind Cloudflare effectively inherits the CDN/host's high availability for free - you don't run a server that can crash, so this is close to a non-issue. The calculus flips with a Flask backend or a database: now you own a process and a data store that can go down, and you should pick a modest SLO (99.9% is plenty for most makers), use a managed host with redundancy, and only consider multi-region/failover if real money or users demand it.

**Sources:** <https://sre.google/sre-book/service-level-objectives/> · <https://sre.google/sre-book/embracing-risk/>

### Rate limiting

**What it is.** Capping how many requests a client (by IP, API key, user, or route) may make in a time window, returning HTTP 429 ('Too Many Requests') once the limit is exceeded. Common algorithms: fixed window (simple but lets bursts bunch at boundaries), token/leaky bucket (handles bursts, but its two parameters are fiddly to tune), and sliding window (accurate and cheap - in Cloudflare's production analysis of 400M requests, only ~0.003% were wrongly allowed or blocked, with no false positives among mitigated sources).

**Why it matters.** It protects a backend from abuse and overload: brute-force login attempts, scrapers, accidental client retry storms, and layer-7 DoS that would otherwise saturate your origin or run up costs. It's the difference between one buggy script taking down your app and that script just getting throttled.

**When to use it.** Add rate limiting once you have endpoints worth abusing - login, signup, search, anything that hits a DB or a paid third-party API. The simpler alternative is to lean on what's already in front of you: Cloudflare can rate-limit at the edge before traffic ever reaches your origin, which is the least-effort option for this stack. Do NOT bother rate-limiting a static site (nothing to protect), and do NOT roll your own distributed limiter when the platform offers one.

**Relevance / when it's worth it.** Overkill for static Pages - but very useful for Flask APIs. Flask-Limiter is the standard extension (declare limits like '100 per minute' per route). Critical correctness note for this reader: its default in-memory storage is for testing/development only and must be replaced before production - with multiple Gunicorn workers each process keeps its own counters, so the effective limit silently multiplies; back it with a shared store like Redis. For most makers, doing the throttling at Cloudflare's edge is even simpler than app-level limits.

**Sources:** <https://blog.cloudflare.com/counting-things-a-lot-of-different-things/> · <https://flask-limiter.readthedocs.io/>

### Error logging / observability

**What it is.** Observability is the ability to understand a system from the outside - asking new questions about its behaviour using only the telemetry it emits, without shipping new code (e.g. 'why is this one user's checkout failing?'). It's commonly built from three signals: logs (timestamped event records - your source of truth for what happened), metrics (cheap numeric aggregates like error rate or request rate that tell you something is wrong), and traces (follow one request across services to show where time went; the unit of work within a trace is a span). OpenTelemetry (OTel) is the open, vendor-neutral standard/instrumentation for emitting all three.

**Why it matters.** You cannot optimise, set SLOs, or trust rate limits without first being able to see what your system is doing. Monitoring tells you a known thing broke; observability lets you investigate 'unknown unknowns'. Error logging specifically is the minimum: when a Flask request 500s at 3am, a captured stack trace turns a mystery into a five-minute fix. Metrics are also what every other topic here is measured in (QPS, latency percentiles, availability).

**When to use it.** Start the moment you run any server-side code - even a single error tracker is worth it on day one of a backend. Grow into structured logs + a few key metrics (error rate, latency p95, request rate) as traffic grows, and add tracing only once you have multiple services to correlate. The simpler alternative early on: a hosted error-tracking service (e.g. Sentry) plus your platform's built-in logs - do NOT stand up a full metrics/tracing stack for a low-traffic app; that's operational overhead you don't need yet.

**Relevance / when it's worth it.** Static sites barely need it - Cloudflare analytics plus the browser console covers you, since there's no server to fail silently. This is arguably the single most valuable topic in the cluster once you have a Flask backend or database: wire up exception logging first, then a handful of metrics. For Electron apps the desktop equivalent is crash/error reporting so you learn about failures on machines you can't see. Prefer OpenTelemetry/hosted tools so you're not reinventing log/metric plumbing.

**Sources:** <https://opentelemetry.io/docs/concepts/observability-primer/> · <https://www.ibm.com/think/insights/observability-pillars>

**Key references:** [Google SRE Book - Service Level Objectives (SLI/SLO/SLA, nines, latency percentiles)](https://sre.google/sre-book/service-level-objectives/) · [Google SRE Book - Embracing Risk (error budgets, cost of each extra nine, why 100% is the wrong target)](https://sre.google/sre-book/embracing-risk/) · [AWS Well-Architected Framework - Performance Efficiency Pillar](https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/welcome.html) · [OpenTelemetry - Observability Primer (telemetry, logs, metrics, traces, spans)](https://opentelemetry.io/docs/concepts/observability-primer/) · [IBM - Three Pillars of Observability: Logs, Metrics and Traces](https://www.ibm.com/think/insights/observability-pillars) · [Cloudflare Blog - How we built rate limiting (sliding window vs token/leaky bucket, ~0.003% accuracy across 400M requests)](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/) · [Flask-Limiter documentation (rate limits, 429s, storage backends, in-memory dev-only warning)](https://flask-limiter.readthedocs.io/) · [Randall Hyde / ACM Ubiquity - The Fallacy of Premature Optimization (profile before optimising; full Knuth quote)](https://ubiquity.acm.org/article.cfm?id=1513451)

---

## Dev workflow, tooling & ML

This cluster covers the everyday tools that surround the code itself: version control and collaboration (Git/GitHub), a precise surgical tool within Git (cherry-pick), a heavyweight Python IDE (PyCharm), and a production ML framework (TensorFlow). For a maker shipping static GitHub Pages sites plus some Flask/Electron apps, Git and GitHub are foundational and used daily regardless of stack size. PyCharm is genuinely useful once Python/Flask code grows past a few files, while git cherry-pick and TensorFlow are specialist tools you reach for only in specific situations and can mostly ignore until a real need appears.

### git / GitHub

**What it is.** Git is a free, open-source distributed version control system (DVCS) that records the full history of changes to your files; every clone is a complete copy of the project plus its entire history, so you can work and commit offline. GitHub is a separate, web-based platform that hosts Git repositories and layers collaboration features on top: pull requests, code review, issues, CI/CD via GitHub Actions, and static hosting via GitHub Pages. The key distinction: Git is the engine you run locally; GitHub is one (popular) hosting service for it, alongside GitLab, Bitbucket, and self-hosting.

**Why it matters.** Git gives you a safe undo button for an entire project, a record of who changed what and when, and the ability to experiment on branches without breaking working code. GitHub turns that local tool into a backup, a collaboration hub, and a deployment target, which is exactly how a static site reaches the web on Pages.

**When to use it.** Use Git for literally every project from day one, even a one-file static site; the cost is near zero and the safety net is large. Use GitHub when you want remote backup, want to collaborate or share, or want free static hosting/CI. A common misconception is that you 'need' GitHub to use Git: you do not. For a purely private local experiment Git alone is fine, and if you dislike GitHub's terms, GitLab or a bare remote on your own server work identically.

**Relevance / when it's worth it.** This is the backbone of the reader's entire workflow. The static sites are almost certainly deployed straight from a GitHub repo via GitHub Pages (behind Cloudflare), and the Flask and Electron apps live in Git too. As the reader grows toward backend/DB hosting, the same repos drive CI/CD pipelines and deploys to a real server, so investing in solid Git habits (small commits, branches, meaningful messages) pays off across every tier of the stack. Note GitHub Pages is static-only and cannot run the Flask backend, so the database/backend work will be hosted elsewhere even while the code stays on GitHub.

**Sources:** <https://git-scm.com/> · <https://docs.github.com/en/get-started/using-git/about-git>

### git cherry-pick

**What it is.** git cherry-pick takes the changes introduced by one or more specific existing commits and re-applies them onto your current branch, creating brand-new commits (new SHAs, same diff) for each. It is a targeted alternative to merge/rebase: instead of integrating an entire branch's history, you pick out just the commit(s) you want. It requires a clean working tree, can hit conflicts you resolve like a merge, and supports --continue/--skip/--abort plus useful flags like -x (records 'cherry picked from commit ...') and -n (apply without committing).

**Why it matters.** It solves the 'I need just this one fix over here, not the whole branch' problem, for example landing a hotfix on main while the feature branch that contains it isn't ready, or backporting a single bug fix to an older release branch. It also rescues valuable commits from an abandoned branch before you delete it.

**When to use it.** Reach for it sparingly and deliberately, for hotfixes, backports, or salvaging a stray commit. The official guidance and community consensus is to prefer merge or rebase when possible, because cherry-pick creates duplicate commits that can muddy history and cause confusing conflicts if the branches later merge. When NOT to use it: as a routine substitute for merging branches, or to move a long series of commits (rebase is cleaner there). If you find yourself cherry-picking constantly, your branching strategy is probably the real issue.

**Relevance / when it's worth it.** Mostly overkill for a solo maker on small static sites with a single main branch, where there's rarely a second branch to pick from. It becomes genuinely useful once the reader runs longer-lived branches or release branches for the Flask/backend app, e.g. cherry-picking an urgent security fix onto a deployed branch without shipping half-finished features. File it under 'know it exists, use it occasionally,' not a daily tool.

**Sources:** <https://git-scm.com/docs/git-cherry-pick> · <https://www.atlassian.com/git/tutorials/cherry-pick>

### PyCharm (IDE)

**What it is.** PyCharm is JetBrains' integrated development environment for Python, built on the IntelliJ platform. It bundles a smart editor (context-aware completion, type hints, auto-imports), project-wide refactoring, a powerful debugger (local, remote, virtualenv, and container), test-runner integration, and built-in database tooling (PostgreSQL, MySQL, MongoDB, Redis, and more, with a SQL console) plus support for web technologies (JavaScript, TypeScript, HTML, CSS) and frameworks like Flask and Django. As of the 2025.1 release PyCharm became a single unified product: core features (including Jupyter) are free, with a paid Pro subscription for advanced capabilities; the separate Community Edition was wound down (2025.2 was the last standalone Community build, and from 2025.3 Community users move to the unified product).

**Why it matters.** For non-trivial Python projects an IDE removes a lot of friction: it catches errors as you type, makes refactors safe across the whole project, and gives you a real visual debugger instead of scattered print statements. The integrated DB client means you can browse and query your database without leaving the editor.

**When to use it.** Use PyCharm once a Python/Flask codebase grows past a handful of files or you're doing real debugging, refactoring, or database work, the debugger and refactoring tools earn their keep there. The simpler alternative is VS Code with the Python extension, which is lighter, free, also excellent, and arguably a better single editor when you're juggling Python, JS, and Electron in one place. When NOT to use it: for editing a static site's HTML/CSS/JS, PyCharm is heavyweight overkill; a lightweight editor starts faster and does the job.

**Relevance / when it's worth it.** Marginal for the static-site work, but a strong fit as the reader grows toward Flask backends and database hosting, exactly the area where PyCharm's debugger and built-in PostgreSQL/Redis clients shine. One practical caveat: the reader's stack spans Python plus Electron (Node/JS), and a single VS Code window may cover all of it more smoothly, so the honest call is to try the free PyCharm tier for the Flask/DB work and compare, rather than assuming you must pay for Pro.

**Sources:** <https://www.jetbrains.com/pycharm/> · <https://blog.jetbrains.com/pycharm/2025/04/unified-pycharm/>

### TensorFlow (ML framework)

**What it is.** TensorFlow is Google's open-source, end-to-end machine learning platform, primarily for building and training neural networks (deep learning) for tasks like classification, computer vision, and NLP. Its high-level API is Keras for model building; the broader ecosystem includes TensorFlow Lite/LiteRT (mobile and embedded), TensorFlow.js (run models in the browser or Node.js), TensorFlow Serving (production inference servers), and TFX (production ML pipelines/MLOps). It runs on CPUs, GPUs, and Google's TPUs, and deploys to servers, edge devices, browsers, and microcontrollers.

**Why it matters.** It solves the heavy lifting of ML: defining models, computing gradients, training efficiently on accelerators, and then deploying the trained model across very different targets. It matters when your product needs genuine learned behavior (image recognition, recommendations, language tasks) rather than hand-written rules.

**When to use it.** Reach for TensorFlow only when you have a real ML problem, meaningful training data, and a reason a learned model beats simpler logic. Even then, consider the alternatives honestly: PyTorch is now the more common default for new research and a large and growing share of new production work; scikit-learn is far simpler for classical (non-deep-learning) tasks; and for adding 'AI' features many makers now just call a hosted model API instead of training anything. When NOT to use it: do not pull in TensorFlow to add a chatbot or a single AI feature you could get from an API, the operational and learning cost is large.

**Relevance / when it's worth it.** Almost entirely overkill for the reader's current stack of static sites and small Flask/Electron apps; nothing here needs a custom-trained neural network. The realistic on-ramp, if ML ever becomes relevant, is TensorFlow.js to run a small pre-trained model client-side in a static page (no backend required), or serving a model behind the Flask API once backend hosting exists. Treat full TensorFlow training and TFX pipelines as a distant, specialized step you adopt only when a concrete ML need and data are in hand, not as part of the core website-building toolkit.

**Sources:** <https://www.tensorflow.org/learn> · <https://github.com/tensorflow/tensorflow>

**Key references:** [Git (official site) - distributed version control system](https://git-scm.com/) · [About Git - GitHub Docs (Git vs GitHub)](https://docs.github.com/en/get-started/using-git/about-git) · [git-cherry-pick Documentation - git-scm.com](https://git-scm.com/docs/git-cherry-pick) · [Git Cherry Pick - Atlassian Git Tutorial](https://www.atlassian.com/git/tutorials/cherry-pick) · [PyCharm - JetBrains (official product page)](https://www.jetbrains.com/pycharm/) · [PyCharm, the Only Python IDE You Need (unified product, free core + Pro) - JetBrains Blog](https://blog.jetbrains.com/pycharm/2025/04/unified-pycharm/) · [Introduction to TensorFlow - tensorflow.org](https://www.tensorflow.org/learn) · [Creating a GitHub Pages site - GitHub Docs (static only, no server-side languages)](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site)

---


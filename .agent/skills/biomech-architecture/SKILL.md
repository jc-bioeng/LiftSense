---
name: biomech-architecture
description: Organizes Python backend and biomechanical processing engines for scalability and future Docker deployment. Use when structuring a FastAPI project, separating domain logic from infrastructure, or preparing for containerization.
---

# Biomech Architecture Skill

This skill ensures that biomechanical processing systems are structured for:

- Clean separation of concerns
- Future Docker containerization
- Horizontal scalability
- Asynchronous processing
- Scientific reproducibility

It is designed for projects using:
- Python
- FastAPI
- Scientific processing (FFT, filtering, ML)
- Docker (current or future)

---

# When to Use This Skill

Use this skill when:

- Starting a new backend project
- Refactoring a monolithic prototype
- Preparing a system for Docker
- Separating API logic from processing logic
- Adding authentication and database layers
- Planning scalability with workers

Do NOT use this skill for:
- Simple scripts
- One-off data analysis notebooks
- Frontend-only applications

---

# Core Architectural Principles

## 1. Separate API from Engine

The biomechanical engine must NEVER be tightly coupled to FastAPI routes.

Correct:


app/
├── api/
├── services/
├── domain/
├── infrastructure/
└── main.py

biomech_engine/
├── pipelines/
├── core/
├── preprocessing/
└── init.py


The API calls the engine.
The engine does NOT know the API exists.

---

## 2. The Engine Must Be Importable

The processing system must run both:

- As a Python module
- Inside a worker container
- Independently from the API

It should support:

```python
from biomech_engine import run_pipeline

Avoid embedding processing logic directly inside route handlers.

3. Domain-Driven Structure

Backend structure should follow:

app/
├── api/                # Routes only
├── domain/             # Entities and business logic
├── services/           # Use cases
├── repositories/       # DB interaction
├── infrastructure/     # External systems (Redis, DB, etc.)
└── config/

Rules:

Routes call services

Services coordinate domain logic

Domain never imports infrastructure

Infrastructure never contains business logic

Docker-Ready Design Rules
Rule 1: One Responsibility per Container

Target architecture:

api container

postgres container

redis container

worker container (biomech processing)

Do not mix:

Web server + DB

API + background workers

Processing + migration scripts

Rule 2: Environment Variables Only

Never hardcode:

DB credentials

Redis URLs

Secret keys

Use environment variables for everything.

Rule 3: Async Processing Preparation

All heavy biomechanical computations must be designed so they can move to workers later.

Even if currently synchronous, design endpoints like:

POST /analyze → returns job_id

GET /results/{job_id}

Avoid blocking API routes with long FFT or ML tasks.

Pipeline Versioning Strategy

All pipelines must be:

Named

Versioned

Registered centrally

Example:

pipelines/
├── registry.py
├── knee_fft_v1.py
├── knee_fft_v2.py

Registry pattern:

Central dictionary of pipelines

API only references pipeline names

Engine resolves implementation

This guarantees reproducibility.

Database Preparation Strategy

Minimum future-ready tables:

Users
AnalysisJobs
Results
Pipelines (optional)

Never store raw signals in the same table as user metadata.

Separate:

metadata

raw data

processed results

Docker Folder Blueprint

When preparing for containerization:

project-root/
├── app/
├── biomech_engine/
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── .env

Later scalable form:

services/
├── api/
├── worker/
└── engine/
Decision Tree

If project is:

Prototype only?
→ Single API container OK
→ Keep engine separate logically

Adding users?
→ Add Postgres container
→ Implement auth layer

Adding heavy computation?
→ Introduce Redis
→ Move engine to worker container

High concurrency?
→ Scale worker replicas
→ Keep API stateless

Anti-Patterns to Avoid

FFT inside route handler

Database calls inside pipelines

Business logic inside API routes

Hardcoded secrets

Circular imports between engine and API

Execution Checklist

When applying this skill:

Verify engine is independent

Verify API imports engine, not vice versa

Confirm no processing inside routes

Ensure environment variables are used

Prepare structure for worker separation

Confirm Dockerfile isolates dependencies

Ensure pipelines are versioned

Outcome

After applying this skill, the project should:

Be Docker-ready

Be scalable

Be modular

Be reproducible for scientific work

Support future async workers without refactor
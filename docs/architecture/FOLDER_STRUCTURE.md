# Folder Structure

This document outlines the organization of the LifeSense project, following the principles of scientific scalability and mobile-first development.

```text
LifeSense/
│
├── backend/                # Python Backend (FastAPI + Biomech Engine)
│   ├── app/                # FastAPI Application (API Layer)
│   │   ├── api/            # API Routes and Endpoints
│   │   ├── domain/         # Business Entities and Domain Logic
│   │   ├── services/       # Use Case Coordinators
│   │   └── infrastructure/ # External Services and App Config
│   ├── biomech_engine/     # Decoupled Biomechanical Core
│   │   ├── core/           # Anatomical Correction and Kinematics
│   │   ├── pipelines/      # Versioned Analysis Routines
│   │   └── preprocessing/  # Signal Processing and Filters
│   ├── requirements.txt    # Python Dependencies
│   └── Dockerfile          # Container Configuration
│
├── frontend/               # Flutter Mobile Application
│   ├── lib/
│   │   ├── l10n/           # Internationalization (ES/EN)
│   │   └── localization/   # Locale Management
│   └── pubspec.yaml        # Flutter Dependencies
│
├── research/               # Scientific R&D
│   ├── experiments/        # Recorded Data and Test Protocols
│   ├── notebooks/          # Jupyter Notebooks for Analysis
│   └── validation/         # Benchmarking against Lab References
│
├── docs/                   # Documentation
│   ├── architecture/       # System Design and Structures
│   ├── decisions/          # Architectural Decision Records (ADR)
│   └── diagrams/           # Visual Workflows and Schematics
│
├── .github/                # CI/CD Workflows
├── VERSION                 # Current Project Version
└── README.md
```

## Core Principles

1. **Separation of Concerns**: The `biomech_engine` is independent of the `app` (API), allowing scientific logic to be tested and versioned separately.
2. **Domain-Driven Design (DDD)**: The `backend/app` uses clear layering to separate API routes from business logic and infrastructure.
3. **Mobile-First Localization**: The `frontend` includes a dedicated `l10n` structure from day one.
4. **Reproducibility**: The `research` folder stores the notebooks and validation data necessary to defend the biomechanical results.

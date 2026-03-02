# Architecture Documentation Index

Welcome to the LiftSense architecture documentation. This directory contains detailed specifications of the system design, data models, and process flows.

## Core Documentation

1. **[System Overview](system_overview.md)**: High-level architecture, components, and technology stack.
2. **[Database Schema](../../backend/schema.sql)**: (SQL) The primary PostgreSQL definition for Supabase.
3. **[Security Model](security_model.md)**: RLS policies, roles, and subscription enforcement.
4. **[Coach-Athlete Flow](coach_athlete_flow.md)**: Onboarding lifecycle, feature inheritance, and plan limits.
5. **[User Interaction Flow](user_interaction_flow.md)**: Primary user journeys and paths.

## UML & Logic Diagrams

1. **[Database ER Diagram](../diagrams/database_er.md)**: Main entity relationships.
2. **[RLS Flow Diagram](../diagrams/rls_flow.md)**: Logic schematic for security and access control.
3. **[Detailed RLS Documentation](rls_policies_detailed.md)**: Deep dive into policy logic and performance.
4. **[Process Flow](../diagrams/process_flow.md)**: (TBD) Sequence of capture to analysis.

## Key Decisions (ADR)

1. **[Biomech Core Placement](../decisions/2026-02-24_biomech_core_placement.md)**: Logic for engine/API decoupling.
2. **[Security and Coach Roles](../decisions/2026-02-24_security_and_coach_roles.md)**: Foundation for multi-user access (Coach-Athlete).
3. **[RLS Optimization and Limits](../decisions/2026-03-01_rls_optimization_and_subscription_limits.md)**: Performance tuning and subscription enforcement logic.

## Compliance & Security

1. **[Formal Security Audit (2026-03-01)](../security/audit_2026_03_01.md)**: Full validation of data integrity and RLS logic.

## Architectural Principles

LiftSense follows these core principles to ensure scientific rigor and scalability:

- **Decoupled Engine**: The biomechanical processing logic is independent of the API and frontend.
- **Async Execution**: Heavy kinematic/kinetic models are processed asynchronously to maintain UI responsiveness.
- **Single Source of Truth**: Supabase acts as the centralized coordinator for Auth, DB, and Storage.
- **Interpretable Output**: Every metric stored includes units and phase context to ensure scientific transparency.

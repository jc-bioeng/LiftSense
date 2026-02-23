# Architecture Documentation Index

Welcome to the LiftSense architecture documentation. This directory contains detailed specifications of the system design, data models, and process flows.

## Core Documentation

1. **[System Overview](system_overview.md)**: High-level architecture, components, and technology stack.
2. **[Database Schema](file:///c:/flutter_projects/LiftSense/backend/supabase/migrations/20260222213000_schema.sql)**: (SQL) The primary PostgreSQL definition for Supabase.

## UML Diagrams

- **[Database ER Diagram](../diagrams/database_er.md)**: Visual representation of tables and relationships.
- **[Process Flow](../diagrams/process_flow.md)**: Sequence diagram of a biomechanical analysis lifecycle.

## Architectural Principles

LiftSense follows these core principles to ensure scientific rigor and scalability:

- **Decoupled Engine**: The biomechanical processing logic is independent of the API and frontend.
- **Async Execution**: Heavy kinematic/kinetic models are processed asynchronously to maintain UI responsiveness.
- **Single Source of Truth**: Supabase acts as the centralized coordinator for Auth, DB, and Storage.
- **Interpretable Output**: Every metric stored includes units and phase context to ensure scientific transparency.

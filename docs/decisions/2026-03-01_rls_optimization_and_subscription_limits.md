# ADR: RLS Performance Optimization and Subscription Enforcement

**Date**: 2026-03-01
**Status**: Decided & Implemented

## Context

As the LiftSense database schema matured, the Row Level Security (RLS) policies became fragmented, leading to two primary issues:
1.  **Performance Degradation**: Standard calls to `auth.uid()` were being re-evaluated for every row during scans, posing a risk for high-volume tables (`landmarks`, `metrics`).
2.  **Security Lint Warnings**: Supabase identified "Multiple Permissive Policies" (e.g., overlapping `INSERT` rules for admins and owners), which are suboptimal for performance and auditability.
3.  **Monetization Readiness**: The system required an enforcement mechanism for tiered subscription plans and guest session governance.

## Decisions

### 1. Unified RLS Policy Pattern
Instead of multiple specialized policies per action (SELECT, INSERT, etc.), each table now uses a single **Unified Policy** (`main_policy`).
- **Pattern**: `CREATE POLICY "table_main_policy" ON table FOR ALL TO authenticated USING (...)`.
- **Logic**: Combines Owner, Admin, and Relationship checks into a single boolean expression.
- **Benefit**: Reduces Postgres policy evaluation overhead and clarifies access intent.

### 2. Deterministic Identity Subqueries
To ensure O(1) performance for identity checks:
- **Pattern**: Replaced `auth.uid()` with `(SELECT auth.uid())`.
- **Mechanism**: The subquery forces the PostgreSQL planner to execute the function once at query start and treat the result as a constant during the scan, rather than executing it for every single row.

### 3. Dynamic SQL Cleanup
To ensure no legacy or orphan policies remain (which cause the "Multiple Permissive Policies" warning), we implemented a dynamic SQL block in migrations that aggressively drops all existing policies in the `public` schema before applying the new unified ones.

### 4. Tiered Limit Enforcement via Triggers
Business logic for usage limits was moved to the database layer for maximum integrity:
- **Guest Daily Limit**: Restricted to 2 sessions per 24-hour sliding window (calculated via `created_at`).
- **Coach Athlete Tiers**: Enforced count limits on `profile_relations` based on `plan_type`:
    - `starter`: 5 athletes.
    - `pro`: 20 athletes.
    - `elite`: Unlimited.

## Consequences

- **Pros**:
    - Eliminated all Supabase/PostgreSQL security and performance lint warnings.
    - Simplified security audits: only one rule to check per table.
    - Direct enforcement of business limits regardless of client-side implementation.
- **Cons**:
    - Unified policies are slightly more complex boolean expressions.
    - Manual policy testing (via `pgTAP` or manual role switching) is required to ensure no regressions in specialized actions (e.g., ensuring a user can't update a field they should only select, although handled by `WITH CHECK`).

## References
- [Security Model](../architecture/security_model.md)
- [RLS Flow Diagram](../diagrams/rls_flow.md)
- [Migration: Force RLS Consolidation](../../backend/supabase/migrations/20260301222000_force_rls_consolidation.sql)

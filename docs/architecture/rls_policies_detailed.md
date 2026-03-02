# Detailed RLS Policy Documentation

This document provide a deep dive into the Row Level Security (RLS) policies implemented in LiftSense. Our security model focuses on **Privacy**, **Performance**, and **Scalability**.

---

## 1. Global Performance Pattern: Deterministic Identity

Every policy in the system uses the `(SELECT auth.uid())` pattern instead of a simple `auth.uid()` call.

### The Problem
In PostgreSQL, calling a function (like `auth.uid()`) inside a policy check can cause the query planner to re-evaluate that function for **every single row** processed. In tables like `landmarks` or `metrics` which contain millions of rows, this leads to catastrophic performance degradation.

### The Solution: Deterministic Subqueries
By wrapping the call in a subquery:
```sql
USING (user_id = (SELECT auth.uid()))
```
PostgreSQL is forced to execute the subquery **once** at the beginning of the statement and treat the result as a constant for the duration of the scan. This ensures $O(1)$ identity evaluation regardless of table size.

---

## 2. Shared Access: The "Linked Coach" Pattern

The most complex security logic resides in the `sessions`, `landmarks`, and `metrics` tables, where both the **Owner** (Athlete) and their **Active Coach** must have access.

### SQL Logic (Simplified)
```sql
USING (
  user_id = (SELECT auth.uid()) -- Owner check
  OR get_user_role() = 'admin'  -- Admin override
  OR EXISTS (                  -- Relationship check
    SELECT 1 FROM public.profile_relations 
    WHERE coach_id = (SELECT auth.uid()) 
    AND athlete_id = sessions.user_id 
    AND status = 'active'
  )
)
```

### Rationale
-   **Direct Ownership**: An athlete always owns their data.
-   **Active Relation**: A coach can only see data if a relationship exists in `profile_relations` and the `status` is explicitly `'active'`.
-   **Admin Global View**: Admins can bypass RLS for support and maintenance using the `get_user_role()` helper.

---

## 3. Policy List & Rationale

### `profiles` (Table: `profiles`)
-   **Policy**: `profiles_main_policy`
-   **Logic**: `id = (SELECT auth.uid()) OR admin`
-   **Note**: Restricts users to only managing their own profile metadata.

### `anthropometry_profiles` (Table: `anthropometry_profiles`)
-   **Policy**: `anthro_main_policy`
-   **Logic**: `user_id = (SELECT auth.uid()) OR admin`
-   **Note**: Ensures sensitive biometric data is only visible to the user it belongs to.

### `profile_relations` (Table: `profile_relations`)
-   **Policy**: `relations_main_policy`
-   **Logic**: `coach_id = (SELECT auth.uid()) OR athlete_id = (SELECT auth.uid()) OR admin`
-   **Note**: A training contract is only visible to the two parties involved.

### `sessions`, `landmarks`, `metrics`
-   **Policy**: `*_main_policy`
-   **Logic**: Uses the **Linked Coach Pattern** (see section 2).
-   **Note**: High-performance triggers also enforce caps on these tables (e.g., guest session limits) to prevent resource exhaustion.

---

## 4. Auditing & Safety

-   **Unified Policies**: We use `FOR ALL TO authenticated` to ensure that anonymous users (`anon`) have zero access to the API by default, and to avoid policy overlap errors.
-   **Cascading Security**: Because `landmarks` and `metrics` inherit visibility from the parent `session`, we ensure that if a session is private, all its associated time-series data is also protected.
-   **Search Path Hardening**: All security functions are defined with an explicit `search_path` (e.g., `SET search_path = public, pg_catalog`) to prevent "search path hijacking" attacks.

---

## 5. Security Decision Records (ADRs)

For the history of how these decisions were reached and the issues they fixed, see:
1.  **[ADR: RLS Performance Optimization](../decisions/2026-03-01_rls_optimization.md)** (Performance and subqueries)
2.  **[ADR: Subscription Enforcement](../decisions/2026-03-01_subscription_enforcement.md)** (Trigger-based gates)

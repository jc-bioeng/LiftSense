---
name: db-security-integrity
description: Guides the protection and hardening of the PostgreSQL/Supabase database layer. Ensures RLS consistency, high performance, and robust business logic enforcement.
---

# Database Security & Integrity Skill

This skill ensures that any modification to the LiftSense database follows the established security and performance standards. It protects against regressions in access control and performance degradation.

## Core Mandates

### 1. The Unified RLS Pattern
Every table MUST have exactly ONE unified policy for authenticated users.
- **Goal**: Avoid "Multiple Permissive Policies" warnings and simplify auditability.
- **Pattern**: `FOR ALL TO authenticated USING (...) WITH CHECK (...)`.
- **Exclusion**: Service roles and admins should be handled within the same unified logic or via specific bypasses.

### 2. Performance: Deterministic Identity
Never use `auth.uid()` directly in a policy that scans large tables.
- **Rule**: Always wrap in a subquery: `(SELECT auth.uid())`.
- **Reason**: This forces PostgreSQL to evaluate the identity once per statement instead of once per row, maintaining $O(1)$ performance.

### 3. Business Logic: Trigger-Based Gates
Usage limits (session caps, plan tiers) MUST be enforced via `BEFORE INSERT` triggers.
- **Security Definer**: Triggers checking other tables (like `profiles`) for plan status MUST be defined as `SECURITY DEFINER`.
- **Search Path**: Every function MUST have an explicit `SET search_path = public, pg_catalog`.

### 4. Integrity: Cascading & Constraints
- **Self-Governance**: Use `CHECK` constraints (like `no_self_relation`) to prevent logical errors.
- **Cleanup**: Ensure `ON DELETE CASCADE` is set on foreign keys to prevent "garbage" data buildup.

## Modification Checklist

Before applying any migration (`supabase db push`):

1. [ ] **Consolidation**: Does the new table have only one Master Policy?
2. [ ] **Subqueries**: Are all identity checks using `(SELECT auth.uid())`?
3. [ ] **Search Path**: Do all new functions have a locked `search_path`?
4. [ ] **Audit Script**: Run the consolidated audit script to verify no regressions.
5. [ ] **Documentation**: Update `docs/architecture/security_model.md` if schema changes.

## Security Audit Snippet
Use this to verify the state of a table after modification:

```sql
SELECT tablename, rowsecurity, 
       (SELECT count(*) FROM pg_policies p WHERE p.tablename = t.tablename) as policy_count
FROM pg_tables t 
WHERE schemaname = 'public' AND tablename = 'YOUR_TABLE_NAME';
```

---
> [!IMPORTANT]
> Failure to use `SECURITY DEFINER` in triggers can lead to subtle "blind bypasses" where the trigger sees NULL instead of the coach's plan due to RLS.

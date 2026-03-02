# Security & Access Control Model

LiftSense uses a robust security model based on **Supabase Auth** and **PostgreSQL Row Level Security (RLS)**. This ensures data isolation and integrity from the database layer, regardless of the client used.

## Core Principles

1.  **Identity-First**: All access is tied to a verified `auth.uid()`.
2.  **Strict Isolation**: Users can only see and modify their own biomechanical data.
3.  **Role-Based Access Control (RBAC)**: An internal `role` in the `profiles` table determines broader permissions.

## User Roles

| Role      | Scope      | Description                                                                 |
| :-------- | :--------- | :-------------------------------------------------------------------------- |
| `admin`   | Global     | Can view and manage all profiles and sessions.                              |
| `coach`   | Managed    | Access managed at plan level (Starter/Pro/Elite). Manage multiple athletes. |
| `athlete` | Owner Only | Can view and manage only their own sessions and anthropometry.              |
| `guest`   | Restricted | Limit of **2 sessions per 24 hours**. Purged/Anonymized regularly.          |

## Subscription Plans

LiftSense uses a tiered model to manage processing resources and collaborative features:

| Plan            | Target         | Limits                                  |
| :-------------- | :------------- | :-------------------------------------- |
| `free`          | Athletes       | Standard biomechanical analysis.        |
| `pro`           | Advanced Users | Priority processing, historical trends. |
| `coach_starter` | Small Teams    | Manage up to **5 athletes**.            |
| `coach_pro`     | Professional   | Manage up to **20 athletes**.           |
| `coach_elite`   | Organizations  | **Unlimited athletes**.                 |

## Advanced Security Mechanisms

### Multi-User Access (Coach → Athlete)
Relationships are established in the `profile_relations` table. RLS policies for sessions and biomechanical data check for an active relation:
```sql
EXISTS (
  SELECT 1 FROM public.profile_relations 
  WHERE coach_id = (SELECT auth.uid()) 
  AND athlete_id = (sessions.user_id) 
  AND status = 'active'
)
```

### Guest Governance
A database trigger `trg_guest_session_limit` enforces a maximum of **2 sessions per 24 hours** for any user with the `guest` role. This ensures fair resource allocation for unverified accounts.

### Coach Relation Governance
A database trigger `trg_coach_athlete_limit` enforces two checks before allowing a coach to link a new athlete:
1. **Subscription Gate**: Only coaches with `subscription_status` of `active` or `trial` may add athletes. Coaches with `canceled` or `past_due` status are blocked.
2. **Plan Capacity**: Athlete count limit based on the coach's `plan_type` (`starter` -> 5, `pro` -> 20, `elite` -> Unlimited).

See [Coach-Athlete Flow](coach_athlete_flow.md) for the full onboarding lifecycle.

## RLS Implementation Details

### Helper Functions

We use a helper function to avoid repeated complex joins in policies:

```sql
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
  SELECT role FROM public.profiles WHERE id = (SELECT auth.uid());
$$ LANGUAGE sql STABLE
SET search_path = public, pg_catalog;
```

All tables have RLS enabled with a **Unified Policy Pattern** (`FOR ALL TO authenticated`) to minimize evaluation overhead and eliminate multiple permissive policy warnings. 

### Performance Optimization
To ensure scalability, all policies use a **Deterministic Subquery Pattern**:
- **Pattern**: `(SELECT auth.uid())` instead of just `auth.uid()`.
- **Benefit**: Forces Postgres to execute the function once per query (constant value), rather than once per row, drastically improving performance on high-volume tables like `landmarks` and `metrics`.

### Core Table Policies
- **Profiles (`profiles_main_policy`)**: Unified rule for owners and admins.
- **Sessions/Anthro (`sessions_main_policy`, `anthro_main_policy`)**: Unified rule allowing access if the user is the owner, an admin, or an active coach.
- **Landmarks/Metrics (`landmarks_main_policy`, `metrics_main_policy`)**: Inherited access via `EXISTS` checks on parent sessions.

## Security Integrity

- **Database Triggers**: Used to enforce business rules (like single active anthropometry) that cannot be bypassed via the API.
- **Cascading Deletes**: User profile deletion automatically wipes all associated biomechanical data to comply with privacy regulations (GDPR/HIPAA ready).

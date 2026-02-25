# Security & Access Control Model

LiftSense uses a robust security model based on **Supabase Auth** and **PostgreSQL Row Level Security (RLS)**. This ensures data isolation and integrity from the database layer, regardless of the client used.

## Core Principles

1.  **Identity-First**: All access is tied to a verified `auth.uid()`.
2.  **Strict Isolation**: Users can only see and modify their own biomechanical data.
3.  **Role-Based Access Control (RBAC)**: An internal `role` in the `profiles` table determines broader permissions.

## User Roles

| Role      | Scope      | Description                                                                  |
| :-------- | :--------- | :--------------------------------------------------------------------------- |
| `admin`   | Global     | Can view and manage all profiles and sessions.                               |
| `coach`   | Managed    | View their own data AND their active athletes' data via `profile_relations`. |
| `athlete` | Owner Only | Can view and manage only their own sessions and anthropometry.               |
| `guest`   | Restricted | Limit of 3 sessions total. Purged/Anonymized regularly.                      |

## Advanced Security Mechanisms

### Multi-User Access (Coach → Athlete)
Relationships are established in the `profile_relations` table. RLS policies for sessions and biomechanical data check for an active relation:
```sql
EXISTS (
  SELECT 1 FROM profile_relations 
  WHERE coach_id = auth.uid() 
  AND athlete_id = sessions.user_id 
  AND status = 'active'
)
```

### Guest Governance
A database trigger `trg_guest_session_limit` enforces a maximum of 3 sessions for any user with the `guest` role. This prevents systematic abuse of processing resources by unverified accounts.

## RLS Implementation Details

### Helper Functions

We use a helper function to avoid repeated complex joins in policies:

```sql
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE;
```

### Table Policies

All tables have RLS enabled. Example policies (Simplified):

- **Profiles**: Restricted by `id = auth.uid()` for updates; admin can `SELECT` all.
- **Sessions/Anthropometry**: Restricted by `user_id = auth.uid()` or `get_user_role() = 'admin'`.
- **Landmarks/Metrics**: Restricted via `EXISTS` checks on the parent `sessions` ownership.

## Security Integrity

- **Database Triggers**: Used to enforce business rules (like single active anthropometry) that cannot be bypassed via the API.
- **Cascading Deletes**: User profile deletion automatically wipes all associated biomechanical data to comply with privacy regulations (GDPR/HIPAA ready).

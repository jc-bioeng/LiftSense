# RLS & Policy Architecture

This diagram illustrates how authentication, roles, and business rules (subscriptions/limits) intersect at the database layer to ensure data integrity and security.

```mermaid
graph TD
    User((Auth User)) -->|JWT Token| Supabase[Supabase API]
    Supabase -->|get_user_role| RoleCheck{Role Check}
    
    subgraph AccessLogic [Unified RLS Policy Layer]
        RoleCheck -->|SELECT auth.uid| Identity[Deterministic Identity]
        Identity --> UnifiedPolicy[Main Table Policy]
        
        UnifiedPolicy -->|Role: owner| OwnData[Personal Records]
        UnifiedPolicy -->|Role: admin| AdminAccess[Global Records]
        UnifiedPolicy -->|Active Relation| AthleteData[Managed Athlete Data]
        
        OwnData -->|Inheritance| SubData[Landmarks / Metrics]
        AthleteData -->|Inheritance| SubData
    end

    subgraph DataTables [PostgreSQL Tables]
        UnifiedPolicy --> Profiles[(Profiles)]
        UnifiedPolicy --> Sessions[(Sessions)]
        UnifiedPolicy --> ProfileRelations[(ProfileRelations)]
        
        SubData --> Landmarks[(Landmarks)]
        SubData --> Metrics[(Metrics)]
    end

    subgraph BusinessEnforcement [Triggers / Gates]
        Sessions -->|BEFORE INSERT| GuestLimit[Guest Session Gate]
        GuestLimit -->|Check: 2 sessions / 24h| Deny1((Exception))
        
        ProfileRelations -->|BEFORE INSERT| CoachGate[Coach Multi-Gate]
        CoachGate -->|Check: Subscription active| Deny2((Exception))
        CoachGate -->|Check: Plan Capacity| Deny2
    end
```

## Detailed Policy Breakdown

| Table          | Policy Name             | Condition (Logic)                    | Purpose                                |
| :------------- | :---------------------- | :----------------------------------- | :------------------------------------- |
| **Profiles**   | `profiles_main_policy`  | `owner` OR `admin`                   | Self-management and admin oversight.   |
| **Sessions**   | `sessions_main_policy`  | `owner` OR `admin` OR `linked_coach` | Primary data access for analysis.      |
| **Anthro**     | `anthro_main_policy`    | `owner` OR `admin`                   | Biometric integrity.                   |
| **Relations**  | `relations_main_policy` | `coach` OR `athlete` OR `admin`      | Visibility of training partnerships.   |
| **Lndmk/Metr** | `landmarks_main_policy` | `inherited from session`             | Automated access for time-series data. |

### Performance & Security Notes

1.  **Deterministic Identity**: We use `(SELECT auth.uid())` in all policies. This prevents PostgreSQL from re-evaluating the `auth.uid()` function for every row in a scan, improving performance by orders of magnitude on large datasets (e.g., millions of landmarks).
2.  **Unified Action Pattern**: Using `FOR ALL` instead of separate `SELECT/INSERT/UPDATE` policies avoids the "Multiple Permissive Policies" lint error and simplifies the security surface area.
3.  **Trigger-Based Business Logic**: Hard limits (like the coach's athlete cap) are enforced via triggers rather than RLS. Triggers provide a robust "last line of defense" that cannot be bypassed by simply having the correct role.

For a deep dive into the exact SQL and security rationale, see the **[Detailed RLS Documentation](rls_policies_detailed.md)**.

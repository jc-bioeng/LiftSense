# RLS Logic Schematic

This diagram visualizes how authentication and roles flow through the database to grant or deny access.

```mermaid
graph TD
    User((Auth User)) -->|JWT Token| Supabase[Supabase API]
    Supabase -->|get_user_role| RoleCheck{Role Check}
    
    subgraph AccessLogic [RLS Policies]
        RoleCheck -->|admin| FullAccess[Full Access: Global]
        RoleCheck -->|athlete/coach/guest| OwnerCheck{Owner Check}
        
        OwnerCheck -->|id = auth.uid| OwnProfile[Manage Own Profile]
        OwnerCheck -->|user_id = auth.uid| OwnSessions[Manage Own Sessions / Anthro]
        
        OwnerCheck -->|via profile_relations| CoachCheck{Relation Check}
        CoachCheck -->|active status| AthleteData[View Athlete Sessions]
        
        OwnSessions -->|Inheritance| SubData[Landmarks / Metrics]
        AthleteData -->|Inheritance| SubData
    end

    subgraph DataTables [PostgreSQL Tables]
        OwnProfile --> Profiles[(Profiles)]
        FullAccess --> Profiles
        
        OwnSessions --> Sessions[(Sessions)]
        AthleteData --> Sessions
        
        SubData --> Landmarks[(Landmarks)]
        SubData --> Metrics[(Metrics)]
    end

    subgraph Automation [Triggers]
        Sessions -->|INSERT| GuestLimit[Guest Limit Trigger]
        GuestLimit -->|Count > 3| Deny((Exception))
    end
```

## Policy Breakdown

| Table          | Logic                                | Role Dependency              |
| :------------- | :----------------------------------- | :--------------------------- |
| **Profiles**   | `owner` OR `admin`                   | Strict ID match              |
| **Sessions**   | `owner` OR `admin` OR `active coach` | Join via `profile_relations` |
| **Lndmk/Metr** | `inherited from session`             | `EXISTS` parent check        |
| **Anthro**     | `owner` OR `admin`                   | Linear history               |

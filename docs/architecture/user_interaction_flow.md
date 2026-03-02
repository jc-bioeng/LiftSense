# User Interaction Flow

This document describes the primary paths a user takes through the LiftSense ecosystem, from initial discovery to advanced biomechanical analysis.

## Interaction Diagram

```mermaid
graph TD
    Start((App Launch)) --> GuestPath[Guest Path]
    Start --> AuthPath[Authenticated Path]

    subgraph GuestPath [Frictionless discovery]
        GuestPath --> G1[Capture Video]
        G1 --> G2[Instant Landmark Tracking]
        G2 --> G3[View Basic Metrics]
        G3 --> GLimit{Check: 2 sessions / 24h?}
        GLimit -->|Under Limit| G1
        GLimit -->|Limit Reached| GRegister[Registration Prompt]
    end

    subgraph AuthPath [Value Cycle]
        AuthPath --> RoleCheck{User Role?}
        
        RoleCheck -->|Athlete| A1[Setup Anthro Profile]
        A1 --> A2[Capture & Long-term Analysis]
        A2 --> A3[History & Trend Visualization]
        
        RoleCheck -->|Coach| C1[Athlete Management]
        C1 --> C2[Remote Monitoring]
        C2 --> C3[Group Progress Reports]
    end
```

## User Journeys

### 1. The Guest (Immediate Value)
- **Goal**: Experience the core "magic" of the biomechanical engine without sign-up friction.
- **Actions**: One-tap capture -> Real-time tracking -> Immediate ROM/Velocity feedback.
- **Enforcement**: Regulated by `trg_guest_session_limit`. The system allows a "taste" of the power but requires registration to build a training history.

### 2. The Athlete (Self-Improvement)
- **Anthro-First**: Users establish a single active anthropometry profile (height, weight, segment lengths).
- **Consistency**: The `trg_single_active_anthropometry` ensures all new captures are analyzed against their current biological state.
- **Privacy**: RLS ensures that while data is stored in a shared infrastructure, only the athlete (and their authorized coach) can access it.

### 3. The Coach (Team Management)
- **Linking**: Coaches establish relationships via `profile_relations`.
- **Governance**: The `trg_coach_athlete_limit` enforces plan tiers (Starter/Pro/Elite).
- **Security Gate**: Coaches with `canceled` or `past_due` subscriptions are blocked from adding new athletes, ensuring business continuity.
- **Collaborative Flow**: Once linked, the coach's dashboard automatically populates with athlete data, enabling remote coaching without manual exports.

---

## Technical Integration

- **UI Gating**: The Flutter frontend uses the `role` and `subscription_status` fields from the `profiles` table to enable/disable UI elements.
- **Backend Enforcement**: Regardless of UI state, the database triggers act as the final authority on usage limits.
- **Dynamic Context**: Policy performance with `(SELECT auth.uid())` ensures that even coaches with 100+ athletes experience zero lag when navigating team history.

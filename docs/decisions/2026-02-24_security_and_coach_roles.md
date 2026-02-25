# Decision Record: Security Model, RLS, and Coach Roles

**Date:** 2026-02-24

## Decision Statement
We will implement a decentralized security model using PostgreSQL Row Level Security (RLS) to ensure data isolation while enabling multi-user collaboration (Coach-Athlete relationships) through a dedicated `profile_relations` table.

## 1. Functions of the Coach
The `coach` role in LiftSense is designed for professionals managing multiple athletes or research subjects. 

- **Managed Data Access**: Coaches can view `sessions`, `landmarks`, and `metrics` of any user linked via an 'active' relation.
- **Biomechanical Oversight**: Coaches can utilize the backend to run analysis pipelines on behalf of their athletes.
- **Relational Governance**: The `profile_relations` table tracks `coach_id`, `athlete_id`, and `permissions` (view_only vs manage_sessions), allowing for revocable access.

## 2. RLS Decisions
To balance performance and security, the following RLS strategies were adopted:

- **Ownership First**: The primary policy `user_id = auth.uid()` ensures that the owner always has full access to their data.
- **Admin Override**: Admin roles bypass ownership checks via the `get_user_role() = 'admin'` helper function.
- **Relational Access (Shared Data)**: For multi-user access (Coaches), we use `EXISTS` clauses to verify active relations in the `profile_relations` table.
- **Indirect RLS (Inheritance)**: Data nested under sessions (Landmarks/Metrics) inherits access permissions from the parent session's ownership/relation status.
- **Guest Restrictions**: A database trigger (`trg_guest_session_limit`) enforces a 3-session cap for unverified Guest accounts to prevent resource abuse.

## Alternatives Discarded
- **Application-Layer Authorization**: Discarded to prevent data leaks if the API is bypassed or if direct DB tools are used for research.
- **Hard-coded Coach IDs**: Discarded as it doesn't scale for gym environments or multiple coaching relationships.

## Impact Dimensions

| Dimension          | Qualitative Assessment                                       |
| :----------------- | :----------------------------------------------------------- |
| **Security**       | High: Data isolation at the DB layer prevents lateral leaks. |
| **Scalability**    | High: RLS handles large datasets efficiently via indices.    |
| **Privacy (GDPR)** | High: Clear ownership and easy data deletion/revocation.     |
| **Flexibility**    | High: `profile_relations` supports complex team structures.  |
| **Performance**    | Medium: `EXISTS` queries add slight overhead to JOINs.       |

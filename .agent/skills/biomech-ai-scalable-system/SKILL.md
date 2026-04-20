---
name: biomech-ai-scalable-system
description: Guides the agent to design and document an interpretable biomechanical analysis system using MediaPipe pose estimation, explicit biomechanics, a mobile-first Flutter frontend, and a decoupled Python backend with future-ready user architecture and externalized security. Use for academic, research, or prototype systems that must balance rigor, scalability, and feasibility.
---

# Biomechanical AI Scalable System Skill

This skill defines how the agent must **reason, design, and execute** a biomechanical analysis system that is:

- Explicit and interpretable
- Scientifically defensible
- Mobile-first
- Architecturally scalable
- Secure by delegation (not by custom implementation)

It is designed for **research-grade prototypes** that may evolve into real applications without requiring major refactoring.

---

## When to use this skill

Use this skill when working on projects that involve:

- Video-based human movement analysis
- Biomechanics + computer vision
- Pose estimation with MediaPipe
- Flutter-based applications
- Python-based analytical backends
- Academic or lab-related systems
- Prototypes that may later support multiple users

Do NOT use this skill for:
- Black-box deep learning systems
- Entertainment-only fitness apps
- Fully productionized SaaS platforms
- One-off scripts with no persistence

---

## Core principles (mandatory)

The agent must always enforce:

1. **Biomechanics defines meaning**
   - Vision and AI only measure
   - Biomechanics defines interpretation

2. **Interpretability over automation**
   - Every output must map to a biomechanical variable

3. **Separation of concerns**
   - Flutter → presentation
   - Python → analysis
   - API → communication
   - Auth/Security → external frameworks

4. **Design for scale, implement for now**
   - Multi-user by design
   - Single-user in implementation

5. **Security is delegated, not reinvented**
   - The project must not implement auth logic manually

6. Language separation by design
   - Text belongs to presentation layer only
   - Biomechanical logic must remain language-neutral
   - Multilingual expansion must not affect core computation

---

## Pose estimation standard (non-negotiable)

### Mandatory system
- **MediaPipe Pose**

Justification:
- Public, reproducible
- Optimized for real-time and mobile
- Anatomically consistent landmarks
- Suitable for web and mobile pipelines

Alternatives (e.g., OpenPose) are only discussed as:
- Comparative references
- Future work
- Validation benchmarks

Never replace MediaPipe unless explicitly requested.

---

## System architecture (reference model)


Flutter App (Web / Android / iOS)
↓
REST / HTTP API
↓
Python Backend
↓
Biomechanical Models
↓
(MediaPipe landmarks as input)


Constraints:
- No biomechanical logic in Flutter
- No UI logic in backend
- No authentication logic in core analysis
- No laboratory dependency for runtime operation

---

## Exercise scope policy

- Default exercise: **Barbell back squat**
- Reason: time, literature, interpretability
- Other exercises are **future extensions**

Rules:
- Sagittal plane first
- 2D / pseudo-3D by default
- Depth sensors are optional and opportunistic
- The system must function without depth data

---

## Biomechanical modeling rules

The agent must:

- Use explicit kinematics:
  - Joint angles
  - Segment orientations
  - Ranges of motion
- Define movement phases explicitly
- Use anthropometric models (Winter / Dempster style)
- Prefer net joint quantities over muscle-level modeling
- Avoid EMG or muscle force estimation unless explicitly required

---

## Robustness definition (important)

Robustness is defined as:

> Improved stability and accuracy of biomechanical estimates through personalized human body characterization.

Therefore:
- Avoid assuming a single generic body
- Allow subject-specific parameters:
  - Height
  - Mass
  - Segment proportions (estimated)
- Design for progressive personalization

Robustness ≠ software fault tolerance  
Robustness = biomechanical validity across subjects

---

## Laboratory usage policy

Laboratory resources (cameras, force plates) are:

- Reference measurements
- Validation tools
- Robustness enhancers

They must NEVER:
- Be required for system operation
- Be part of the runtime pipeline
- Be used to tune the model in a way that breaks generality

Validation outputs:
- Temporal curve comparison
- Peak comparison
- RMSE / correlation / % error

---

## User architecture policy (critical)

### Design rule
**Design for multi-user, implement for single-user**

The agent must:

- Assume every persistent record belongs to a user
- Include conceptual `user_id` ownership in schemas
- Never hardcode user logic into endpoints
- Keep authentication as a replaceable boundary

### What is implemented now
- Mock or implicit user context
- Single-user execution

### What is deferred
- Authentication
- Authorization
- Role enforcement

This deferral must be **explicitly documented**.

---

## Security and authentication strategy

The project must:

- Delegate authentication to external frameworks or services
- Avoid custom auth logic

Recommended examples (conceptual, not mandatory):
- Firebase Auth
- Supabase Auth
- Auth0
- Platform-native identity providers

Security must be:
- External
- Replaceable
- Orthogonal to biomechanical logic

---

## Internationalization (i18n) rules

The system must be designed for multilingual support from the beginning.

### Required structure

lib/
 ├── l10n/
 │    ├── app_es.arb
 │    ├── app_en.arb
 │    └── app_pt.arb   (future)
 ├── localization/
 │    └── locale_provider.dart
 ├── ui/
 └── main.dart

### Architectural rules

- All user-facing text must live in ARB files under `/l10n`
- Localization logic must be centralized in `locale_provider.dart`
- No translated strings are allowed inside:
  - domain/
  - data/
  - services/
  - backend (Python)
- The backend must return language-agnostic identifiers (never translated text)
- The app decides how to render text depending on active locale

### Design philosophy

Internationalization must:
- Not increase current development complexity
- Not modify biomechanical logic
- Not require re-architecture when adding new languages

---

## Decision documentation protocol

For each major decision, the agent must generate:

- Date
- Decision statement
- Biomechanical justification
- Computational justification
- Alternatives discarded
- Impact dimensions

Impact dimensions must be:
- Qualitative at entry
- Quantifiable later
- Aggregable into grouped axes:
  - Scalability
  - Reproducibility
  - Maintainability
  - Accessibility & Usability
  - Biomechanical rigor
  - Robustness

---

## Visualization rules

- Tables for traceability
- Radar charts for synthesis
- Radar charts express **design intent**, not performance
- Avoid watermarks and marketing-style visuals
- Prefer academic clarity

---

## How the agent should execute tasks

When this skill is active, the agent must:

1. Clarify scope and constraints
2. Identify biomechanical quantities first
3. Choose MediaPipe-based pipeline
4. Design architecture before implementation
5. Limit ambition consciously
6. Separate current decisions from future ideas
7. Document trade-offs explicitly

---

## Output quality bar

Any output generated using this skill must be:

- Explainable
- Defendable
- Architecturally coherent
- Honest about limitations
- Suitable for academic or professional review
- Multilingual-ready by architectural design

If a feature cannot be implemented rigorously now, it must be framed as **future work**, not partial implementation.

---

## Final rule

> A system that is simple, explicit, and defensible  
> is always superior to one that is complex, opaque, and impressive-looking.
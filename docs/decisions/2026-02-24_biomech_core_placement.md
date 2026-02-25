# Decision Record: Placement and Structure of Biomech Core

**Date:** 2026-02-24

## Decision Statement
We will implement the biomechanical analysis logic in a dedicated, importable module named `biomech_engine` located at `backend/biomech_engine/`, keeping it strictly decoupled from the FastAPI application in `backend/app/`.

## Biomechanical Justification
- **Interpretability:** Moving the biomechanical logic to its own engine ensures that analysis routines (pipelines) are defined by biomechanical variables rather than API constraints.
- **Validity:** Allows for independent validation of kinematics (joint angles, segment orientations) against laboratory references without the overhead of the web server.

## Computational Justification
- **Scalability:** Enables moving heavy biomechanical computations (FFT, filtering) to worker containers/containers as per `biomech-architecture` Rule 1.
- **Importability:** The engine can be used as a standalone Python module for research or validation scripts in `research/notebooks`.

## Alternatives Discarded
- **`backend/app/core`**: Discarded to avoid coupling business logic with infrastructure/API configuration.
- **`backend/app/services`**: Discarded to keep biomechanical pipelines pure and language-neutral, separate from API use cases.

## Impact Dimensions

| Dimension                     | Qualitative Assessment                                     |
| :---------------------------- | :--------------------------------------------------------- |
| **Scalability**               | High: Ready for Docker worker separation.                  |
| **Reproducibility**           | High: Named and versioned pipelines.                       |
| **Maintainability**           | High: Clear separation of concerns (API vs Engine).        |
| **Accessibility & Usability** | Medium: Requires understanding of the decoupled structure. |
| **Biomechanical Rigor**       | High: Explicit kinematic calculations.                     |
| **Robustness**                | High: Independent testing of subject-specific parameters.  |

---
slug: roadmap
title: Roadmap
role: milestones
updated: "2026-08-31T14:37:29"
---

# Roadmap

```mermaid
gantt
    title Maltex Parallel Track Roadmap
    dateFormat YYYY-MM
    section 1.2.x Mainline Track
    v1.2.0 Release (Dual-arch)          :done, 2026-08, 2026-08
    v1.2.x Stability & Bug Fixes        :active, 2026-08, 2026-12
    Sparkle Dual-Arch Updates           :active, 2026-08, 2026-12
    section 1.3.x Experimental Track
    v1.3.0-beta1 (aria2-rust arm64)     :done, 2026-08, 2026-08
    Follow upstream aria2_rust (Phase 2):active, 2026-08, 2026-11
    Evaluate aria2_rust for GA          :2026-11, 2027-01
```

## Track Details

- **1.2.x Track (`main`)**: Stability-first maintenance, dual-architecture (arm64 & x86_64), automated CI/CD and Sparkle releases.
- **1.3.x Track (`feature/aria2-rust`)**: Innovation track tracking upstream `aria2_rust`, Apple Silicon (arm64) exclusive, manual pre-releases.

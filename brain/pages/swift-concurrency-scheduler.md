---
id: swift-concurrency-scheduler
title: Use Swift Concurrency Actors for download task state
category: decision
status: active
created: "2026-08-21T06:38:35"
updated: "2026-08-21T06:38:35"
---

<!-- compiled_truth -->
Utilized Swift actors to isolate chunk buffer mutations and prevent race conditions during multi-threaded downloads.


## Timeline

- time: 2026-08-21T06:38:35
  kind: decision
  summary: "Created this page: Use Swift Concurrency Actors for download task state"
  source: git log
  affects: [swift-concurrency-scheduler]

- time: 2026-08-21T06:38:35
  kind: decision
  summary: Standardized concurrency on Swift actors.
  source: git log
  affects: [swift-concurrency-scheduler]

# rn-counter — Design

## Overview

A minimal React Native Counter component, built with `@testing-library/react-native` tests. Used as an end-to-end smoke test of the ai-crew team-lead orchestrator: spec/plan/build/verify/review hand-off across the developer subagent.

## Feature

A `Counter` component with:
- A label showing the current count (starts at 0)
- A `+` button that increments
- A `-` button that decrements (clamped at 0 — never goes below zero)

## Why this fixture exists

This is **not** a real product. It is the smallest React Native surface that:
1. Has more than one acceptance criterion (so the plan has multiple atomized tasks)
2. Forces the team-lead to dispatch the developer subagent more than once (so we verify hand-off)
3. Uses `@testing-library/react-native` queries (so we exercise the `mobile-component-testing-with-rntl` skill)
4. Has obvious correctness checks (RNTL tests pass / fail)

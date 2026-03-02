# Canonical Corrective Todo

This is the active source of truth for shared-fixture corrective finish work.

Supersedes:
- `todos/pikahut-shared-fixture-corrective.md`
- `todos/shared-fixture-closeout-corrective.md`

## Spec

This corrective follow-up is needed because the shared fixture feature was implemented against the wrong todo scope in parts: the core architecture landed, but completion criteria, promotion boundaries, and cleanup policy are inconsistent. We need one holistic finish-off todo that explicitly states what to remove, what to add, and what evidence is required to call the feature complete.

Intent and expected outcome:
1. Keep the implemented shared fixture foundation that is already working.
2. Remove unsafe, misleading, or over-scoped behavior now.
3. Add missing technical and governance gates so completion is objective.
4. Converge all remaining work to one canonical finish todo and mark overlaps superseded.

Exact build target when done:
1. Shared fixture phase-1 scope is explicit per profile/selector (shared-capable vs strict-only).
2. Shared-capable internals enforce tenant helper usage; no hidden ad-hoc namespace bypass.
3. Deterministic completion gates are enforced:
- strict/shared parity for canonical deterministic selectors
- relay/moq tenant isolation regressions
- postgres tenant isolation regressions (default + fallback)
- shared pool transient failure recovery and teardown resilience regressions
4. Shared defaults are only active where lane/profile evidence exists.
5. Unsupported shared defaults are rolled back to strict until evidence gates pass.
6. Postgres default remains schema-per-tenant with deterministic database fallback in this finish cycle; any default flip is deferred behind explicit evidence.
7. Relay tenant namespace helpers remain available as canonical helper surface; enforcement target is still no ad-hoc tenant string construction.
8. Deterministic tenant seed support remains as a bounded reproducibility/debug tool.
9. Shared pool failure policy is explicit: recover transient failures, fail-fast for irrecoverable states.
10. Drift guardrails keep docs/toggles/selectors/matrix aligned.
11. One canonical corrective todo remains active; overlapping todos are marked superseded.

Exact approach:
1. Preserve core implementation and apply targeted removals only where risk is clear.
2. Add missing correctness gates before further promotion.
3. Sequence work into many small, testable steps with acceptance criteria.
4. Make promotion evidence-based and reversible.

## Plan

1. Publish a canonical strict-vs-shared capability matrix for relevant profiles/selectors.
Acceptance criteria: one checked-in matrix marks each target as `SharedSupported`, `StrictOnly`, or `Experimental`.

2. Identify unsafe or misleading shared-fixture behaviors for immediate correction.
Acceptance criteria: a concrete remove/de-scope list exists with file-level references.

3. Remove tenant namespace bypasses from shared-capable internals.
Acceptance criteria: shared-capable paths only use tenant helper APIs for relay/moq naming.

4. Add explicit temporary adapters where immediate full removal would break migration.
Acceptance criteria: each adapter is documented, bounded, and tied to a removal condition.

5. Remove or rewrite stale completion claims in docs.
Acceptance criteria: docs no longer imply completion without parity/isolation/recovery evidence.

6. Define canonical deterministic selector set for parity validation.
Acceptance criteria: one selector list is reused by strict and shared validation commands.

7. Add strict-mode canonical deterministic run target.
Acceptance criteria: reproducible strict command path is documented and runnable.

8. Add shared-mode canonical deterministic run target.
Acceptance criteria: reproducible shared command path is documented and runnable.

9. Add strict-vs-shared parity summary output.
Acceptance criteria: run artifacts expose comparable strict/shared pass outcomes.

10. Add relay tenant isolation regression test for concurrent tenants.
Acceptance criteria: concurrent tenants cannot observe/collide in relay namespaces.

11. Add moq tenant isolation regression test for concurrent tenants.
Acceptance criteria: concurrent tenants cannot observe/collide in moq topics.

12. Add postgres default-mode tenant isolation regression test.
Acceptance criteria: default tenant isolation mode proves data separation across concurrent tenants.

13. Add postgres fallback-mode tenant isolation regression test.
Acceptance criteria: fallback mode preserves tenant separation and emits fallback diagnostics.

14. Add deterministic fallback trigger validation.
Acceptance criteria: fallback trigger behavior is deterministic under defined conditions.

15. Add shared pool transient initialization failure recovery regression test.
Acceptance criteria: transient init failures can recover without permanent poisoned pool state.

16. Add irrecoverable failure policy regression test.
Acceptance criteria: irrecoverable failures fail fast with clear error surfacing.

17. Add teardown retry/backoff regression test for shared resources.
Acceptance criteria: teardown remains idempotent and resilient under transient lock contention.

18. Keep deterministic tenant seed support as bounded debug capability.
Acceptance criteria: seed behavior remains documented, test-covered, and scoped to reproducibility use.

19. Keep relay tenant helper APIs but clarify their role.
Acceptance criteria: docs/tests treat relay helpers as canonical naming utilities, while cryptographic identity remains the primary Nostr isolation boundary.

20. Add guardrail to detect ad-hoc tenant namespace literals in shared-capable internals.
Acceptance criteria: guardrail fails on raw tenant namespace string construction outside helper module.

21. Add guardrail for shared toggle/docs drift.
Acceptance criteria: documented shared/strict toggles match implemented env/control surface.

22. Add guardrail for selector/docs/matrix drift.
Acceptance criteria: canonical selectors and capability matrix remain aligned with invoked lane contracts.

23. Apply strict-by-default rollback for lanes/profiles with insufficient shared evidence.
Acceptance criteria: unsupported shared defaults are reverted and documented in matrix.

24. Define promotion evidence contract per lane/profile.
Acceptance criteria: promotion requires parity pass + reliability signal + runtime delta evidence.

25. Promote shared default only for lanes/profiles meeting evidence contract.
Acceptance criteria: each promotion has recorded evidence artifact references.

26. Defer any Postgres default flip until evidence review is complete.
Acceptance criteria: explicit decision record exists comparing schema-default vs database-default behavior before any default change.

27. Add diagnostics assertions for shared/strict mode metadata emission.
Acceptance criteria: deterministic runs emit expected shared reuse/isolation/fallback diagnostics.

28. Consolidate shared-fixture docs into one authoritative finish-state reference.
Acceptance criteria: reference doc includes capability matrix, toggles, limits, promotion policy, rollback guidance.

29. Mark overlapping shared-fixture todos/specs as superseded.
Acceptance criteria: superseded files contain explicit pointer to canonical corrective todo.

30. Run full shared-fixture guardrail suite.
Acceptance criteria: tenant enforcement + drift guardrails pass.

31. Run canonical deterministic strict/shared validation in CI-like environment.
Acceptance criteria: both modes pass canonical selectors with actionable artifacts.

32. Manual QA gate (user-run): approve completion and promotion boundaries.
Acceptance criteria: user confirms parity results, no observed tenant contamination, acceptable reliability/performance evidence for promoted lanes, and sign-off on removals/additions from this corrective todo.

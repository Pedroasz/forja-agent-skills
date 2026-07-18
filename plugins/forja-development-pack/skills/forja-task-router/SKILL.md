---
name: forja-task-router
description: Use when classifying FORJA tasks, requests, incidents, migrations, frontend changes, or documentation work before selecting FORJA skills.
---

# Route FORJA Tasks

Classify the request before planning or changing anything. Read [the routing contract](references/routing-contract.md) for risk triggers and the skill map.

Confirm that the request concerns FORJA. If it does not, select no FORJA skill and state that boundary.

## Produce This Exact Routing Record

- Task summary:
- Risk level:
- Selected skills:
- Skills deliberately not selected:
- Required approvals:
- Prohibited actions:
- Validation plan:
- Stop conditions:

Use only these eight fields. State concrete facts from the request; do not invent approval, execution, or validation evidence.

## Route

1. Identify every applicable trigger in the request.
2. Assign each trigger a risk from the contract. Apply the highest risk.
3. Select every matching FORJA skill, including `forja-test-strategy` when a functional, authentication, storage, migration, or RLS change needs tests.
4. List plausible skills that were deliberately not selected and give a brief boundary reason.
5. Set approvals, prohibited actions, validation, and stop conditions to the strictest applicable route.

Stop before destructive production work, remote database execution, deployment, handling real data, or any action outside explicit authority. Route a CRITICAL request to incident handling and wait for incident authority.

## Check Before Handoff

Verify the project scope, selected skill names, risk level, and all eight record fields. Keep a non-FORJA request outside this pack.

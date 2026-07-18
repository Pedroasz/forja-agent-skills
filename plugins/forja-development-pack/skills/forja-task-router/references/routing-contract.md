# FORJA Routing Contract

## Apply the Contract

1. Confirm the work belongs to FORJA; otherwise select no FORJA skill.
2. Match every trigger below.
3. Assign the listed risk to each match. **The highest risk prevails.**
4. Select every listed skill and apply the strictest approvals, prohibitions, validation, and stop condition.

The highest risk determines the risk level and gates but NEVER replaces lower-risk applicable skills. Risk classification and skill composition are separate operations: classify with the maximum risk, then retain every matching base skill and focused overlay.

## Risk and Skill Map

| Risk | Trigger | Select | Approval and stop condition |
|---|---|---|---|
| LOW | README, ADR, evidence, or documentation-only change | `forja-documentation` | No execution approval; validate the edited artifact. |
| MODERATE | Functional frontend, navigation, form, UI, accessibility, or performance change | `forja-safe-frontend-change`, `forja-test-strategy`; add the focused UX or performance skill when applicable | Require approval before a FORJA SaaS merge. |
| HIGH | Authentication, storage, workspace isolation, RLS, policy, schema, or incremental migration | `forja-supabase-migration`, `forja-auth-storage-safety`, `forja-test-strategy` | Require approval before migration execution or SaaS merge. Stop before remote database commands. |
| CRITICAL | Confirmed incident, destructive production request, real-data loss, outage, or irreversible production action | `forja-incident-response` plus every matching focused overlay below | Stop and require explicit incident authority before any production action. |

## Compositional Overlays

Apply every matching row in addition to the base risk row. Never stop scanning after finding HIGH or CRITICAL.

| Focused signal | Add these skills |
|---|---|
| keyboard, focus, contrast, modal, or accessibility | `forja-safe-frontend-change`, `forja-ux-accessibility` |
| performance | `forja-performance-audit` |
| explicit test strategy | `forja-test-strategy` |
| documentation, evidence, or report | `forja-documentation` |
| review | `forja-independent-review` |
| release | `forja-release-pipeline` |
| restore, rollback, recovery, or copy-first | `forja-data-recovery` |
| confirmed outage, incident, or data loss | `forja-incident-response` |
| schema, RLS, or migration | `forja-supabase-migration`, `forja-auth-storage-safety`, `forja-test-strategy` |

## Required Boundaries

- `forja-task-router` is the decision mechanism and does not select or list itself in either `Selected skills` or `Skills deliberately not selected`.
- Never select a FORJA skill for another project.
- Never treat a hypothetical question as authority to execute.
- Never delete production data, deploy, run remote database commands, use real credentials, or claim validation that did not occur.
- For mixed work, retain every relevant skill and the strictest route; do not downgrade risk because part of the task is documentation.
- A CRITICAL incident route is not incident-only: restore, explicit test, documentation, review, or other focused signals keep their overlays while the CRITICAL stop applies.

## Deterministic Examples

| Request | Risk | Selected skills | Stop |
|---|---|---|---|
| Update the FORJA README | LOW | `forja-documentation` | No |
| Change a FORJA dashboard button | MODERATE | `forja-safe-frontend-change`, `forja-test-strategy` | No |
| Change a FORJA RLS policy in a new migration | HIGH | `forja-supabase-migration`, `forja-auth-storage-safety`, `forja-test-strategy` | Before remote execution |
| FORJA modal focus change plus RLS migration | HIGH | `forja-safe-frontend-change`, `forja-ux-accessibility`, `forja-supabase-migration`, `forja-auth-storage-safety`, `forja-test-strategy` | Before remote execution or SaaS merge |
| Confirmed outage with restore, test strategy, and documentation | CRITICAL | `forja-incident-response`, `forja-data-recovery`, `forja-test-strategy`, `forja-documentation` | Before containment, restore, or any production action |
| Delete production user data | CRITICAL | `forja-incident-response` | Yes |
| Edit a separate project's README | NONE | None | No FORJA routing |

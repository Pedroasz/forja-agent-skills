# FORJA Routing Contract

## Apply the Contract

1. Confirm the work belongs to FORJA; otherwise select no FORJA skill.
2. Match every trigger below.
3. Assign the listed risk to each match. **The highest risk prevails.**
4. Select every listed skill and apply the strictest approvals, prohibitions, validation, and stop condition.

## Risk and Skill Map

| Risk | Trigger | Select | Approval and stop condition |
|---|---|---|---|
| LOW | README, ADR, evidence, or documentation-only change | `forja-documentation` | No execution approval; validate the edited artifact. |
| MODERATE | Functional frontend, navigation, form, UI, accessibility, or performance change | `forja-safe-frontend-change`, `forja-test-strategy`; add the focused UX or performance skill when applicable | Require approval before a FORJA SaaS merge. |
| HIGH | Authentication, storage, workspace isolation, RLS, policy, schema, or incremental migration | `forja-supabase-migration`, `forja-auth-storage-safety`, `forja-test-strategy` | Require approval before migration execution or SaaS merge. Stop before remote database commands. |
| CRITICAL | Confirmed incident, destructive production request, real-data loss, outage, or irreversible production action | `forja-incident-response` | Stop and require explicit incident authority before any production action. |

## Required Boundaries

- Never select a FORJA skill for another project.
- Never treat a hypothetical question as authority to execute.
- Never delete production data, deploy, run remote database commands, use real credentials, or claim validation that did not occur.
- For mixed work, retain every relevant skill and the strictest route; do not downgrade risk because part of the task is documentation.

## Deterministic Examples

| Request | Risk | Selected skills | Stop |
|---|---|---|---|
| Update the FORJA README | LOW | `forja-documentation` | No |
| Change a FORJA dashboard button | MODERATE | `forja-safe-frontend-change`, `forja-test-strategy` | No |
| Change a FORJA RLS policy in a new migration | HIGH | `forja-supabase-migration`, `forja-auth-storage-safety`, `forja-test-strategy` | Before remote execution |
| Delete production user data | CRITICAL | `forja-incident-response` | Yes |
| Edit a separate project's README | NONE | None | No FORJA routing |

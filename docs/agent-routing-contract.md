<!-- Synced copy. Do not edit here. Master: Rule-0-Softworks/rule-0-softworks-platform, docs/config/. -->

# Agent Routing and Capacity Contract v0.9

**Status:** Active policy. Replaces v0.8. Last reviewed: November 16, 2026.
Next review due: by January 16, 2027.

This contract says which model does which work, who approves, and when to
escalate. It applies to Codex and Claude agents alike. A model choice never
grants scope, authority, or approval.

## 1. Pick the tier

Check in this order. Stop at the first match.

| Order | Tier | Use when | OpenAI | Claude |
|---|---|---|---|---|
| 1 | Specialist | Inspected evidence shows a Specialist trigger (section 2). | GPT-6 Astra, high | Opus 5.5 high or Fable 5.2 (section 2) |
| 2 | Efficient | Every Efficient condition holds (section 3). | GPT-6 Luna, max | Haiku 5.5 |
| 3 | Standard | Everything else. | GPT-6 Sol, medium | Sonnet 5.5, medium |

Standard moves to **high** (Sol high, Opus 5.5 high) when the work has any of:

- ambiguity that could change the result, the approach, or the checks
- parts that depend on each other and need coordinated decisions
- a change to shared architecture, shared interfaces, or repo-wide config
- a provenance question or a policy conflict

Size, difficulty, file count, high stakes, or preference never raise the tier.

## 2. Specialist triggers

The work, as shown by inspected code or evidence, does one of these:

1. Changes or decides auth, a security or trust boundary, secrets, or
   permissions.
2. Reviews or evaluates one of those without changing it.
3. Needs real screen use, visual judgment, or work across applications.
4. Needs a dangerous or hard-to-undo action.

| Trigger | OpenAI | Claude |
|---|---|---|
| 1 or 4 | Astra high | Fable 5.2 |
| 2 or 3 | Astra high | Opus 5.5 high |

- Every Specialist assignment names the trigger and the evidence. If it
  cannot, use Standard.
- Shell commands, repo tools, command-line browser automation, and using
  existing credentials are not triggers.
- A dangerous action still needs Josh's approval for that exact action.

## 3. Efficient conditions

All must be true and written down before assignment:

- The repository, issue, and exact files are named.
- Authority, non-goals, and acceptance criteria are complete. Nothing is
  inferred.
- The check is named in advance and gives the same answer every time.
- The slice is small, in one piece, and easy to undo.
- No design decision, open dependency, or coordination is left.
- No shared contract or shared config is touched.
- No Specialist trigger applies.

If any condition is missing or stops being true, stop and use Standard. The
main agent decides eligibility. An Efficient agent may not qualify itself,
delegate, or be dispatched by a worker or reviewer.

## 4. Escalate

| When | Move |
|---|---|
| A Standard-high condition appears | Standard medium to Standard high |
| Two separate, complete, repeatable validation failures at high | High to xhigh, or Opus to Fable in Specialist |
| A Specialist trigger is found | Stop. New Specialist assignment. |
| An Efficient condition fails | Stop. Move to Standard. |
| The work outgrows its approved scope | Stop. Ask Josh. |
| Josh names a different profile | Use it. Log it as an exception. It changes the profile only. |

- Rerunning the same failed check does not count as a second failure.
- A writer who returns partial work with real progress continues. A return
  with no progress counts as a failed attempt. Two failed attempts is the
  limit.
- Step down only when the reason for the higher level is gone.
- A tier change needs a new approval. A provider change inside a tier does
  not, but it is logged.

## 5. Who approves

- Josh approves every slice before work starts. The tier is fixed at
  approval. The provider may be left open.
- No agent reclassifies its own work. A wrong tier pauses the work and goes
  back to Josh.
- No agent widens its issue, repository, or authority by inference.
- No agent merges a pull request.
- Agents move Linear issues only among Triage, Backlog, To Do, and In
  Progress.
- One writer per repository at a time.
- This contract outranks a slice contract. An exception needs Josh and ends
  with the slice.

**Before work starts, state:** purpose, scope and non-goals, files, tier and
the evidence for it, the reviewer, how it can be undone, and how done is
checked.

**When work stops, report:** state, what changed, each acceptance criterion
with its proof, validation and review results, what is left, the next decision
for Josh, and the tier used with any escalation or exception.

## 6. Review

- Specialist implementation always gets an independent reviewer. So does any
  workflow that asks for one.
- The reviewer matches the writer's tier and effort. An Efficient writer gets
  a Standard medium reviewer.
- The reviewer is a separate agent, is read-only, and may be from either
  provider. It does not delegate or become the writer for that slice.

## 7. PR feedback

A request from Josh to address feedback on a named PR is its own approval.

- The current agent may assess, fix, validate, commit, push, and reply. No
  approval packet or reassignment is needed. A linked hotfix PR is allowed.
- A request to only assess stays read-only.
- Still required: tests, secret checks, repository restrictions, and
  Specialist triggers (inspect the code first; a comment that mentions
  security is not a trigger on its own).
- Never force-push, resolve review threads, or merge.

## 8. Keeping lanes moving

- Follow Josh's priority order.
- While one lane waits on Josh, prepare the next contract. Preparing is
  read-only.
- Bring Josh one decision at a time, with a link.
- Never leave a lane silently idle. Say what it waits on.
- Stop everything when Josh says pause.

## 9. Contract upkeep

- Review this contract no sooner than one month and no later than two months
  after the last review. A scheduled task starts one every six weeks.
- Each review checks both providers' official model docs and confirms or
  updates the tables.
- An agent drafts the review. Josh approves any change.
- Every review updates the dates at the top, even if nothing changes.

## Not verified

The Claude model names come from the current Claude 5 family. Their official
capability and reasoning-level docs have not been checked yet. The first
review checks them against Anthropic's documentation.

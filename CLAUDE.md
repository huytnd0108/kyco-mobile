# kyco — rules for any code change

Before editing code here, READ the business-rules memory and check the change against it:
`/home/bi/.claude/projects/-home-bi-w-AppDroid1-ori/memory/kyco-business-flows.md`
(roles, booking FSM, pricing, payment, 80/20 ledger, cancellation, subscriptions, flags, §8 invariants).
Open security defects + fix waves: `apps/kyco/docs/security-review-2026-10-10.md`.

- Code is the source of truth over `docs/kyco-system-handbook.md`; if a change alters a business rule, say so first and update the memory file.
- Any change touching payment / money / ledger / wallet / payout / refund needs explicit human approval BEFORE building ("hỏi chặn").
- Mobile never computes or sends a money amount (only the user-typed payout amount).

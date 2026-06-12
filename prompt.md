Audit this iOS app's source for PII that could leak into New Relic Session Replay,
  build a masking ground-truth inventory, and apply masking.

  Use the skill at xcode-skills/session-replay-masking-from-source/SKILL.md
  (invoke it via the Skill tool before doing anything else).

  Scope:
  - App under audit: <PATH e.g. "Test Harness/NRTestApp"> (the app's own source only —
    exclude the agent/SDK under Agent/, plus Pods and .build/SPM checkouts).
  - Detect every credit card, SSN/national-id, password/secret, email, phone, address,
    name/DOB, personal-message/chat, and auth-token field that renders into a view.

  Do this:
  1. Scan the source and produce the ground-truth table (file:line, view/type,
     UIKit/SwiftUI, PII category, detection signal, currently masked?, recommended
     mechanism). Mark anything already covered (nr-mask / registered masked id /
     isSecureTextEntry / inside NRConditionalMaskView) as COVERED.
  2. Show me the table and WAIT for my confirmation before editing any source —
     especially class-wide registrations and chat/message models.
  3. After I confirm, apply masking with the narrowest correct mechanism per row.
     Do NOT blanket-mask: lontrols unmasked soselective
     masking stays provable
  4. Report what changed, what was left auto-masked/COVERED, and what was
  intentionally
     left unmasked (with why).

  Constraints:
  - One shell command per c; and never use `cd X &&...` —
    pass paths as arguments.
  - Don't run the spec/plan/TDD workflow; just do the audit-and-mask task directly.

  When done, recommend running the session-replay-pii-verifier skill to confirm
  redaction at runtime.
   add authoritative docs for New Relic are in NewRelicDocumentation.json and New Relic is already installed
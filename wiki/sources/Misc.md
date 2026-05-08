- Make ast_grep support AILANG
https://github.com/ast-grep/ast-grep


- Explore integrating Context Mode and/or Headroom for context compression
https://github.com/chopratejas/headroom
https://github.com/mksglu/context-mode


- Explore OpenClaw-RL
https://github.com/Gen-Verse/OpenClaw-RL


- Finetune an LLM for AILANG using eg distil labs, Tinker or Oumi
https://www.distillabs.ai/
https://thinkingmachines.ai/tinker/
https://oumi.ai/


- Explore rewrinting core using CSP: 
https://ailang.sunholo.com/docs/reference/language-syntax#concurrency-csp
https://en.wikipedia.org/wiki/Communicating_sequential_processes
https://dev.to/karanpratapsingh/csp-vs-actor-model-for-concurrency-1cpg


- Explore Monty
https://pydantic.dev/articles/pydantic-monty
https://github.com/pydantic/monty


- Explore LLM Wiki
https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f


- Make Deterministic Simulation Testing the foundation for Motoko
https://www.amplifypartners.com/blog-posts/a-dst-primer-for-unit-test-maxxers


- Incorporate ideas from the "Phoenix Architecture"
https://aicoding.leaflet.pub/


Move this to feature plan:

- Log from core to tui
- Configuration system
- Tool registration systen (Pi inspired)
- Skill registration system (Pi inspired)
- MCP registration (extension?)






Short answer: that claim does not look correct based on Modal’s current docs/pricing (checked April 19, 2026).

  What Modal says publicly:

  - Starter already includes $30/month free credits and pay-as-you-go usage:
    https://modal.com/pricing
  - Billing is auto-charged when you exceed thresholds; it does not describe a separate “buy/add credits” flow limited to Team:
    https://modal.com/docs/guide/billing
  - Team includes $100/month included credits as part of the subscription, but that’s plan-included credit, not evidence that only Team can fund usage:
    https://modal.com/pricing

  So practically:

  - On Starter, you generally use included credits, then usage is billed to your payment method.
  - If your UI specifically says “add credits” is unavailable, that may be a product/UI limitation, but docs suggest billing still works via auto-charges on Starter.

  If you want, I can help you draft a 2-line message to billing@modal.com to confirm your workspace/account behavior.


› I don't like this - it seems like a very risky thing if the account get hacked


• Agreed. Auto-bill on a hacked account is real risk.

  Do this now:

  1. Set a strict workspace budget cap in Modal (Settings -> Usage & Billing -> Workspace budget), as low as you can tolerate.
  2. Use a dedicated virtual card with a hard spending limit for Modal only.
  3. Keep GPU concurrency low (Starter already limits it; keep it that way).
  4. Rotate and minimize secrets; never store long-lived high-privilege cloud keys in Modal.
  5. Enforce org security: SSO/MFA where possible; at minimum ensure strong MFA on all owner accounts.
  6. Add spend monitoring:

  - Daily check in Modal dashboard.
  - Alerting externally (card transaction alerts, email filters).

  7. Separate risky experiments into a separate workspace with its own budget/payment method.

  For your current run plan, I’d cap budget to roughly one H200 experiment window (for example 2-4 hours), then raise only when needed.


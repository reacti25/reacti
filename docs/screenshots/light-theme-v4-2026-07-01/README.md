# Screenshots — Light theme, round 4 (2026-07-01, TestFlight)

Depth pass worked (cards now lift off the canvas). Remaining issues are all
light-on-light contrast + one dark-mode leftover. Referenced by
`docs/PLAN-light-theme-polish-2026-07-01.md`.

- `01-login-fields-labels-invisible.png` — Login: "Email"/"Password" labels, "Login" +
  "Login to continue" heading/subtitle are white/pale = invisible; input fields are
  pale-on-pale (not clearly delineated); "Forgot Password"/"Sign up"/"Reacti" are lime on
  pale = low contrast. **Signup screen has the same problems.** ❌
- `02-chat-list-nav-active-low-contrast.png` — Bottom nav: the ACTIVE item (Chat) is lime
  on the near-white nav = hard to see. ❌
- `03-inbox-media-placeholder-caption-invisible.png` — Media placeholder ("Reacti / Click
  to view the media"): the "Click to view the media" caption is white on pale = invisible;
  the placeholder tile itself is faint. ❌
- `04-inbox-reaction-frame-still-dark.png` — The Reaction message frame (dark/olive card
  around the reaction video + "Reaction" label) is still dark-mode styled on the light
  theme. ❌ (patent UI — colour tokens only, no behaviour change)

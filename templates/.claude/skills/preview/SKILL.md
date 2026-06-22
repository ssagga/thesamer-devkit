---
name: preview
description: Launch the change locally so the human can look at it running BEFORE the agent verifies/audits — especially for visual/UI work. Use at the PREVIEW step (between BUILD and VERIFY) when the preview gate preference calls for it, or when asked to "preview this", "let me see it", "show me the change running". Read-only-ish — it runs the app, it doesn't edit code.
---

# Local preview gate

Between BUILD and VERIFY, offer the human a look at the change **running** instead of racing to the
end. The point is a human eyeball on real behavior — most valuable for visual/UI changes — not an
automated check (that's VERIFY's job).

## When to fire

Per the **preview gate** preference in `CLAUDE.md`:
- `always` → preview every change.
- `visual-only` → preview only changes that affect something a person looks at (UI, layout, copy,
  styling, a rendered page/screen). Skip pure refactors, config, or backend-only logic.
- `never` → skip; go straight to VERIFY.

If it's borderline whether a change is "visual", lean toward previewing — a wasted 20 seconds beats
shipping a visual regression.

## Steps

1. **Detect the app type** and the launch command (from `CLAUDE.md` Commands / the run-&-observe
   note):
   - **Web** → start the dev server (`<dev>`), wait for it to be ready, report the URL, and capture
     a screenshot of the changed view.
   - **CLI / TUI** → run it with a representative invocation and show the output.
   - **Mobile** → boot the simulator/emulator and launch the app.
2. **PATH fallbacks** — if the package manager or runtime isn't on `PATH`, use the local binaries
   (`./node_modules/.bin/<tool>`, `npx <tool>`, the project venv) rather than giving up.
3. **Point at the change** — open/screenshot the *specific* view or flow that changed, not just the
   home screen. Tell the human exactly what to look at.
4. **Hand control to the human.** Let them look and say go / not-yet. If they spot something, loop
   back to BUILD; otherwise proceed to VERIFY.
5. **Clean up** — stop any dev server you started once they're done.

## Rules

- **Don't edit code here.** Preview runs the app; fixes happen back in BUILD.
- **Don't substitute for VERIFY.** A human glance is not the adversarial review or the build gate —
  it's an extra, earlier set of eyes, not a replacement.
- Reuse the project's real launch commands; don't invent a bespoke way to run the app.

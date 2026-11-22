# Protect the main branch (you do this once, on github.com)

Why: with these two rules, nothing gets into `main` (and so onto the
latest-build download page) unless the tests passed. I (the builder) do
**not** change repository settings; only you can turn this on.

Words used here:
- **Branch**: a line of work in the repo. `main` is the one the app is built from.
- **Pull request (PR)**: a request to add changes to `main`, which can be checked before it is accepted.
- **Status check**: an automatic test that runs on GitHub (here: the CI workflow, `ci.yml`).
- **Ruleset**: GitHub's name for a set of rules on a branch.

## Steps (in a browser, signed in as CAPPY7)
1. Open https://github.com/CAPPY7/isekai-drop
2. Tap **Settings** (top menu; on a phone, tap the `...` menu first).
3. In the left menu open **Rules** > **Rulesets**.
4. Tap **New ruleset** > **New branch ruleset**.
5. **Ruleset name**: `protect main`.
6. **Enforcement status**: choose **Active**.
7. **Bypass list**: tap **Add bypass**, tick **Repository admin**, then **Add selected**.
   This keeps direct pushes from your own account (and from me, using your
   token) working. Remove it later if you want every change to go through a pull request.
8. **Target branches**: tap **Add target** > **Include default branch** (that is `main`).
9. Under **Rules**, tick:
   - **Restrict deletions** (usually ticked already)
   - **Block force pushes** (usually ticked already)
   - **Require a pull request before merging**. "Required approvals" can stay **0**,
     since you are the only person working on the repo.
   - **Require status checks to pass**. Then tap **Add checks**, type
     `flutter analyze + flutter test` and pick it from the list.
     (It shows up in the list only after CI has run once; it has, since 0.11.3.)
     Also tick **Require branches to be up to date before merging**.
10. Scroll down and tap **Create**.

## Check it worked
- Settings > Rules > Rulesets shows `protect main` as **Active**.
- A pull request now shows "Required" next to `flutter analyze + flutter test`,
  and the Merge button stays grey until it is green.

## Undo
Settings > Rules > Rulesets > `protect main` > set **Enforcement status** to
**Disabled** (or delete the ruleset at the bottom of its page).

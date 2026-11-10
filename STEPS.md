# DevSecOps activity: step-by-step

The ready-made files in this bundle are the **final** versions. Follow the order below: the drills grade you on *seeing* a check go red, then fixing it, so don't paste everything at once.

Files in this bundle (paths match the repo):
- `.pre-commit-config.yaml`: ruff + gitleaks hook
- `.github/workflows/security.yml`: final 4-job pipeline (Drill 5 state)
- `campus_notifier/settings.py`: SECRET_KEY read from env
- `terraform/main.tf`: KMS encryption added (fixes Checkov CKV_AWS_136)
- `requirements.txt`: Django 5.2.7 → 5.2.19
- `SECURITY_REGISTER.md`: findings register + gate policy + discussion answers

---

## 0. Setup
```bash
git clone <your-fork-url>
cd devops-2025S-demo
git switch -c devsecops-scans
pip install pre-commit
pre-commit install          # installs the git hook into .git/hooks/pre-commit
```
Make sure Docker Desktop is running.

## 1. Drill 1: leak check at commit time
1. Copy in `.pre-commit-config.yaml` (note: the original file had no newline at the end; mine fixes that).
2. Commit it:
   ```bash
   git add -A
   git commit -m "devsecops: pre-commit leak check"
   ```
   Expect: `ruff ... Skipped`, `ruff-format ... Skipped`, `Detect hardcoded secrets ... Passed`.
3. Prove it blocks:
   ```bash
   python3 -c "import secrets; print(secrets.token_hex(32))"
   ```
   In `campus_notifier/settings.py`, replace line 27 with `SECRET_KEY = "<that key>"`, then:
   ```bash
   git add campus_notifier/settings.py
   git commit -m "test leak"        # should FAIL: rule generic-api-key, file + line shown
   git restore --staged --worktree campus_notifier/settings.py
   ```
   **Screenshot both terminal outputs.**

## 2. Drill 2: Bandit + gitleaks on the PR (see red first!)
1. Create `.github/workflows/security.yml` with **only the handout's two jobs** (`code` with `continue-on-error: true`, and `secrets`). Leave `settings.py` untouched.
   *Tip: add the `env:` block under the Gitleaks step from my file (`GITHUB_TOKEN` + `GITLEAKS_ENABLE_COMMENTS: false`). The action needs the token to scan PRs.*
2. Push and open a PR **inside your own fork** (base: `<you>/devops-2025S-demo:main`, NOT pelino250's):
   ```bash
   git add .github/workflows/security.yml
   git commit -m "devsecops: bandit + gitleaks CI"
   git push -u origin devsecops-scans
   ```
3. Checks tab: Secret scan ✅, Code scan ❌ (B105 on settings.py:27). **Screenshot.**
4. Fix it:
   ```bash
   grep -n "^.env$" .gitignore          # confirm .env is ignored before writing it
   echo "DJANGO_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')" > .env
   ```
   Copy in my `campus_notifier/settings.py`, then:
   ```bash
   git status                          # .env must NOT appear here
   git add campus_notifier/settings.py
   git commit -m "fix(B105): read SECRET_KEY from environment"
   git push
   ```
   Code scan goes ✅.

   ⚠️ Running the app now needs the env var. Locally, `.env` is loaded automatically. In Docker, `.env` is excluded by `.dockerignore`, so use `docker run --env-file .env ...` (or `env_file: .env` in compose).

## 3. Drill 3: Trivy image scan
1. Add the handout's `image` job (`severity: HIGH,CRITICAL`, `exit-code: "0"`). Commit and push.
2. When it finishes, open the job log → Trivy table. **Write down the HIGH and CRITICAL counts** in register row 3 (it has blanks for this). Django 5.2.7 shows up under the Python packages section.
3. Remedy: copy in my `requirements.txt` (Django 5.2.19), commit, push, and watch the Python section shrink.

## 4. Drill 4: Checkov IaC scan
1. Add the handout's `iac` job (`soft_fail: true`). Commit and push.
2. Expect 1 failure: **CKV_AWS_136** (ECR not encrypted with KMS). I ran Checkov locally and that is the only one (3 passed, 1 failed).
3. Fix: copy in my `terraform/main.tf`, commit, push → 4 passed, 0 failed.

## 5. Drill 5: turn the gates on
1. Replace `security.yml` with my final version. It does what the handout asks:
   - image: `severity: CRITICAL`, `exit-code: "1"`, plus `ignore-unfixed: true` ("CRITICAL **with a fix published** fails")
   - iac: `soft_fail: false`
   - code: my call = **block on Medium+, report Low** (reason in the register)
2. Add `SECURITY_REGISTER.md`, commit, push:
   ```bash
   git add .github/workflows/security.yml SECURITY_REGISTER.md
   git commit -m "devsecops: enforce gates + findings register"
   git push
   ```
3. If **Image scan** goes red: there's a fixable CRITICAL in the Debian base packages. Fix it by adding this line to the Dockerfile right after `WORKDIR /app`:
   ```dockerfile
   RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
   ```
   Note it in register row 3.
4. All 4 checks green → copy the PR URL → submit it on Canvas.

# Security Findings Register: devsecops-scans

Owner for all rows: Hubert2c. Register opened 2026-11-10.

Every finding from Drills 2–4 gets a decision: **Remediate**, **Suppress** (with a written justification), or **Accept** (documented risk, owner, revisit date).

| # | Scanner | ID / Rule | Severity | Location | Finding | Decision | Justification / Action | Owner | Revisit |
|---|---------|-----------|----------|----------|---------|----------|------------------------|-------|---------|
| 1 | Bandit | B105 `hardcoded_password_string` (CWE-259) | Low (Medium confidence) | `campus_notifier/settings.py:27` | Django `SECRET_KEY` hardcoded in source | **Remediate** | Key moved to `.env` (`DJANGO_SECRET_KEY`, git-ignored) and read with `os.environ["DJANGO_SECRET_KEY"]`. **Removed from the file ≠ rotated:** the old `django-insecure-...` key is still in git history, so anyone with the repo can read it. Treat it as burned: never use it in any deployed environment, and generate a fresh key per environment. Full fix needs a history rewrite (`git filter-repo`), which is out of scope for a class repo. | Hubert2c | 2026-12-10 |
| 2 | Trivy | Django 5.2.7 CVEs (incl. CVE-2025-64459, SQL injection via `_connector`, rated "high" by Django) and later 5.2.x security releases | HIGH (Python pkg) | `requirements.txt` → image `campus-notifier:dev` | Django pinned to a version a year behind on security patches | **Remediate** | Bumped to `Django==5.2.19` (latest 5.2 LTS patch). Stays on the 5.2 LTS line, so no breaking changes. | Hubert2c | Each Django security release |
| 3 | Trivy | OS packages in `python:3.12-slim` (Debian) | Not measured | Base image | Trivy could not scan the image: GitHub assigned no runner to the workflow jobs, and Docker is unavailable locally | **Pending scan** | Re-run Trivy when a runner is available and record HIGH/CRITICAL counts. Remediate fixable findings; document and revisit unfixed findings monthly. | Hubert2c | 2026-12-10 |
| 4 | Checkov | CKV_AWS_136: "Ensure that ECR repositories are encrypted using KMS" | n/a (policy check) | `terraform/main.tf`, `aws_ecr_repository.devops_repo` | ECR repo used default AES256 instead of KMS | **Remediate** | Added `encryption_configuration { encryption_type = "KMS" }` using the AWS-managed key: no extra cost or key to manage. Checkov now 4 passed / 0 failed. | Hubert2c | n/a |

## Gate policy (Drill 5)

| Job | Gate | Why |
|-----|------|-----|
| Secret scan (gitleaks) | **Blocks** on any finding | A real leaked secret is never acceptable; there is no "low severity" leak. |
| Image scan (Trivy) | **Blocks** on CRITICAL **with a fix available** (turned on deliberately) | Critical + fixable = we can act today. Blocking on unfixable CVEs only trains people to disable the gate. Blocking on HIGH too would be stricter; we chose to see HIGH in the report without blocking on it. |
| IaC scan (Checkov) | **Blocks** on any failed check (turned on deliberately) | IaC findings are cheap to fix before `terraform apply` and expensive after. Accepted risks must be suppressed inline with `#checkov:skip=ID:reason`, so the justification lives next to the code. |
| Code scan (Bandit) | **Blocks** on Medium/High; Low is reported only | Low findings (like B105) are pattern guesses with false positives. Blocking on them creates noise. Medium/High (injection, unsafe deserialization, `shell=True`) are worth stopping a merge for. Today's finding was Low *and* got fixed anyway, because the report still shows it. |

## Discussion answers

**Why does CI run gitleaks again when the pre-commit hook exists?**
The hook is optional and local: a teammate may never run `pre-commit install`, can skip it with `git commit --no-verify`, or can commit from the GitHub web editor. CI is the one check nobody can skip. It's also a different view: CI looks at all the commits in the PR, not just the currently staged diff.

**Why did Bandit flag a key that gitleaks passed?**
They ask different questions. gitleaks asks "is this a *real* credential?" and deliberately ignores the `django-insecure-` prefix, because that marks Django's generated dev placeholder. Bandit asks "is a password-like variable (`SECRET_KEY`) assigned a hardcoded string?" It flags the *pattern*, whatever the value is. Both views are right: the value is a placeholder, but hardcoding the key is still the wrong pattern for production.

**Drill 1: what was the difference between the passed and refused commit?**
The first commit only staged `.pre-commit-config.yaml`: no Python, so the ruff hooks were *Skipped*, and gitleaks found nothing. The second staged `settings.py` with a random 64-char hex string assigned to `SECRET_KEY`. gitleaks matched it to rule `generic-api-key` (high-entropy value next to a key-like name), exited 1, and git aborted the commit.

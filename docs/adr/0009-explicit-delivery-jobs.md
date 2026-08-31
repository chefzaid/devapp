# ADR 0009: Use Explicit Delivery Jobs And Non-Blocking Verification

## Status

Accepted. This supersedes the job topology in ADR 0007 while retaining its GitOps, daemonless Kaniko, and immutable-tag decisions.

## Decision

Expose GitLab jobs named `01-build`, `02-test`, `03-package`, `01-e2e`, `02-quality`, `01-release`, `02-deploy`, and `set-major-version`. Numeric prefixes preserve the intended order in GitLab's alphabetically sorted stage boxes. Build compiles the application, optional tests own unit and coverage results, and package validates the runtime images.

`01-e2e` is optional and manual. `02-quality` consumes the test artifacts directly, submits SonarQube analysis without waiting for its gate, and retains dependency-audit reports; it is optional and manual in standard mode and automatic in full mode. The verify jobs are independent, and neither is a release dependency. `01-release` requires the compiled artifacts and successful package validation, publishes images/packages and Git release state, and `02-deploy` runs only after release passes.

Normal pipelines run `01-build`, `02-test`, and `03-package` automatically and expose E2E, quality, and release manually. A default-branch pipeline started with `PIPELINE_MODE=full` runs non-blocking quality reporting automatically and automates release and deploy after the required build path; E2E remains optional and manual.

Keep a `VERSION` baseline in Git. Increment patch deterministically from new commits, tag the exact version deployed, prepare the next minor baseline after release, and reset to `<major>.0.0` only through the major-version job. Synchronize Maven and npm manifests when a version baseline changes.

Keep Sonar, GitLab project metadata, labels, badges, branch protection, CI variables, and retention automation in repository-owned scripts. Keep secrets in Vault and GitLab masked variables.

## Consequences

- Every operation has an accurate job name, status, log, duration, and retry action.
- Compilation and package failures stop delivery; test, coverage, browser, Sonar, and dependency findings remain visible without becoming release gates.
- Release reuses build outputs instead of compiling and scanning a second time.
- Thirty-day registry-backed Kaniko layers and dependency/analyzer caches reduce repeated work.
- SonarQube Community Build analyzes only `main`; branch and merge-request pipelines still retain local test, coverage, and dependency reports.

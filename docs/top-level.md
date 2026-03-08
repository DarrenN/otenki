## Standards

- Use the Functional Core, Imperative Shell pattern.
- Follow the 12 Factor Apps philosophy.
- TDD: write tests before implementation, then run them.
- All code should be well documented.

### Makefile

- Every project needs a `Makefile` with dev/prod build, test, and cleanup targets.

### Git / GitHub

- Sync `main` with `origin:main` and create a working branch before starting new work.
- Run tests before every commit; fix failures before proceeding.
- Use Conventional Commits (`fix:`, `feat:`, `refactor:`, `chore:`, `style:`, `docs:`, `test:`).
- Use `git` directly, `gh` is available for Pull Requests, etc.
- Prefer `README.org` over `README.md`.

### Tools

- Use `rg` instead of `grep` (`rg -h` for help).

### Docker / Containers

- Use explicit base image tags (never `latest`).
- Multi-stage builds; run final container as non-root user.
- Keep runtime path consistent (`/app` in image, entrypoint, and launcher).
- Add a `HEALTHCHECK` instruction that probes a health route.
- Include a `make docker-smoke` target: build → start → probe readiness.

#### Hadolint

- Run `hadolint Dockerfile` before commit (if not installed, install it).
- Fix findings by default; use inline `# hadolint ignore=RULE` only for intentional exceptions.

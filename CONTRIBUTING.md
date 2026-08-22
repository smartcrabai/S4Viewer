# Contributing

Thank you for your interest in contributing.

## How to Contribute

1. Open an issue or discussion for non-trivial changes before starting work.
2. Fork the repository and create a topic branch.
3. Keep changes focused and include tests or documentation updates when appropriate.
4. Run `xcodebuild -scheme "S4 Viewer" -destination 'platform=macOS' test` before opening a
   pull request. That is the `UnitTests` plan; the XCUITest suite (`-testPlan AllTests`)
   takes over the cursor and keyboard of the machine it runs on, so run it on a spare
   machine or a VM. See `README.md`.
5. Open a pull request with a clear summary and any relevant context.

## Pull Request Guidelines

- Keep pull requests small and reviewable.
- Explain why the change is needed, not only what changed.
- Link related issues when applicable.
- Be respectful and constructive in reviews and discussions.

## Security Issues

Please do not disclose security vulnerabilities in public issues. See `SECURITY.md` for reporting instructions.

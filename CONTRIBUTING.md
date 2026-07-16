# Contributing to AnVPS

## Code of Conduct

By participating, you agree to maintain a respectful, inclusive environment. Harassment, trolling, and discrimination are not tolerated.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Include:
   - Android version and device model
   - Rooted or unrooted
   - RAM and storage available
   - Exact error output (run `anvps doctor` first)
   - Steps to reproduce

### Suggesting Features

Open an issue with the `enhancement` label describing:
- The problem you're solving
- Proposed solution
- Alternative approaches considered

### Pull Requests

1. Fork the repo and create a branch: `git checkout -b feature/your-feature`
2. Make changes following the existing code style
3. Run tests: `make test` or `bash tests/unit/test_install.sh`
4. Ensure bash syntax: `make lint`
5. Commit with clear messages: `type(scope): description`
6. Open PR against `main` branch

### Commit Style

```
feat(tier): add 32MB shadow mode detection
fix(cli): correct service status parsing
docs(readme): update architecture diagram
security(tor): add kill switch integration
```

### Code Style

- **Bash**: `set -euo pipefail` at top of all scripts; `local` variables; 4-space indent
- **Python**: PEP 8; type hints where practical
- **Quoting**: Always quote variables (`"$var"` not `$var`)
- **Functions**: Lowercase with underscores; document with comments
- **Error handling**: Check return codes; provide meaningful error messages

### Testing

- All bash scripts must pass `bash -n` syntax check
- Unit tests: `bash tests/unit/test_install.sh`
- New features should include test coverage

### Documentation

- Update `docs/` when adding features
- Keep README badges and tables current
- Document CLI commands in `docs/commands.md`

## Questions?

Open a discussion or issue. We're happy to help.

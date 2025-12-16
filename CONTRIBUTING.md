# Contributing to MacBook Pro Thermal Management Scripts

First off, thank you for considering contributing. It’s people like you that make this project a great tool for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior.

## How Can I Contribute?

### Reporting Bugs

- **Ensure the bug was not already reported** by searching on GitHub under [Issues](https://github.com/nelsojona/macbook-cooler/issues).
- If you're unable to find an open issue addressing the problem, [open a new one](https://github.com/nelsojona/macbook-cooler/issues/new). Be sure to include a **title and clear description**, as much relevant information as possible, and a **code sample** or an **executable test case** demonstrating the expected behavior that is not occurring.

### Suggesting Enhancements

- Open a new issue and provide a clear description of the enhancement you are suggesting.
- Explain why this enhancement would be useful to other users.

### Pull Requests

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/AmazingFeature`).
3.  Make your changes.
4.  Ensure your code lints (`shellcheck *.sh`).
5.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
6.  Push to the branch (`git push origin feature/AmazingFeature`).
7.  Open a pull request.

## Styleguides

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature").
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...").
- Limit the first line to 72 characters or less.
- Reference issues and pull requests liberally after the first line.

### Shell Scripting Styleguide

- All scripts should be `shellcheck` compliant.
- Use `set -euo pipefail` at the beginning of your scripts.
- Use descriptive variable names.
- Comment your code where necessary.

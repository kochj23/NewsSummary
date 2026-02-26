# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.2.x   | Yes       |
| < 2.0   | No        |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public GitHub issue**
2. Email: kochj23 (via GitHub)
3. Include: description, steps to reproduce, potential impact

We aim to respond within 48 hours and provide a fix within 7 days for critical issues.

## Security Features

- **Local AI Processing**: News analysis runs on-device via local LLM backends
- **No Cloud Upload**: Article content and analysis never leave your machine
- **Multi-Perspective Analysis**: Bias detection without transmitting user preferences
- **Keychain Storage**: Any API keys stored in macOS Keychain
- **No Telemetry**: Zero analytics, crash reporting, or usage tracking
- **Fact-Checking Privacy**: Verification runs locally — your reading habits stay private

## Best Practices

- Never hardcode credentials or API keys
- Report suspicious behavior immediately
- Keep dependencies updated
- Review all code changes for security implications

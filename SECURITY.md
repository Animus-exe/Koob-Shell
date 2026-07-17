# Security policy

## Supported versions

Security fixes are applied to the latest release on the default branch.

## Reporting a vulnerability

If you discover a security issue, please report it privately rather than opening a public issue.

1. Do not disclose the vulnerability publicly until it has been addressed.
2. Use [GitHub private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) once the repository is published, or contact the maintainer directly until then.
3. Include steps to reproduce and the impact if known.
4. Allow reasonable time for a fix before public disclosure.

Koob Shell is a local-only macOS app. It does not sync data, elevate privileges, or run remote jobs. Reports involving local data exposure, shell injection, or unsafe file handling are especially welcome.

## Scope

In scope:

- Code execution or privilege escalation via Koob Shell features
- Unsafe handling of pasted shell input, plugin manifests, or workflow hooks
- SQLite or filesystem access outside intended App Support paths

Out of scope:

- Issues in third-party dependencies (report those upstream; we will bump versions as needed)
- Social engineering or physical access to an unlocked Mac

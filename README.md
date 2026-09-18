# tools
Tools repo

GitHub Actions runs PowerShell analysis and Pester tests on pushes and pull requests.
Analysis errors and failed tests fail CI; warnings remain visible for review.
GitHub Actions are pinned to full commit SHAs.

Run the tests locally in PowerShell 7.4 or newer:

```powershell
Install-Module Pester -RequiredVersion 6.2.0 -Scope CurrentUser -Force -SkipPublisherCheck
Import-Module Pester -RequiredVersion 6.2.0
Invoke-Pester -Path ./tests -Output Detailed
```

The tests cover branch-cleanup eligibility, dry runs, explicit deletion, and
`-WhatIf`. Git commands are mocked so tests do not delete real branches.

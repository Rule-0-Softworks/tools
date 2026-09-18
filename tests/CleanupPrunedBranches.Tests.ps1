BeforeAll {
    . "$PSScriptRoot/../powershell/CleanupPrunedBranches.ps1"
}

Describe 'Branch deletion eligibility' {
    BeforeEach {
        $branch = [pscustomobject]@{
            Name = 'feature/finished'
            UpstreamGone = $true
            UsedByWorktree = $false
            MergedInto = @('dev')
            MergedPrBase = 'dev'
        }
    }

    It 'accepts a removed upstream merged into an allowed base' {
        @(Get-DeletionCandidates -Branches @($branch)).Name | Should -Be 'feature/finished'
    }

    It 'protects the <Base> base branch' -TestCases @(
        @{ Base = 'main' }, @{ Base = 'develop' }, @{ Base = 'dev' }
    ) {
        param($Base)
        $branch.Name = $Base
        @(Get-DeletionCandidates -Branches @($branch)).Count | Should -Be 0
    }

    It 'keeps branches whose upstream still exists' {
        $branch.UpstreamGone = $false
        @(Get-DeletionCandidates -Branches @($branch)).Count | Should -Be 0
    }

    It 'keeps branches checked out in a worktree' {
        $branch.UsedByWorktree = $true
        @(Get-DeletionCandidates -Branches @($branch)).Count | Should -Be 0
    }

    It 'keeps branches without a verified merge into an allowed base' {
        $branch.MergedInto = @('feature/other')
        @(Get-DeletionCandidates -Branches @($branch)).Count | Should -Be 0
    }

    It 'uses the merged PR base in PullRequest mode' {
        $branch.MergedInto = @()
        @(Get-DeletionCandidates -Branches @($branch) -VerificationMode PullRequest).Count | Should -Be 1
    }

    It 'rejects a PR merged into an unapproved base' {
        $branch.MergedPrBase = 'feature/other'
        @(Get-DeletionCandidates -Branches @($branch) -VerificationMode PullRequest).Count | Should -Be 0
    }
}

Describe 'Cleanup execution safeguards' {
    BeforeEach {
        Mock git { $global:LASTEXITCODE = 0 }
        Mock Get-WorktreeBranches { @() }
        Mock Get-LocalBranchStates {
            [pscustomobject]@{ Name = 'feature/finished'; UpstreamGone = $true; Sha = 'abc123' }
        }
        Mock Get-AncestryBases { 'dev' }
        Mock Write-Host {}
        Mock Write-Warning {}
    }

    It 'does not delete by default' {
        Invoke-CleanupPrunedBranches -RepositoryPath $TestDrive -VerificationMode Ancestry
        Should -Invoke git -Times 0 -Exactly -ParameterFilter { $args -contains '-D' }
    }

    It 'deletes a verified candidate when Apply is requested' {
        Invoke-CleanupPrunedBranches -RepositoryPath $TestDrive -VerificationMode Ancestry -Apply
        Should -Invoke git -Times 1 -Exactly -ParameterFilter {
            $args -contains '-D' -and $args -contains 'feature/finished'
        }
    }

    It 'honors WhatIf even when Apply is requested' {
        Invoke-CleanupPrunedBranches -RepositoryPath $TestDrive -VerificationMode Ancestry -Apply -WhatIf
        Should -Invoke git -Times 0 -Exactly -ParameterFilter { $args -contains '-D' }
    }

    It 'stops if the directory is not a Git repository' {
        Mock git { $global:LASTEXITCODE = 1 }
        { Invoke-CleanupPrunedBranches -RepositoryPath $TestDrive -VerificationMode Ancestry } |
            Should -Throw '*Not a git repository*'
        Should -Invoke Get-LocalBranchStates -Times 0 -Exactly
    }
}

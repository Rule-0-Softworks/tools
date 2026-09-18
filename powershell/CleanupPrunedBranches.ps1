[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RepositoryPath = '.',
    [ValidateSet('Ancestry', 'PullRequest')]
    [string]$VerificationMode = 'Ancestry',
    [switch]$Apply,
    [switch]$FetchPrune
)

$ErrorActionPreference = 'Stop'
$script:AllowedBaseBranches = @('main', 'develop', 'dev')

function Test-BranchVerified {
    param(
        [Parameter(Mandatory)][object]$Branch,
        [Parameter(Mandatory)][string]$VerificationMode
    )

    if ($VerificationMode -eq 'Ancestry') {
        return @($Branch.MergedInto | Where-Object { $_ -in $script:AllowedBaseBranches }).Count -gt 0
    }

    return $Branch.MergedPrBase -in $script:AllowedBaseBranches
}

function Get-DeletionCandidates {
    param(
        [Parameter(Mandatory)]
        [object[]]$Branches,
        [ValidateSet('Ancestry', 'PullRequest')]
        [string]$VerificationMode = 'Ancestry'
    )

    $Branches | Where-Object {
        $_.Name -notin $script:AllowedBaseBranches -and
        $_.UpstreamGone -and
        -not $_.UsedByWorktree -and
        (Test-BranchVerified -Branch $_ -VerificationMode $VerificationMode)
    }
}

function Get-LocalBranchStates {
    param([Parameter(Mandatory)][string]$Repository)

    git -C $Repository for-each-ref refs/heads --format='%(refname:short)%00%(upstream:track)%00%(objectname)' |
        ForEach-Object {
            $parts = $_ -split "`0", 3
            [pscustomobject]@{
                Name         = $parts[0]
                UpstreamGone = $parts.Count -eq 3 -and $parts[1] -eq '[gone]'
                Sha          = if ($parts.Count -eq 3) { $parts[2] } else { $null }
            }
        }
}

function Get-WorktreeBranches {
    param([Parameter(Mandatory)][string]$Repository)

    git -C $Repository worktree list --porcelain |
        Where-Object { $_ -like 'branch refs/heads/*' } |
        ForEach-Object { $_.Substring('branch refs/heads/'.Length) }
}

function Get-AncestryBases {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$Branch
    )

    foreach ($base in $script:AllowedBaseBranches) {
        # Resolve exactly one base ref, preferring the remote-tracking ref.
        # A merge that only exists on an unpushed local base does not qualify
        # while origin has that base; the work must be reachable from origin.
        $baseRef = $null
        git -C $Repository show-ref --verify --quiet "refs/remotes/origin/$base"
        if ($LASTEXITCODE -eq 0) {
            $baseRef = "refs/remotes/origin/$base"
        }
        else {
            git -C $Repository show-ref --verify --quiet "refs/heads/$base"
            if ($LASTEXITCODE -eq 0) {
                $baseRef = "refs/heads/$base"
            }
        }
        if (-not $baseRef) { continue }

        git -C $Repository merge-base --is-ancestor "refs/heads/$Branch" $baseRef
        if ($LASTEXITCODE -eq 0) {
            $base
        }
    }
}

function Get-MergedPullRequestBase {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$Branch
    )

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'PullRequest verification requires the GitHub CLI (gh).'
    }

    $tip = git -C $Repository rev-parse "refs/heads/$Branch"
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to resolve the local tip of '$Branch'."
    }

    Push-Location -LiteralPath $Repository
    try {
        $json = gh pr list --state merged --head $Branch --json baseRefName,headRefOid --limit 100
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to query merged pull requests for '$Branch'."
        }

        # Only accept a merged PR whose head SHA equals the current local tip.
        # This closes the branch-name-reuse hole: a recycled name with new
        # local commits will not match any previously merged PR and fails closed.
        @($json | ConvertFrom-Json |
            Where-Object { $_.headRefOid -eq $tip } |
            ForEach-Object { $_.baseRefName })
    }
    finally {
        Pop-Location
    }
}

function Invoke-CleanupPrunedBranches {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$RepositoryPath,
        [Parameter(Mandatory)]
        [ValidateSet('Ancestry', 'PullRequest')]
        [string]$VerificationMode,
        [switch]$Apply,
        [switch]$FetchPrune
    )

    $repo = (Resolve-Path -LiteralPath $RepositoryPath).Path

    # Native command failures do not throw under ErrorActionPreference = 'Stop',
    # so verify the path is a repository explicitly instead of silently reporting
    # an empty branch list.
    git -C $repo rev-parse --is-inside-work-tree | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Not a git repository: $repo" }

    if ($FetchPrune) {
        git -C $repo fetch --all --prune
        if ($LASTEXITCODE -ne 0) { throw 'Git fetch/prune failed.' }
    }
    else {
        Write-Warning '[gone] detection reflects the last fetch/prune. Run with -FetchPrune for current remote state.'
    }

    $worktreeBranches = @(Get-WorktreeBranches -Repository $repo)
    $branches = @(Get-LocalBranchStates -Repository $repo)
    foreach ($branch in $branches) {
        $branch | Add-Member -NotePropertyName UsedByWorktree -NotePropertyValue ($branch.Name -in $worktreeBranches)
        if (-not $branch.UpstreamGone) { continue }

        if ($VerificationMode -eq 'Ancestry') {
            $branch | Add-Member -NotePropertyName MergedInto -NotePropertyValue @(Get-AncestryBases -Repository $repo -Branch $branch.Name)
        }
        else {
            $branch | Add-Member -NotePropertyName MergedPrBase -NotePropertyValue @((Get-MergedPullRequestBase -Repository $repo -Branch $branch.Name) | Where-Object { $_ -in $script:AllowedBaseBranches } | Select-Object -First 1)
        }
    }

    $verifiedBranches = @($branches | Where-Object {
        $_.Name -notin $script:AllowedBaseBranches -and
        $_.UpstreamGone -and
        (Test-BranchVerified -Branch $_ -VerificationMode $VerificationMode)
    })
    foreach ($branch in @($verifiedBranches | Where-Object UsedByWorktree)) {
        Write-Host "SKIP: $($branch.Name) is checked out in another worktree."
    }

    $candidates = @(Get-DeletionCandidates -Branches $branches -VerificationMode $VerificationMode)
    if ($candidates.Count -eq 0) {
        Write-Host 'No safe pruned branches.'
        return
    }

    # The SHA in each line is the recovery breadcrumb. A branch's reflog is
    # deleted with the branch, so this output is the durable record needed
    # to restore a tip via: git branch <name> <sha>
    foreach ($branch in $candidates) {
        $reason = if ($VerificationMode -eq 'Ancestry') { "merged into $($branch.MergedInto -join ', ')" } else { "PR merged into $($branch.MergedPrBase)" }
        Write-Host "DELETE candidate: $($branch.Name) @ $($branch.Sha) (upstream gone; $reason)"
    }

    if (-not $Apply) {
        Write-Host 'Dry run. Add -Apply to delete.'
        return
    }

    foreach ($branch in $candidates) {
        if (-not $PSCmdlet.ShouldProcess("$($branch.Name) @ $($branch.Sha)", 'git branch -D')) { continue }

        git -C $repo branch -D -- $branch.Name
        if ($LASTEXITCODE -ne 0) { throw "Failed to delete '$($branch.Name)'." }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-CleanupPrunedBranches -RepositoryPath $RepositoryPath -VerificationMode $VerificationMode -Apply:$Apply -FetchPrune:$FetchPrune
}
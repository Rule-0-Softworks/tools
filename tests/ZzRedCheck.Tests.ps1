Describe "scratch" {
    It "deliberately fails to prove required-ci goes red" {
        $true | Should -BeFalse
    }
}

$ErrorActionPreference = 'Stop'
function Run-Check([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}
Run-Check 'flutter' @('analyze')
Run-Check 'flutter' @('test')
Run-Check 'py' @('-3','-m','unittest','discover','-s','pipeline/tests','-v')
Run-Check 'py' @('-3','pipeline/self_test.py')
Run-Check 'py' @('-3','pipeline/audit_report.py','--db','assets/content.sqlite','--outdir','reports/audit')
Run-Check 'py' @('-3','pipeline/release_gate.py','--db','assets/content.sqlite')
Run-Check 'flutter' @('build','apk','--debug')
Write-Host 'App checks completed. Editorial release readiness is reported separately.'

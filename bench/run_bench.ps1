# Замеры pgbench для solution_a / solution_b / solution_c.
# Использование: .\bench\run_bench.ps1 -Tag 128mb
#   -Tag       метка прогона (попадает в имена файлов results\bench_<Tag>.*)
#   -Clients   число параллельных клиентов pgbench (по умолчанию 4)
#   -Duration  длительность замера в секундах (по умолчанию 15)
#   -Warmup    длительность прогрева в секундах (по умолчанию 5, результат отбрасывается)
param(
    [Parameter(Mandatory = $true)][string]$Tag,
    [int]$Clients = 4,
    [int]$Duration = 15,
    [int]$Warmup = 5,
    # какие сценарии запускать (по умолчанию все)
    [string[]]$Scenarios = @('read_entity', 'read_static', 'update_status', 'delete_entity', 'insert_entity'),
    # synchronous_commit=off: убирает ожидание записи WAL на диск при коммите (изолирует CPU/индексную стоимость от fsync)
    [switch]$SyncCommitOff
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
New-Item -ItemType Directory -Force results | Out-Null

$container = 'test-postgres'
$psql = @('exec', $container, 'psql', '-U', 'test_user', '-d', 'testdb', '-v', 'ON_ERROR_STOP=1')

# Порядок сценариев: чтение -> обновление -> удаление -> вставка (вставка последней, чтобы рост таблиц не влиял на остальные)
$scenarios = $Scenarios
$solutions = 'a', 'b', 'c'

docker cp bench "${container}:/tmp/bench" | Out-Null
docker cp sql/07_seed_localizations.sql "${container}:/tmp/07_seed_localizations.sql" | Out-Null

Write-Host "== [$Tag] Пересоздание данных (одинаковое исходное состояние)"
& docker @psql -q -f /tmp/07_seed_localizations.sql | Out-Null
& docker @psql -q -c "VACUUM (ANALYZE) solution_a.payment_methods, solution_a.languages, solution_a.entity_localizations, solution_a.static_localizations, solution_a.translations, solution_b.payment_methods, solution_b.languages, solution_b.entity_localizations, solution_b.static_localizations, solution_b.translations, solution_c.payment_methods, solution_c.languages, solution_c.entity_translations, solution_c.static_translations" | Out-Null
& docker @psql -t -A -c "SHOW shared_buffers" | ForEach-Object { Write-Host "shared_buffers = $_" }

function Invoke-Pgbench([string]$file, [int]$seconds) {
    $envArgs = @()
    if ($SyncCommitOff) { $envArgs = @('-e', 'PGOPTIONS=-c synchronous_commit=off') }
    $out = docker exec @envArgs $container pgbench -U test_user -d testdb -n -M prepared -c $Clients -j ([Math]::Min($Clients, 2)) -T $seconds -f "/tmp/bench/$file" 2>&1 | Out-String
    return $out
}

$rows = @()
$log = New-Object System.Text.StringBuilder
foreach ($sc in $scenarios) {
    foreach ($s in $solutions) {
        $file = "${s}_$sc.sql"
        Write-Host "   $sc / solution_$s (прогрев $Warmup c, замер $Duration c)"
        Invoke-Pgbench $file $Warmup | Out-Null
        $out = Invoke-Pgbench $file $Duration
        [void]$log.AppendLine("##### $Tag $sc solution_$s")
        [void]$log.AppendLine($out)
        $tps = [regex]::Match($out, 'tps = ([\d.]+)').Groups[1].Value
        $lat = [regex]::Match($out, 'latency average = ([\d.]+) ms').Groups[1].Value
        $n = [regex]::Match($out, 'number of transactions actually processed: (\d+)').Groups[1].Value
        $failed = [regex]::Match($out, 'number of failed transactions: (\d+)').Groups[1].Value
        $rows += [pscustomobject]@{
            tag = $Tag; sync_commit = $(if ($SyncCommitOff) { 'off' } else { 'on' }); scenario = $sc; solution = "solution_$s"; clients = $Clients; seconds = $Duration
            tps = [double]::Parse($tps, [Globalization.CultureInfo]::InvariantCulture)
            latency_ms = [double]::Parse($lat, [Globalization.CultureInfo]::InvariantCulture)
            transactions = [int]$n; failed = [int]$failed
        }
    }
}

$rows | Export-Csv -NoTypeInformation -Encoding UTF8 "results\bench_$Tag.csv"
[System.IO.File]::WriteAllText("$root\results\bench_$Tag.log", $log.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "== Результаты [$Tag]"
$rows | Format-Table scenario, solution, tps, latency_ms, transactions, failed -AutoSize | Out-String | Write-Host

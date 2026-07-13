# install.ps1
# Instala a skill poc-swarm no Copilot CLI (Windows) criando um symlink:
#   ~/.copilot/skills/poc-swarm  ->  <raiz deste repo>
#
# Uso:
#   pwsh scripts/install.ps1
#   pwsh scripts/install.ps1 -WithTools   # tenta instalar tb o toolchain de validação/deploy (az/bicep/terraform/tflint/checkov)
#
# O symlink no Windows exige Developer Mode habilitado
# (Settings > Privacy & security > For developers) OU um terminal elevado.
# Se a criação de symlink falhar, o script cai para junction (mklink /J),
# que não exige privilégio.

[CmdletBinding()]
param(
  # Quando presente, tenta instalar o toolchain de validação/deploy:
  # Azure CLI + Bicep, Terraform, tflint (winget) e checkov (pip).
  [switch]$WithTools
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$SkillsDir = Join-Path $env:USERPROFILE '.copilot\skills'
$LinkPath  = Join-Path $SkillsDir 'poc-swarm'

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'SKILL.md'))) {
  throw "SKILL.md não encontrado em $RepoRoot — rode este script de dentro do repo poc-swarm."
}

Write-Host '🛠️🐝 Instalando skill poc-swarm'
Write-Host "   repo:  $RepoRoot"
Write-Host "   link:  $LinkPath"

New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null

# Remove link/pasta existente (sem seguir o link).
if (Test-Path -LiteralPath $LinkPath) {
  $item = Get-Item -LiteralPath $LinkPath -Force
  if ($item.LinkType) { $item.Delete() } else { Remove-Item -LiteralPath $LinkPath -Recurse -Force }
}

$kind = $null
try {
  New-Item -ItemType SymbolicLink -Path $LinkPath -Target $RepoRoot -ErrorAction Stop | Out-Null
  $kind = 'symlink'
} catch {
  cmd /c mklink /J "`"$LinkPath`"" "`"$RepoRoot`"" | Out-Null
  if ($LASTEXITCODE -eq 0) {
    $kind = 'junction'
  } else {
    throw "Falha ao criar o link. Habilite o Developer Mode ou rode em terminal elevado. Erro: $($_.Exception.Message)"
  }
}

$target = (Get-Item -LiteralPath $LinkPath -Force).Target
Write-Host "   ✅ poc-swarm instalado ($kind) -> $target"
Write-Host ''
Write-Host 'Reinicie o Copilot CLI e confirme com /skills.'
Write-Host ('Saída das POCs (padrão): ' + (Join-Path $RepoRoot 'pocs'))
Write-Host 'Para mudar a saída, defina $env:POCSWARM_ROOT ou indique o destino no pedido.'

# ── Toolchain de validação/deploy: opcional ────────────────────────────────────
# O motor de agentes funciona sem nada disto. Validação e deploy precisam de
# az CLI + Bicep, Terraform (se usado), e linters (tflint/checkov/PSRule).
try {
  $PSNativeCommandUseErrorActionPreference = $false
  Write-Host ''
  Write-Host '— Toolchain de validação/deploy: checando —'

  function Test-Cmd($n) { [bool](Get-Command $n -ErrorAction SilentlyContinue) }
  function Test-PyMod($m) { if (-not (Test-Cmd python)) { return $false }; & python -c "import $m" 2>$null; return ($LASTEXITCODE -eq 0) }
  function Test-AzBicep { if (-not (Test-Cmd az)) { return $false }; try { return ((& az bicep version 2>$null | Out-String).Trim().Length -gt 0) } catch { return $false } }
  function Test-PSRuleAzure { try { return [bool](Get-Module -ListAvailable -Name 'PSRule.Rules.Azure' -ErrorAction SilentlyContinue) } catch { return $false } }

  $checks = [ordered]@{
    'az (Azure CLI)'         = (Test-Cmd az)
    'bicep (az bicep)'       = (Test-AzBicep)
    'terraform'              = (Test-Cmd terraform)
    'tflint'                 = (Test-Cmd tflint)
    'checkov'                = (Test-Cmd checkov)
    'PSRule.Rules.Azure'     = (Test-PSRuleAzure)
  }

  $missing = @()
  foreach ($k in $checks.Keys) {
    if ($checks[$k]) { Write-Host "   ✅ $k" } else { Write-Host "   ⚠️  $k (ausente)"; $missing += $k }
  }

  if ($missing.Count -eq 0) {
    Write-Host '   ✅ toolchain de validação/deploy completo.'
  } elseif ($WithTools) {
    Write-Host ''
    Write-Host '   Instalando toolchain (-WithTools)...'
    if (Test-Cmd winget) {
      try { & winget install --id Microsoft.AzureCLI      -e --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null } catch {}
      try { & winget install --id Hashicorp.Terraform     -e --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null } catch {}
      try { & winget install --id TerraformLinters.tflint -e --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null } catch {}
    } else {
      Write-Host '   ⚠️  winget ausente — instale az CLI, Terraform e tflint manualmente.'
    }
    if (Test-Cmd az)     { try { & az bicep install 2>&1 | Out-Null } catch {} }
    if (Test-Cmd python) { try { & python -m pip install --quiet checkov 2>&1 | Out-Null } catch {} }
    try { Install-Module -Name PSRule.Rules.Azure -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop } catch {}
    Write-Host '   ✅ Tentativa concluída. REINICIE o terminal para o PATH pegar as ferramentas novas.'
    Write-Host '   Lembre: faça `az login` antes de rodar uma POC com deploy.'
  } else {
    Write-Host ''
    Write-Host '   Para habilitar validação/deploy, instale o que falta:'
    Write-Host '     winget install Microsoft.AzureCLI   ;  az bicep install'
    Write-Host '     winget install Hashicorp.Terraform'
    Write-Host '     winget install TerraformLinters.tflint'
    Write-Host '     pip install checkov'
    Write-Host '     Install-Module PSRule.Rules.Azure -Scope CurrentUser'
    Write-Host '   Ou rode:  pwsh scripts\install.ps1 -WithTools'
    Write-Host '   Depois, REINICIE o terminal (PATH) e faça `az login`.'
  }
} catch {
  Write-Host "   ⚠️  Checagem do toolchain falhou: $($_.Exception.Message)"
}

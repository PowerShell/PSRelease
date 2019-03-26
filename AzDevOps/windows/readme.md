# Azure DevOps Pipeline Agent Install Script

This script installs the latest stable PowerShell Core and the [Azure DevOps Pipeline Agent][].

## Usage

See the instructions on [how to install the agent on windows][], for how to get the `AzDevOpsUrl`, `AzDevOpsPat`, and `AzDevOpsPool`.

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/PowerShell/PSRelease/master/AzDevOps/windows/install-agent.ps1 -outfile ./install-agent.ps1
./install-agent.ps1 -Url '$AzDevOpsUrl' -Pat '$AzDevOpsPat' -Pool '$AzDevOpsPool'
```

[how to install the agent on windows]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops
[Azure DevOps Pipeline Agent]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops

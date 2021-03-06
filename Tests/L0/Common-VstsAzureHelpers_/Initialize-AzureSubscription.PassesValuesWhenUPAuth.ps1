[CmdletBinding()]
param()

# Arrange.
. $PSScriptRoot/../../lib/Initialize-Test.ps1
Microsoft.PowerShell.Core\Import-Module Microsoft.PowerShell.Security
$module = Microsoft.PowerShell.Core\Import-Module $PSScriptRoot/../../../Tasks/AzurePowerShell/ps_modules/VstsAzureHelpers_ -PassThru
$endpoint = @{
    Auth = @{
        Parameters = @{
            UserName = 'Some user name'
            Password = 'Some password'
        }
        Scheme = 'UserNamePassword'
    }
    Data = @{
        SubscriptionId = 'Some subscription ID'
        SubscriptionName = 'Some subscription name'
    }
}
$variableSets = @(
    # Azure:
    @{
        Azure = $true
        AzureRM = $false
        StorageAccount = $null
    }
    @{
        Azure = $true
        AzureRM = $false
        StorageAccount = 'Some storage account'
    }
    # Azure and AzureRM:
    @{
        Azure = $true
        AzureRM = $true
        StorageAccount = $null
    }
    @{
        Azure = $true
        AzureRM = $true
        StorageAccount = 'Some storage account'
    }
    # AzureRM:
    @{
        Azure = $false
        AzureRM = $true
        StorageAccount = $null
    }
)
foreach ($variableSet in $variableSets) {
    Write-Verbose ('-' * 80)
    Unregister-Mock Add-AzureAccount
    Unregister-Mock Add-AzureRMAccount
    Unregister-Mock Set-CurrentAzureSubscription
    Unregister-Mock Set-CurrentAzureRMSubscription
    Register-Mock Add-AzureAccount { 'some output' }
    Register-Mock Add-AzureRMAccount { 'some output' }
    Register-Mock Set-CurrentAzureSubscription
    Register-Mock Set-CurrentAzureRMSubscription
    & $module {
        $script:azureModule = $null
        $script:azureRMProfileModule = $null
    }
    if ($variableSet.Azure) {
        & $module { $script:azureModule = @{ Version = [version]'1.0' } }
    }

    if ($variableSet.AzureRM) {
        & $module { $script:azureRMProfileModule = @{ Version = [version]'1.2.3.4' } }
    }

    # Act.
    $result = & $module Initialize-AzureSubscription -Endpoint $endpoint -StorageAccount $variableSet.StorageAccount

    # Assert.
    Assert-AreEqual $null $result
    if ($variableSet.Azure) {
        Assert-WasCalled Add-AzureAccount -ArgumentsEvaluator {
            $args.Length -eq 2 -and
            $args[0] -eq '-Credential' -and
            $args[1] -is [pscredential] -and
            $args[1].UserName -eq 'Some user name' -and
            $args[1].GetNetworkCredential().Password -eq 'Some password'
        }
        Assert-WasCalled Set-CurrentAzureSubscription -- -SubscriptionId $endpoint.Data.SubscriptionId -StorageAccount $variableSet.StorageAccount
    }

    if ($variableSet.AzureRM) {
        Assert-WasCalled Add-AzureRMAccount -ArgumentsEvaluator {
            $args.Length -eq 2 -and
            $args[0] -eq '-Credential' -and
            $args[1] -is [pscredential] -and
            $args[1].UserName -eq 'Some user name' -and
            $args[1].GetNetworkCredential().Password -eq 'Some password'
        }
        Assert-WasCalled Set-CurrentAzureRMSubscription -- -SubscriptionId $endpoint.Data.SubscriptionId
    }
}

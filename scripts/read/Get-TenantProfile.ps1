<#
.SYNOPSIS
    Reads tenant licensing and SharePoint tenant settings.

.DESCRIPTION
    Populates the facts that AGENTS.md gates recommendations on, above all
    the license tier. Until that is known, Oracle365 restricts advice to
    features available at every tier.

    Read-only. Nothing here changes tenant state.

    Requires delegated authentication as an administrator. Licensing comes
    from Microsoft Graph /subscribedSkus, whose least privileged permission
    is LicenseAssignment.Read.All; Global Reader covers it delegated.
    Tenant settings come from Get-PnPTenant, which needs SharePoint
    Administrator. App-only with Sites.Selected cannot do either.

.PARAMETER AdminUrl
    SharePoint admin URL, for example https://contoso-admin.sharepoint.com

.PARAMETER Mode
    Delegated or AppOnly. Defaults to Delegated, which is the only mode
    that works for this script under a Sites.Selected app registration.

.EXAMPLE
    ./Get-TenantProfile.ps1 -AdminUrl https://contoso-admin.sharepoint.com

.NOTES
    Cmdlet names and permissions verified against PnP PowerShell and
    Microsoft Graph documentation, 2026-09-21. Not yet run against a live
    tenant.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AdminUrl,

    [ValidateSet('Delegated', 'AppOnly')]
    [string]$Mode = 'Delegated'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..' 'lib' 'Oracle365.Common.ps1')

Connect-Oracle365 -Url $AdminUrl -Mode $Mode

# --- Licensing -------------------------------------------------------------

Write-Host 'Reading subscribed SKUs...'

$skus = $null
try {
    $response = Invoke-PnPGraphMethod -Url 'v1.0/subscribedSkus' -Method Get
    $skus = @($response.value | ForEach-Object {
        [ordered]@{
            sku_part_number = $_.skuPartNumber
            sku_id          = $_.skuId
            enabled         = $_.prepaidUnits.enabled
            consumed        = $_.consumedUnits
            service_plans   = @($_.servicePlans |
                Where-Object { $_.provisioningStatus -eq 'Success' } |
                ForEach-Object { $_.servicePlanName } | Sort-Object)
        }
    })
}
catch {
    Write-Warning "Could not read /subscribedSkus: $($_.Exception.Message)"
    Write-Warning ''
    Write-Warning 'This needs LicenseAssignment.Read.All as the least privileged'
    Write-Warning 'permission, or Directory.Read.All or Organization.Read.All.'
    Write-Warning 'Delegated, Global Reader covers it. An app registration holding'
    Write-Warning 'only Sites.Selected does not, and cannot be made to by granting'
    Write-Warning 'site permissions.'
    Write-Warning ''
    Write-Warning 'Record license_tier in profile.md by hand from the Microsoft 365'
    Write-Warning 'admin center under Billing, Your products, if you do not want to'
    Write-Warning 'add the permission.'
}

# --- Feature availability --------------------------------------------------
#
# Service plan names are the reliable signal. A SKU name tells you what was
# bought; a service plan tells you what is actually provisioned. These are
# the plans behind the features AGENTS.md gates on.

$featurePlans = [ordered]@{
    'Sensitivity labels'        = @('MIP_S_CLP1', 'MIP_S_CLP2', 'RMS_S_PREMIUM', 'RMS_S_ENTERPRISE')
    'Purview retention'         = @('RECORDS_MANAGEMENT', 'INFO_GOVERNANCE', 'EXCHANGE_S_ENTERPRISE')
    'Data Loss Prevention'      = @('MIP_S_CLP1', 'PURVIEW_DISCOVERY', 'INFORMATION_BARRIERS')
    'Conditional Access'        = @('AAD_PREMIUM', 'AAD_PREMIUM_P2')
    'Access reviews'            = @('AAD_PREMIUM_P2')
    'Premium Power connectors'  = @('POWERAPPS_PER_USER', 'FLOW_PER_USER', 'POWERAPPS_PER_APP')
    'Dataverse'                 = @('DYN365_CDS_VIRAL', 'CDS_O365_P2', 'CDS_O365_P3')
}

$features = [ordered]@{}
if ($skus) {
    $provisioned = $skus | ForEach-Object { $_.service_plans } | Select-Object -Unique
    foreach ($feature in $featurePlans.Keys) {
        $hits = @($featurePlans[$feature] | Where-Object { $provisioned -contains $_ })
        $features[$feature] = if ($hits.Count -gt 0) {
            "likely available (via $($hits -join ', '))"
        } else {
            'no matching service plan found'
        }
    }
}

# --- SharePoint tenant settings --------------------------------------------

Write-Host 'Reading SharePoint tenant settings...'

$tenantSettings = $null
try {
    $t = Get-PnPTenant
    $tenantSettings = [ordered]@{
        sharing_capability               = [string]$t.SharingCapability
        default_sharing_link_type        = [string]$t.DefaultSharingLinkType
        default_link_permission          = [string]$t.DefaultLinkPermission
        require_anonymous_links_expire   = [string]$t.RequireAnonymousLinksExpireInDays
        prevent_external_users_resharing = [string]$t.PreventExternalUsersFromResharing
        site_creation_mode               = [string]$t.SiteCreationMode
        storage_quota                    = [string]$t.StorageQuota
        storage_quota_allocated          = [string]$t.StorageQuotaAllocated
    }
}
catch {
    Write-Warning "Could not read tenant settings: $($_.Exception.Message)"
    Write-Warning 'Get-PnPTenant requires SharePoint Administrator.'
}

# --- Report ----------------------------------------------------------------

Write-Host ''
Write-Host 'Licensing'
Write-Host '---------'
if ($skus) {
    $skus | ForEach-Object {
        Write-Host ("  {0,-32} {1}/{2} assigned" -f $_.sku_part_number, $_.consumed, $_.enabled)
    }
    Write-Host ''
    Write-Host 'Feature availability, inferred from provisioned service plans.'
    Write-Host 'Treat as a prompt to verify, not as an authority. Microsoft'
    Write-Host 'changes which plans carry which features.'
    Write-Host ''
    foreach ($k in $features.Keys) {
        Write-Host ("  {0,-26} {1}" -f $k, $features[$k])
    }
}
else {
    Write-Host '  Not read. See the warning above.'
}

Write-Host ''
Write-Host 'SharePoint tenant settings'
Write-Host '--------------------------'
if ($tenantSettings) {
    foreach ($k in $tenantSettings.Keys) {
        Write-Host ("  {0,-34} {1}" -f $k, $tenantSettings[$k])
    }
}
else {
    Write-Host '  Not read. See the warning above.'
}

$snapshot = Write-Oracle365Snapshot `
    -Name 'tenant-profile' `
    -Scope 'Tenant licensing and SharePoint tenant settings' `
    -Mode $Mode `
    -Data ([ordered]@{
        subscribed_skus      = $skus
        feature_availability = $features
        tenant_settings      = $tenantSettings
    })

Write-Host ''
Write-Host "Snapshot: $snapshot"
Write-Host ''
Write-Host 'Record license_tier in profile.md yourself. This script reports what'
Write-Host 'is provisioned; naming the tier is a judgement call, and profile.md is'
Write-Host 'yours to maintain.'

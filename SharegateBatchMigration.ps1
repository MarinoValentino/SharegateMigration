$srcSiteUrl="https://<Source_URL>"
$dstSiteUrl = "https://<Tenant>.sharepoint.com/sites/<SiteName>"

$ListsToTransform = @(
"Documents",
"Quick links",
"Team Documents",
"Public Pictures"
)

$Testrun = $false

#region Migration Users
    # ($Credential=Get-Credential).Password | ConvertFrom-SecureString
    $srcUsername = 'Domain\User'
    $srcSecureString = "0100....949c36"
    $srcPassword = ConvertTo-SecureString $srcSecureString
    $srcCred = New-Object System.Management.Automation.PSCredential -ArgumentList $srcUsername, $srcPassword
    $dstUsername = 'Cloud_User@<Tenant>.onmicrosoft.com'
    $dstSecureString = "0100....949c37"
    $dstPassword = ConvertTo-SecureString $dstSecureString
    $dstCred = New-Object System.Management.Automation.PSCredential -ArgumentList $dstUsername, $dstPassword
#endregion

#region Sharegate and PnP Connections
    $srcSite = Connect-Site -Url $srcSiteUrl -UserName $srcUsername -Password $srcPassword
    $dstSite = Connect-Site -Url $dstSiteUrl -UserName $dstUsername -Password $dstPassword
    $srcPnP=Connect-PnPOnline -Url $srcSiteUrl -CurrentCredentials -ReturnConnection
    $dstPnP=Connect-PnPOnline -Url $dstSiteUrl -Credentials $dstCred -ReturnConnection
#endregion

#region Copy Settings and mappings
    $srcOwnersGrp = (Get-PnPGroup -Connection $srcPnP -AssociatedOwnerGroup).Title
    $srcMembersGrp = (Get-PnPGroup -Connection $srcPnP -AssociatedMemberGroup).Title
    $srcVisitorsGrp = (Get-PnPGroup -Connection $srcPnP -AssociatedVisitorGroup).Title
    $dstOwnersGrp = (Get-PnPGroup -Connection $dstPnP -AssociatedOwnerGroup).Title
    $dstMembersGrp = (Get-PnPGroup -Connection $dstPnP -AssociatedMemberGroup).Title
    $dstVisitorsGrp = (Get-PnPGroup -Connection $dstPnP -AssociatedVisitorGroup).Title
    $mappingSettings = New-MappingSettings
    $mappingSettings = Set-UserAndGroupMapping -MappingSettings $mappingSettings -UnresolvedUserOrGroup -Destination $dstUsername
    $mappingSettings = Set-UserAndGroupMapping -MappingSettings $mappingSettings -Source $srcUsername -Destination $dstUsername
    $mappingSettings = Set-UserAndGroupMapping -MappingSettings $mappingSettings -Source $srcOwnersGrp -Destination $dstOwnersGrp
    $mappingSettings = Set-UserAndGroupMapping -MappingSettings $mappingSettings -Source $srcMembersGrp -Destination $dstMembersGrp
    $mappingSettings = Set-UserAndGroupMapping -MappingSettings $mappingSettings -Source $srcVisitorsGrp -Destination $dstVisitorsGrp
    $mappingSettings = Set-ContentTypeMapping -MappingSettings $mappingSettings -Source <CT_To_Replace> -Destination Document
    $copySettings = New-CopySettings -OnContentItemExists IncrementalUpdate -OnSiteObjectExists Merge -OnWarning Continue -OnError Skip -VersionOrModerationComment 'SPO Migration'
    $VersionLimit = 2
#endregion

#region Copy
function Incremental-ListCopy ([String]$srcListName)
{
    $StartDate=Get-Date; $Start = "Start`t" + $srcListName + " " + $StartDate
    Write-Host $Start -ForegroundColor Green 
    $srcList = Get-List -Name $srcListName -Site $srcSite
    If ($testrun) { $result = Copy-List -List $srcList -DestinationSite $dstSite -VersionLimit $VersionLimit -CopySettings $copySettings -MappingSettings $mappingSettings -TaskName "$dstSite :: $srcListName" -NoCustomizedListForms -WhatIf }
    else { $result = Copy-List -List $srcList -DestinationSite $dstSite -VersionLimit $VersionLimit -CopySettings $copySettings -MappingSettings $mappingSettings -TaskName "$dstSite :: $srcListName" -NoCustomizedListForms}
    $EndDate=Get-Date; $DurationTime = New-TimeSpan -Start $StartDate -End $EndDate; $End = "End`t" + $EndDate + " Duration " + $DurationTime
    Write-Host $End -ForegroundColor Green
}
#endregion

# Copy Lists
foreach ($ListToTransform in $ListsToTransform)
{
    Incremental-ListCopy $ListToTransform
}

# Copy Groups
Write-Host "Start Copy Owners-/Members-/Visitors-Group" -ForegroundColor Green
If ($testrun) 
{
    Copy-Group -SourceSite $srcSite -DestinationSite $dstSite -Name $srcOwnersGrp -CopySettings $copySettings -MappingSettings $mappingSettings -TaskName "$dstSite :: $srcOwnersGrp" -WhatIf
    Copy-Group -SourceSite $srcSite -DestinationSite $dstSite -Name $srcMembersGrp -CopySettings $copySettings -MappingSettings $mappingSettings -TaskName "$dstSite :: $srcMembersGrp" -WhatIf
    Copy-Group -SourceSite $srcSite -DestinationSite $dstSite -Name $srcVisitorsGrp -CopySettings $copySettings -MappingSettings $mappingSettings -TaskName "$dstSite :: $srcVisitorsGrp" -WhatIf
}
else
{
    Copy-Group -SourceSite $srcSite -DestinationSite $dstSite -Name $srcOwnersGrp -CopySettings $copySettings -MappingSettings $mappingSettings -TaskName "$dstSite :: $srcOwnersGrp"
    Copy-Group -SourceSite $srcSite -DestinationSite $dstSite -Name $srcMembersGrp -CopySettings $copySettings -MappingSettings $mappingSettings -TaskName "$dstSite :: $srcMembersGrp"
    Copy-Group -SourceSite $srcSite -DestinationSite $dstSite -Name $srcVisitorsGrp -CopySettings $copySettings -MappingSettings $mappingSettings -TaskName "$dstSite :: $srcVisitorsGrp"
}
#######################################
### Script:  FlatADGroups.ps1       ###
### By:      C.Schulze - aikux.com  ###
### Version: 1.0                    ###
### Date:    2015-06-15             ###
#######################################

### variables (if $Delete is set to 0 no groups will be deleted, if it is set to 1 the groups will be deleted) ###
Import-Module ActiveDirectory
$ErrorActionPreference = "SilentlyContinue"
$Groups = Get-Content -Path "D:\Work\groups2flat.txt"
$excGroups = Get-Content -Path "D:\Work\exclude_groups.txt"
$totalGroups = $Groups.Count
$Counter = 1
$Delete = 0
$FlatInfos = @()
$DelInfos = @()

### function to determine group hierarchy recursive ###
function Get-ADGroupHierarchy {
    param (
        $searchGroup
    )

    $Members = Get-ADGroupMember -Identity $searchGroup | Sort-Object objectClass -Descending

    foreach ($Member in $Members) {
        if ($Member.objectClass -eq "user") {
            $Userinfo = $Member.SamAccountName
        }
        if ($Member.objectClass -eq "group") {
            $Groupinfo = $Member.SamAccountName
        }
        $Hierarchy = [Ordered]@{GroupName = $searchGroup; SubGroupName = $Groupinfo; UserName = $Userinfo}
        $Hierarchy | ForEach-Object {New-Object  PSObject -Property $_}
        Clear-Variable Groupinfo, Userinfo -ErrorAction SilentlyContinue        
        if ($Member.objectClass -eq "group") {
            if ($excGroups -notcontains $Member.Name) {
                Get-ADGroupHierarchy -searchGroup $Member.SamAccountName
            }
        }
    }
}

### flat groups, create logfile, delete if necessary ###
foreach ($Group in $Groups) {
    if ($Counter -eq 1) {
        Write-Host Starting FlatADGroups ... $totalGroups Groups to flat
        Write-Host ................................................................................
    }
    Write-Host "$Group ($Counter of $totalGroups) ... Processing"
    $Flat = Get-ADGroupHierarchy $Group
    foreach ($Username in $Flat.UserName) {
        if ($Username) {
            $SubGroup = $Flat | Where-Object UserName -EQ $Username | Select-Object GroupName
            if ($SubGroup.GroupName -ne $Group) {
                $FlatInfos += [Ordered]@{User = $Username; fromGroup = $SubGroup.GroupName -join ","; inGroup = $Group}
                Add-ADGroupMember -Identity $Group -Members $Username
            }
        }
        Clear-Variable SubGroup, Username
    }
    if ($FlatInfos) {
        $FlatInfos | ForEach-Object {New-Object psobject -Property $_} | Export-Csv D:\Work\Flat_$Group'_'$(get-date -f yyyyMMdd-hhmm).csv -Delimiter ";" –NoTypeInformation -Encoding UTF8
    }
    if ($Delete -eq 1) {
        $delGroups = Get-ADGroupMember -Identity $Group | Where-Object objectClass -EQ "group"
        foreach ($delGroup in $delGroups.Name) {
            if ($excGroups -notcontains $delGroup) {
                $DelInfos += [Ordered]@{Group = $delGroup; deletetfrom = $Group}
                Remove-ADGroupMember -Identity $Group -Members $delGroup -Confirm:$false
            }
        }
        if ($DelInfos) {
            $DelInfos | ForEach-Object {New-Object psobject -Property $_} | Export-Csv D:\Work\Delete_$Group'_'$(get-date -f yyyyMMdd-hhmm).csv -Delimiter ";" –NoTypeInformation -Encoding UTF8
        }
    }
    $FlatInfos = @()
    $DelInfos = @()
    Write-Host "$Group ($Counter of $totalGroups) ... Done"
    Write-Host ................................................................................
    if ($Counter -eq $totalGroups) {
        Write-Host Finished FlatADGroups ... Processed $totalGroups Groups
    }
    $Counter += 1
    Clear-Variable Group
}

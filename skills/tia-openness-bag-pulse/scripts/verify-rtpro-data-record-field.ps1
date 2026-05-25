param(
  [string]$SqlServer = ".\WINCC",
  [string]$DatabaseLike = "CC_HMI_HWS3%",
  [string]$ArchiveName = "DATA1",
  [string]$FieldName = "环境检测",
  [string]$ProcessTag = "PV_HJ环境氧浓度检测",
  [string]$DisplayTagPrefix = "data_环境检测",
  [string]$ScreenName = "D2_数据记录",
  [string]$OutputRoot = ".\tia_rtpro_learning"
)

$ErrorActionPreference = "Stop"

function Invoke-SqlQuery {
  param(
    [string]$Database,
    [string]$Query
  )

  $connectionString = "Server=$SqlServer;Database=$Database;Integrated Security=True;TrustServerCertificate=True"
  $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
  $command = $connection.CreateCommand()
  $command.CommandTimeout = 30
  $command.CommandText = $Query
  $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
  $table = New-Object System.Data.DataTable
  try {
    [void]$adapter.Fill($table)
  }
  finally {
    $connection.Dispose()
  }
  return ,$table
}

function Format-DataTable {
  param([System.Data.DataTable]$Table)
  if ($null -eq $Table -or $Table.Rows.Count -eq 0) {
    return @("<no rows>")
  }
  return ($Table | Format-Table -AutoSize | Out-String -Width 260).TrimEnd()
}

$logDir = Join-Path $OutputRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir "verify_rtpro_data_record_field.txt"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("VerifyTime=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("SqlServer=$SqlServer")
$lines.Add("DatabaseLike=$DatabaseLike")
$lines.Add("ArchiveName=$ArchiveName")
$lines.Add("FieldName=$FieldName")
$lines.Add("ProcessTag=$ProcessTag")
$lines.Add("DisplayTagPrefix=$DisplayTagPrefix")
$lines.Add("ScreenName=$ScreenName")
$lines.Add("")

$dbQuery = @"
select name, state_desc, create_date
from sys.databases
where name like N'$($DatabaseLike.Replace("'", "''"))'
  and state_desc = 'ONLINE'
order by create_date desc, name;
"@
$dbs = Invoke-SqlQuery -Database "master" -Query $dbQuery
$lines.Add("== Online WinCC Databases ==")
$lines.Add((Format-DataTable $dbs))
$lines.Add("")

foreach ($dbRow in $dbs.Rows) {
  $dbName = [string]$dbRow["name"]
  if ($dbName.EndsWith("LT")) {
    continue
  }

  $hasPdeQuery = "select object_id(N'[PDE#TAGs]') as TagsObjectId, object_id(N'[PDE#ARCHIVES]') as ArchivesObjectId;"
  $hasPde = Invoke-SqlQuery -Database $dbName -Query $hasPdeQuery
  if ([DBNull]::Value.Equals($hasPde.Rows[0]["TagsObjectId"])) {
    continue
  }

  $escapedArchive = $ArchiveName.Replace("'", "''")
  $escapedField = $FieldName.Replace("'", "''")
  $escapedProcessTag = $ProcessTag.Replace("'", "''")
  $archiveQuery = @"
select ARCHIVNAME, ARCHIVTYPE, RECORDTYPE, TIMEMODIFY, RecordId
from [PDE#ARCHIVES]
where ARCHIVNAME = N'$escapedArchive';
"@
  $tagQuery = @"
select TLGTAGID, RecordId, ARCNAME, VARNAME, PROCVARNAME, SCANTIME, ARCTIME, VARSTARTEVENT, TIMEMODIFY
from [PDE#TAGs]
where ARCNAME = N'$escapedArchive'
order by TLGTAGID;
"@
  $fieldQuery = @"
select TLGTAGID, RecordId, ARCNAME, VARNAME, PROCVARNAME, SCANTIME, ARCTIME, VARSTARTEVENT, TIMEMODIFY
from [PDE#TAGs]
where ARCNAME = N'$escapedArchive'
  and (VARNAME = N'$escapedField' or PROCVARNAME = N'$escapedProcessTag');
"@

  $lines.Add("== Runtime Archive DB: $dbName ==")
  $lines.Add("-- Archive --")
  $lines.Add((Format-DataTable (Invoke-SqlQuery -Database $dbName -Query $archiveQuery)))
  $lines.Add("-- All DATA1 Tags --")
  $lines.Add((Format-DataTable (Invoke-SqlQuery -Database $dbName -Query $tagQuery)))
  $fieldResult = Invoke-SqlQuery -Database $dbName -Query $fieldQuery
  $lines.Add("-- Target Field --")
  $lines.Add((Format-DataTable $fieldResult))
  $lines.Add("TargetFieldPresent=$($fieldResult.Rows.Count -gt 0)")
  $lines.Add("")

  $ltName = "${dbName}LT"
  $ltExists = $dbs.Select("name = '$($ltName.Replace("'", "''"))'").Count -gt 0
  if (-not $ltExists) {
    $lines.Add("LTDatabaseMissing=$ltName")
    $lines.Add("")
    continue
  }

  $escapedDisplay = $DisplayTagPrefix.Replace("'", "''")
  $escapedScreen = $ScreenName.Replace("'", "''")
  $ltTagQuery = @"
select TLGTAGID, CLASSICID, CLASSICFOREIGNID, VALIDATIONFLAGINRT
from HmiDataLoggingTag
order by TLGTAGID;
"@
  $ltTargetQuery = @"
select TLGTAGID, CLASSICID, CLASSICFOREIGNID, VALIDATIONFLAGINRT
from HmiDataLoggingTag
where CLASSICID = N'$escapedField'
   or TLGTAGID in (select TLGTAGID from [$dbName].[dbo].[PDE#TAGs] where ARCNAME = N'$escapedArchive' and (VARNAME = N'$escapedField' or PROCVARNAME = N'$escapedProcessTag'));
"@
  $displayQuery = @"
select TagId, TagName, HmiDataTypeName, ESAddress, PLCNAME
from HmiTag
where TagName like N'$escapedDisplay%'
   or TagName = N'$escapedProcessTag'
order by TagName;
"@
  $screenQuery = @"
select ScreenId, ScreenName, UnvalidatedScreenName
from HmiScreen
where ScreenName = N'$escapedScreen' or UnvalidatedScreenName = N'$escapedScreen';
"@
  $scriptQuery = @"
select FlexId, Name, UsageCount, IsDeleted
from HmiVBScript
where Name like N'%DATA%' or Name like N'%CSV%' or Name like N'%Audit%'
order by Name;
"@

  $lines.Add("== LT Metadata DB: $ltName ==")
  $allLtTags = Invoke-SqlQuery -Database $ltName -Query $ltTagQuery
  $targetLtTags = Invoke-SqlQuery -Database $ltName -Query $ltTargetQuery
  $displayTags = Invoke-SqlQuery -Database $ltName -Query $displayQuery
  $screenRows = Invoke-SqlQuery -Database $ltName -Query $screenQuery
  $scriptRows = Invoke-SqlQuery -Database $ltName -Query $scriptQuery

  $lines.Add("-- Data Logging Tag Mapping --")
  $lines.Add((Format-DataTable $allLtTags))
  $lines.Add("-- Target Field Mapping --")
  $lines.Add((Format-DataTable $targetLtTags))
  $lines.Add("TargetMappingPresent=$($targetLtTags.Rows.Count -gt 0)")
  $lines.Add("-- Display Tags --")
  $lines.Add((Format-DataTable $displayTags))
  $lines.Add("DisplayTagCount=$($displayTags.Rows.Count)")
  $lines.Add("-- Screen --")
  $lines.Add((Format-DataTable $screenRows))
  $lines.Add("-- VB Script Modules --")
  $lines.Add((Format-DataTable $scriptRows))
  $lines.Add("")
}

[IO.File]::WriteAllLines($logPath, $lines, [Text.Encoding]::UTF8)
Write-Output $logPath



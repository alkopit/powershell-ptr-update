#Кудаков Александр 10.01.2019#
##############################
# Скрипт проверяет и актуализирует PTR записи
# Если зоны и записи отсутствует то создает их
# Если зоны имеются то актуализирует записи в случае необходимости

Clear-Host 
Write-Host ''
$ThreeOctets = New-object System.Collections.ArrayList 
$UniqueOctets = New-Object System.Collections.ArrayList 
$PTRZones = New-Object System.Collections.ArrayList #лист PTR зон
$ZoneStatusBad = New-Object System.Collections.ArrayList #лист отсутствующих зон
$TTL = "3:00:00:00" #TTL для записей PTR
$Zone = 'udevelopment.local' #прямая зона

while ($Zone -eq ''){
            Write-Host 'Не задана прямая зона для просмотра А записей (параметр $Zone = "")'
            Write-Host 'Укажите параметр в файле скрипта или введите зону вручную ниже'
            $Zone = Read-Host 'Прямая зона'
        }

Write-Host ''
Write-Host "Начало..." -ForegroundColor Green 
Write-Host ''
#проверяем зону на существование
if ($Zone) { 
    $DC = (Get-ADDomainController -filter {Domain -eq "$env:USERDNSDOMAIN"}).Name[0] 
    $Existence = (Get-DnsServerZone -Name "$Zone" -ComputerName $DC -ErrorAction SilentlyContinue).ZoneName

if ($Existence -eq $Null) { 
    Write-Host "Такой зоны не существует в вашем Active Directory" -ForegroundColor Red 
    Start-Sleep -s 5
    Break 
}

#получаем список А записей из прямой зоны
$ARecords = Get-DnsServerResourceRecord -ComputerName $DC -RRType A -ZoneName "$Zone" | 
    ? {$_.HostName -notlike "*DNSZones*" -and $_.HostName -notlike "*@*"} | 
    select HostName,@{Name="IPAddress";Expression={$_.RecordData.IPv4Address}} 

#получаем из подсети из IP адресов А записей
foreach ($I in $ARecords) { 
    [string]$LastOctet = ($I.IPaddress.ipaddresstostring).Split(".")[3] 
    [string]$OctetOne = $I.IPAddress.ipaddresstostring.split(".")[0] 
    [string]$OctetTwo = $I.IPAddress.ipaddresstostring.split(".")[1] 
    [string]$OctetThree = $I.IPAddress.ipaddresstostring.split(".")[2]
    [string]$Subnet = "$($OctetOne)."+"$($OctetTwo)."+"$($OctetThree)" 
    $ThreeOctets += $Subnet 
    $UniqueOctets = ($ThreeOctets | select -Unique) 
} 

#формируем имена обратных зон
foreach ($Member in $UniqueOctets) { 
    [string]$OctetOne = $Member.split(".")[0] 
    [string]$OctetTwo = $Member.split(".")[1] 
    [string]$OctetThree = $Member.split(".")[2] 
    [string]$Reversed = "$($OctetThree)."+"$($OctetTwo)."+"$($OctetOne).in-addr.arpa" 
    $PTRZones += $Reversed 
} 

#проверяем существование PTR зон, при ошибке продолжаем без оповещения
foreach ($PTRZone in $PTRZones) { 
$FoundZone = (Get-DnsServerZone -ComputerName $DC -Name $PTRZone -ErrorAction SilentlyContinue) 

    if ($FoundZone -eq $null) { 
        [string]$WithoutArpa = $PTRZone.TrimEnd(".in-addr.arpa") 
        [string]$OctetOne = $WithoutArpa.Split(".")[2] 
        [string]$OctetTwo = $WithoutArpa.Split(".")[1] 
        [string]$OctetThree = $WithoutArpa.Split(".")[0] 
        [string]$ZoneToCreate = "$OctetOne."+"$OctetTwo."+"$OctetThree."+"0"
        Write-Host "Зона $PTRZone не найдена" -ForegroundColor Red 

        $ZoneCreation = ''
        #спрашиваем пользователя о действии в случае отсутствия обратной зоны
        while ($ZoneCreation -ne 'n' -and $ZoneCreation -ne 'y'){
            $ZoneCreation = Read-Host 'Создать зону? (y - Да / n - Нет)'
        }
        if ($ZoneCreation -eq 'n') {
            Write-Host 'Вы выбрали ' $ZoneCreation ' - зона НЕ будет создана'
            $ZoneStatusBad += $PTRZone
            Write-Host ''
        }
        elseif ($ZoneCreation -eq 'y') {
            Write-Host 'Вы выбрали ' $ZoneCreation ' - зона будет создана'
            Add-DnsServerPrimaryZone -ComputerName $DC -NetworkId "$ZoneToCreate/24" -ReplicationScope Forest 
            Write-Host "Создана обратная зона $ZoneToCreate с маской по умолчанию/24" -ForegroundColor Green
            Write-Host ''
        }
    } 
    else { 
        Write-Host "Зона $PTRZone найдена" -ForegroundColor Cyan 
    } 
}

Write-Host ''

#добавляем PTR запись
foreach ($A in $ARecords) { 
    [string]$OctetOne = $A.IPAddress.IPAddressToString.Split(".")[0] 
    [string]$OctetTwo = $A.IPAddress.IPAddressToString.Split(".")[1] 
    [string]$OctetThree = $A.IPAddress.IPAddressToString.Split(".")[2] 
    [string]$OctetFour = $A.IPAddress.IPAddressToString.Split(".")[3] 
    [string]$TargetZone = "$OctetThree."+"$OctetTwo."+"$OctetOne"+".in-addr.arpa"
    if ($TargetZone -eq $ZoneStatusBad) {
        Write-Host "Добавление PTR записи для $($A.HostName) - $($A.IPAddress.IPAddressToString) пропущено" -ForegroundColor DarkGray
        continue
    }
    [string]$HostName = "$($A.HostName)."+"$Zone"

    # эталон
    #$FindRecord = (Get-DnsServerResourceRecord -ComputerName $DC -RRType PTR -ZoneName $TargetZone |
             #? {$_.RecordData.PtrDomainName -eq "$Hostname." -and $_.HostName -eq "$OctetFour"})
    try {
        $FindRecord = (Get-DnsServerResourceRecord -ComputerName $DC -RRType PTR -ZoneName $TargetZone |
            ? {$_.RecordData.PtrDomainName -eq "$Hostname."} | Select -ExpandProperty 'HostName')
        }
    catch {
        Write-Host 'PTR записи не существует' -ForegroundColor Red
    }
    finally {
        
    }
    try {
        $NodePTRRecord = Get-DnsServerResourceRecord -ComputerName $DC -ZoneName $TargetZone -Name "$FindRecord" -RRType PTR
    }
    catch {
        Write-Host 'PTR записи для ' $A.HostName ' не существует' -ForegroundColor Red
    }
    finally{

    }
         
    if ($FindRecord -eq $null) { 
    #Add-DnsServerResourceRecordPtr -ComputerName $DC -ZoneName $TargetZone -Name $OctetFour -PtrDomainName $HostName -TimeToLive $TTL -AllowUpdateAny 
        Add-DnsServerResourceRecordPtr -ComputerName $DC -ZoneName $TargetZone -Name $OctetFour -PtrDomainName $HostName -TimeToLive $TTL -AllowUpdateAny
        Write-Host "Добавлена PTR запись для $($A.HostName) - $($A.IPAddress.IPAddressToString)" -ForegroundColor Green 
    } 
    elseif ($FindRecord -ne $OctetFour){
        Remove-DnsServerResourceRecord -ComputerName $DC -ZoneName $TargetZone -InputObject $NodePTRRecord -Force
        Add-DnsServerResourceRecordPtr -ComputerName $DC -ZoneName $TargetZone -Name $OctetFour -PtrDomainName $HostName -TimeToLive $TTL -AllowUpdateAny
        Write-Host "Изменена PTR запись для $($A.HostName) - $($A.IPAddress.IPAddressToString)" -ForegroundColor Green
    }
    else { 
        Write-Host "Найдена PTR запись для $($A.Hostname) - $($A.IPAddress.IPAddressToString)" -ForegroundColor Cyan 
    } 
} 
} 

 
Write-Host ''
Write-Host "Готово" -ForegroundColor Red 
Start-Sleep -s 5


#Проверка записей
#foreach ($Z in $PTRZones) {Get-DnsServerResourceRecord -ZoneName $Z -ComputerName $DC}
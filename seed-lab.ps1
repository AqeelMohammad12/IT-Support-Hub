# seed-lab.ps1
# Seeds an ISOLATED lab domain (lab.local) with OUs, users, and a few deliberate
# misconfigurations so a scanner has something to find.
# LAB USE ONLY. Do not run this in any real environment.

Import-Module ActiveDirectory

$domainDN = (Get-ADDomain).DistinguishedName
$dnsRoot  = (Get-ADDomain).DNSRoot

# Lab-only password. Meets complexity rules.
$labPassword = ConvertTo-SecureString "LabPass#2026x" -AsPlainText -Force

# --- Organizational units ---
foreach ($ou in "Employees","IT","ServiceAccounts","Legacy") {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $domainDN -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $false
        Write-Host "Created OU: $ou"
    }
}

function New-LabUser {
    param([string]$Name, [string]$Sam, [string]$Ou, [string]$Description = "")
    if (Get-ADUser -Filter "SamAccountName -eq '$Sam'" -ErrorAction SilentlyContinue) {
        Write-Host "Exists: $Sam"
        return
    }
    New-ADUser -Name $Name -SamAccountName $Sam -UserPrincipalName "$Sam@$dnsRoot" `
        -Path "OU=$Ou,$domainDN" -AccountPassword $labPassword -Enabled $true `
        -Description $Description
    Write-Host "Created user: $Sam"
}

# --- Normal employees ---
$employees = @(
    @("Alice Rivera","arivera"), @("Ben Nguyen","bnguyen"), @("Carla Mendes","cmendes"),
    @("Dev Patel","dpatel"),     @("Elena Ortiz","eortiz"), @("Frank Lee","flee"),
    @("Grace Kim","gkim"),       @("Hector Diaz","hdiaz")
)
foreach ($e in $employees) { New-LabUser -Name $e[0] -Sam $e[1] -Ou "Employees" }

# --- IT staff ---
New-LabUser -Name "Ivan Brooks" -Sam "ibrooks" -Ou "IT"
New-LabUser -Name "Jana Cole"   -Sam "jcole"   -Ou "IT"

# --- Service and legacy accounts ---
New-LabUser -Name "svc-backup" -Sam "svc-backup" -Ou "ServiceAccounts" -Description "Backup service account"
New-LabUser -Name "tempuser"   -Sam "tempuser"   -Ou "Legacy" -Description "Temp password: Welcome2026 - change later"
New-LabUser -Name "kiosk01"    -Sam "kiosk01"    -Ou "Legacy" -Description "Lobby kiosk"
New-LabUser -Name "oldapp"     -Sam "oldapp"     -Ou "Legacy" -Description "Legacy application account"

# --- Deliberate misconfigurations (the things a scanner should find) ---

# 1. Password never expires: a service account and a legacy account
Set-ADUser -Identity "svc-backup" -PasswordNeverExpires $true
Set-ADUser -Identity "tempuser"   -PasswordNeverExpires $true

# 2. Service account with an SPN
Set-ADUser -Identity "svc-backup" -ServicePrincipalNames @{Add="MSSQLSvc/itsh-sql01.$dnsRoot:1433"}

# 3. Password not required
Set-ADAccountControl -Identity "kiosk01" -PasswordNotRequired $true

# 4. Kerberos pre-authentication disabled
Set-ADAccountControl -Identity "oldapp" -DoesNotRequirePreAuth $true

# 5. A regular employee in Domain Admins
Add-ADGroupMember -Identity "Domain Admins" -Members "bnguyen"

Write-Host ""
Write-Host "Done. Users in domain:" (Get-ADUser -Filter *).Count

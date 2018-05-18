<#
.SYNOPSIS
	Get an SSL certificate from Let's Encrypt and install it on FileMaker Server.

.PARAMETER Domains
	Array of domain(s) for which you would like an SSL Certificate.
	Let's Encrypt will peform separate validation for each of the domains,
	so be sure that your server is reachable at all of them before
	attempting to get a certificate. 100 domains is the max.

.PARAMETER Email
	Contact email address to your real email address so that Let's Encrypt
	can contact you if there are any problems.

.PARAMETER FMSPath
	Path to your FileMaker Server directory, ending in a backslash. Only
	necessary if installed in a non-default location.

.NOTES
	File Name:   GetSSL.ps1
	Author:      David Nahodyl contact@bluefeathergroup.com, modified by Daniel Smith dan@filemaker.consulting
	Created:     2016-10-08
	Revised:     2018-05-17
	Version:     0.7-DS

.LINK
	http://bluefeathergroup.com/blog/how-to-use-lets-encrypt-ssl-certificates-with-filemaker-server/

.EXAMPLE
	.\GetSSL.ps1 test.com user@test.com

	Simplest call with domain to sign listed first and email second.

.EXAMPLE
	.\GetSSL.ps1 test.com, sub.example.com user@test.com

	Multiple domains can be listed, separated by commas.

.EXAMPLE
	.\GetSSL.ps1 -d test.com -e user@test.com

	Can use short-hand parameter names.

.EXAMPLE
	.\GetSSL.ps1 -Domain test.com -Email user@test.com

	Or full parameter names.

.EXAMPLE
	.\GetSSL.ps1 test.com user@test.com -FMSPath "X:\FileMaker Server\"

	Use if you installed FileMaker Server in a non-default path.
	Must end in a backslash.

.EXAMPLE
	.\GetSSL.ps1 test.com user@test.com -Confirm

	Don't ask for confirmation; use the -Confirm parameter when called from a scheduled task.
	To have this script run silently, it must also be able to perform fmsadmin.exe without asking for username and password. There are two ways to do that:
		1. Add a group name that is allowed to access the Admin Console and run the script as a user that belongs to the group.
		2. Hard-code the username and password into this script. (NOT RECOMMENDED)

.EXAMPLE
	.\GetSSL.ps1 test.com user@test.com -WhatIf

	Display the inputs, then exit; use to verify you passed parameters in the correct format
#>


[cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]

Param(
	[Parameter(Mandatory=$True,Position=1)]
	[Alias('d')]
	[string[]] $Domains,

	[Parameter(Mandatory=$True,Position=2)]
	[Alias('e')]
	[string] $Email,

	[Parameter(Position=3)]
	[Alias('p')]
	[string] $FMSPath = 'C:\Program Files\FileMaker\FileMaker Server\'
)

<# Exit immediately on error #>
$ErrorActionPreference = "Stop"

$fmsadmin = $FMSPath + 'Database Server\fmsadmin.exe'


function Test-Administrator
{
	$user = [Security.Principal.WindowsIdentity]::GetCurrent();
	(New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}


<# Display user input #>
Write-Output ""
Write-Output ('  domains:   '+($Domains -join ', '))
Write-Output "  email:     $Email"
Write-Output "  FMSPath:   $FMSPath"
Write-Output ""


<# -WhatIf parameter provided, so don't do anything; just show parameters #>
if ([bool]$WhatIfPreference.IsPresent){
	if (-not (Test-Administrator)){
		Write-Output "  WARNING: This script is not running as Administrator."
		Write-Output ""
	}
	if (-not(Test-Path $fmsadmin)){
		Write-Output "  WARNING: fmsadmin could not be found at: '$fmsadmin', please check the FMSPath parameter: '$FMSPath'";
		Write-Output ""
	}
	exit;
}


<# Check to make sure we're running as admin #>
if (-not (Test-Administrator)){
	throw 'This script must be run as Administrator'
}


<# validate FMSPath #>
if (-not(Test-Path $fmsadmin)){
	throw "fmsadmin could not be found at: '$fmsadmin', please check the FMSPath parameter: '$FMSPath'";
}


if ($ConfirmPreference -eq "High"){
	while( -not ( ($choice= (Read-Host "If you proceed, and this script is successful, FileMaker Server service will be restarted and ALL USERS DISCONNECTED. Use the -Confirm parameter to prevent this confirmation.`n`nContinue?[y/n]")) -match "[yY]|[nN]")){ "Y or N ?"}
	if ($choice -match "[nN]"){
		exit;
	}
}


$domainAliases = @();foreach ($domain in $Domains) {
	if ($domain -Match ",| "){
		throw "Domain cannot contain a comma or parameter; perhaps two domains were passed as a single string? Try removing quotes from the domains.";
	}
	$domainAliases += "$domain"+[guid]::NewGuid().ToString();
}


<# Install ACMESharp #>
if (!(Get-Module -Listavailable -Name ACMESharp)){
	Install-Module -Name ACMESharp, ACMESharp.Providers.IIS -AllowClobber -Confirm
	Enable-ACMEExtensionModule -ModuleName ACMESharp.Providers.IIS
}
Import-Module ACMESharp;


<# Initialize the vault to either Live or Staging#>
if (!(Get-ACMEVault)) {
	Initialize-ACMEVault;
}
#Initialize-ACMEVault -BaseURI https://acme-staging.api.letsencrypt.org/


<# Regiser contact info with LE #>
New-ACMERegistration -Contacts mailto:$Email -AcceptTos;

<# ACMESharp keeps creating a web.config that doesn't work, so let's delete it and make our own good one #>
$webConfigPath = $FMSPath + 'HTTPServer\conf\.well-known\acme-challenge\web.config';
<# Delete the bad one #>
if (Test-Path $webConfigPath){
	Remove-Item $webConfigPath;
}

<# Create directory the file goes in #>
if (-not (Test-Path (Split-Path -Path $webConfigPath -Parent))){
	New-Item -Path (Split-Path -Path $webConfigPath -Parent) -ItemType Directory
}

<# Write a new good one #>
' <configuration>
     <system.webServer>
         <staticContent>
             <mimeMap fileExtension="." mimeType="text/plain" />
         </staticContent>
     </system.webServer>
 </configuration>' | Out-File -FilePath ($webConfigPath);


<# Loop through the array of domains and validate each one with LE #>
for ( $i=0; $i -lt $Domains.length; $i++ ) {
	<# Create a UUID alias to use for our domain request #>
	$domain = $Domains[$i];
	$domainAlias = $domainAliases[$i];
	Write-Output "Performing challenge for $domain with alias $domainAlias";
	<#Create an entry for us to use with these requests using the alias we just generated #>
	New-ACMEIdentifier -Dns $domain -Alias $domainAlias;
	<# Use ACMESharp to automatically create the correct files to use for validation with LE #>
	$response = Complete-ACMEChallenge $domainAlias -ChallengeType http-01 -Handler iis -HandlerParameters @{ WebSiteRef = 'FMWebSite'; SkipLocalWebConfig = $true } -Force;

	<# Sample Response
	== Manual Challenge Handler - HTTP ==
	  * Handle Time: [1/12/2016 1:16:34 PM]
	  * Challenge Token: [2yRd04TwqiZTh6TWLZ1azL15QIOGaiRmx8MjAoA5QH0]
	To complete this Challenge please create a new file
	under the server that is responding to the hostname
	and path given with the following characteristics:
	  * HTTP URL: [http://myserver.example.com/.well-known/acme-challenge/2yRd04TwqiZTh6TWLZ1azL15QIOGaiRmx8MjAoA5QH0]
	  * File Path: [.well-known/acme-challenge/2yRd04TwqiZTh6TWLZ1azL15QIOGaiRmx8MjAoA5QH0]
	  * File Content: [2yRd04TwqiZTh6TWLZ1azL15QIOGaiRmx8MjAoA5QH0.H3URk7qFUvhyYzqJySfc9eM25RTDN7bN4pwil37Rgms]
	  * MIME Type: [text/plain]------------------------------------
	#>
	<# Let them know it's ready #>
	Submit-ACMEChallenge $domainAlias -ChallengeType http-01 -Force;
	<# Pause 10 seconds to wait for LE to validate our settings #>
	Start-Sleep -s 10
	<# Check the status #>
	(Update-ACMEIdentifier $domainAlias -ChallengeType http-01).Challenges | Where-Object {$_.Type -eq "http-01"};

	<# Good Response Sample
	ChallengePart          : ACMESharp.Messages.ChallengePart
	Challenge              : ACMESharp.ACME.HttpChallenge
	Type                   : http-01
	Uri                    : https://acme-v01.api.letsencrypt.org/acme/challenge/a7qPufJw0Wdk7-Icw6V3xDDlXj1Ag5CVr4aZRw2H27
	                         A/323393389
	Token                  : CqAhe31xGDeaqzf01dPx2j9NUqsBVqT1LpQ_Rhx1GiE
	Status                 : valid
	OldChallengeAnswer     : [, ]
	ChallengeAnswerMessage :
	HandlerName            : manual
	HandlerHandleDate      : 11/3/2016 12:33:16 AM
	HandlerCleanUpDate     :
	SubmitDate             : 11/3/2016 12:34:48 AM
	SubmitResponse         : {StatusCode, Headers, Links, RawContent...}
	#>
}



$certAlias = 'cert-'+[guid]::NewGuid().ToString();

<# Ready to get the certificate #>
Write-Output "New-ACMECertificate -----------------------------------------------------------";
New-ACMECertificate $domainAliases[0] -Generate -AlternativeIdentifierRefs $domainAliases -Alias $certAlias;

Write-Output "Submit-ACMECertificate --------------------------------------------------------";
Submit-ACMECertificate $certAlias;

<# Pause 10 seconds to wait for LE to create the certificate #>
Start-Sleep -s 10

<# Check the status $certAlias #>
Write-Output "Update-ACMECertificate --------------------------------------------------------";
Update-ACMECertificate $certAlias;


<# Look for a serial number #>


<# Export the private key #>
$keyPath = $FMSPath + 'CStore\serverKey.pem'
if (Test-Path $keyPath){
	Remove-Item $keyPath;
}
Get-ACMECertificate $certAlias -ExportKeyPEM $keyPath;

<# Export the certificate #>
$certPath = $FMSPath + 'CStore\crt.pem'
if (Test-Path $certPath){
	Remove-Item $certPath;
}
Get-ACMECertificate $certAlias -ExportCertificatePEM $certPath;

<# Export the Intermediary #>
$intermPath = $FMSPath + 'CStore\interm.pem'
if (Test-Path $intermPath){
	Remove-Item $intermPath;
}
Get-ACMECertificate $certAlias -ExportIssuerPEM $intermPath;

<# Install the certificate #>
& $fmsadmin certificate import $certPath -y;

<# Append the intermediary certificate to support older FMS before 15 #>
Add-Content $FMSPath'CStore\serverCustom.pem' (Get-Content $intermPath)

<# Restart the FMS service #>
net stop 'FileMaker Server';
net start 'FileMaker Server';

<# Just in case server isn't configured to start automatically
	(should add other services here, if necessary, like WPE) #>
& $fmsadmin start server

<# All done! Exit. #>
exit;

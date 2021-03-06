Function Get-RemoteLoggedonUser {
# Updated from original script here: 
# http://gallery.technet.microsoft.com/scriptcenter/0e43993a-895a-4afe-a2b2-045a5146048a#content
#
# .EXAMPLE
#  $Cred = Get-Credential
#  $a = Get-RemoteLoggedonUser 'server01' -Credential $Cred | 
#       Where {$_.Type -eq 'RemoteInteractive'} | 
#       select -unique User
    [CmdletBinding()]
    param( 
        [Parameter( Position=0,
                    ValueFromPipelineByPropertyName=$true,                    
                    ValueFromPipeline=$true,
                    HelpMessage="Computers to retreive logged in user list from." )]
        [string[]]$ComputerName = $env:computername,
        [parameter( HelpMessage="Set this if you want the function to prompt for alternate credentials" )]
        [switch]$PromptForCredential,
        [parameter( HelpMessage="Pass an alternate credential" )]
        [System.Management.Automation.PSCredential]$Credential = $null
    )
    BEGIN 
    {
        if ($PromptForCredential)
        {
            $Credential = Get-Credential
        }
        $regexa = '.+Domain="(.+)",Name="(.+)"$' 
        $regexd = '.+LogonId="(\d+)"$' 

        $logontype = @{ 
                        "0"="Local System" 
                        "2"="Interactive" #(Local logon) 
                        "3"="Network" # (Remote logon) 
                        "4"="Batch" # (Scheduled task) 
                        "5"="Service" # (Service account logon) 
                        "7"="Unlock" #(Screen saver) 
                        "8"="NetworkCleartext" # (Cleartext network logon) 
                        "9"="NewCredentials" #(RunAs using alternate credentials) 
                        "10"="RemoteInteractive" #(RDP\TS\RemoteAssistance) 
                        "11"="CachedInteractive" #(Local w\cached credentials) 
                      }
    }
    PROCESS
    {
        Foreach ($computer in $ComputerName) {
            $wmiparams = @{ Computername = $Computer }
            if ($Credential -ne $null) {
                $wmiparams.Credential = $Credential
            }
            $logon_sessions = @(gwmi win32_logonsession @wmiparams) 
            $logon_users = @(gwmi win32_loggedonuser @wmiparams) 
             
            $session_user = @{} 
         
            $logon_users | %{
                $_.antecedent -match $regexa > $null
                $username = $matches[1] + "\" + $matches[2]
                $_.dependent -match $regexd > $null
                $session = $matches[1]
                $session_user[$session] += $username
            }

            $logon_sessions | %{
                $starttime = [management.managementdatetimeconverter]::todatetime($_.starttime)

                $userproperties = @{
                                    Session = $_.logonid
                                    User = $session_user[$_.logonid]
                                    'Type' = $logontype[$_.logontype.tostring()]
                                    Auth = $_.authenticationpackage
                                    StartTime = $starttime
                                   }
                $loggedonuser = New-Object -TypeName psobject -Property $userproperties
                $loggedonuser
            }
        }
    }
}

  $Cred = Get-Credential
  $a = Get-RemoteLoggedonUser 'us-chi-bkp-02' -Credential $Cred | 
       Where {$_.Type -eq 'RemoteInteractive'} | 
       select -unique User
## Credit

This is a fork of the work started by: [David Nahodyl, Blue Feather](http://bluefeathergroup.com/blog/how-to-use-lets-encrypt-ssl-certificates-with-filemaker-server/)  

Thanks for figuring out the hard part David!


## Notes

* Only supports newer OS (only tested on Windows Server 2017, but likely works on 2016 as well).
* Only tested on FileMaker Server 16 and 17.
* Installs ACMESharp for you. (TODO: test this)
* Will not display any errors, unless it fails.


## Installation

1. Open PowerShell console as an Administrator:
    1. Click **Start**
    2. Type **PowerShell**
    3. Right-click on **Windows PowerShell**
    4. Click **Run as administrator**

2. Configure ExecutionPolicy:  
   TODO: verify CurrentUser scope is sufficient

    * Option 1: Change the policy for the current user (less secure):

        ```powershell
        Set-ExecutionPolicy -Scope CurrentUser Unrestricted
        ```

    * Option 2: specify the policy every time you run the script (more secure):
	TODO: consider making this the only suggestion

        ```powershell
        powershell.exe -ExecutionPolicy Bypass -Command .\GetSSL.ps1 example.com user@email.com
    	```

3. Download the `GetSSL.ps1` file to your server:

    ```powershell
	Invoke-WebRequest -Uri https://raw.githubusercontent.com/dansmith65/FileMaker-LetsEncrypt/blob/dev/GetSSL.ps1 -OutFile "C:\Program Files\FileMaker\FileMaker Server\Data\Scripts\GetSSL.ps1"
    ```

4. Get your first Certificate:

    ```powershell
    "C:\Program Files\FileMaker\FileMaker Server\Data\Scripts\GetSSL.ps1" fms.example.com user@email.com
    ```

5. Setup scheduled task to renew the certificate:  
   TODO: mention that fmsadmin user/pass needs to either be saved in the script, or user that runs the script exist in a group that can access admin console

    ```powershell
    #TODO
    ```


## Docs

Once the script is downloaded, run this from PowerShell, while in the same directory as the script, to get all documentation on the script:

```powershell
Get-Help .\GetSSL.ps1 -full
```

(Or just view the GetSSL.ps1 file in a text editor)

## Credit

This is a fork of the work started by: [David Nahodyl, Blue Feather](http://bluefeathergroup.com/blog/how-to-use-lets-encrypt-ssl-certificates-with-filemaker-server/)  

Thanks for figuring out the hard part David!


## Notes

* Only supports newer OS (only tested on Windows Server 2016).
* Only tested on FileMaker Server 16 and 17.
* Installs ACMESharp for you.
* Will not display any errors, unless it fails.


## Installation

1. Open PowerShell console as an Administrator:
    1. Click **Start**
    2. Type **PowerShell**
    3. Right-click on **Windows PowerShell**
    4. Click **Run as administrator**

2. Download the `GetSSL.ps1` file to your server:

    ```powershell
	# TODO: switch out /dev/ with /master/ before merging with that branch
	Invoke-WebRequest -Uri https://raw.githubusercontent.com/dansmith65/FileMaker-LetsEncrypt/dev/GetSSL.ps1 -OutFile "C:\Program Files\FileMaker\FileMaker Server\Data\Scripts\GetSSL.ps1"
    ```

3. Get your first Certificate:

    ```powershell
	# You might want to read the Docs first (see below).
    # If you like to live dangerously and you have FileMaker Server installed in
    # the default directory you can run this command after replacing fms.example.com
    # and user@email.com with your own.
    
    powershell.exe -ExecutionPolicy Bypass -Command "& 'C:\Program Files\FileMaker\FileMaker Server\Data\Scripts\GetSSL.ps1' fms.example.com user@email.com"
    ```

4. (Optional) Setup scheduled task to renew the certificate:  
   TODO: mention that fmsadmin user/pass needs to either be saved in the script, or user that runs the script exist in a group that can access admin console

    ```powershell
    #TODO
    ```

5. (Optional) Configure ExecutionPolicy:  

    * Option 1: specify the policy every time you run the script (more secure):  
	  This is the method used when getting your first certificate.

        ```powershell
        powershell.exe -ExecutionPolicy Bypass -Command .\GetSSL.ps1 example.com user@email.com
    	```

    * Option 2: Change the policy for the CurrentUser or LocalSystem (less secure):

        ```powershell
        # First, view the current policy:
        Get-ExecutionPolicy -List
        
        # If necessary, modify the policy:
        Set-ExecutionPolicy -Scope CurrentUser Unrestricted
        ```


## Docs

Once the script is downloaded, run this from PowerShell, while in the same directory as the script, to get all documentation on the script:

```powershell
Get-Help .\GetSSL.ps1 -full
```

(Or just view the GetSSL.ps1 file in a text editor)

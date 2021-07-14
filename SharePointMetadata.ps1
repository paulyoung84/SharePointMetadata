#Load SharePoint CSOM Assemblies
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
Add-Type -AssemblyName "System.Web"
 
#Parameters
$SiteURL = "SHAREPOINT URL"
$CSVPath = "C:\Temp\FilesInventory.csv"
#Array for Result Data
$DataCollection = @()
$BatchSize="1000"
 
#Get credentials to connect
$Cred = Get-Credential
 
Try {
    #Setup the Context
    $Ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
    $Ctx.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Cred.UserName, $Cred.Password)
 
    #Get the Web
    $Web = $Ctx.Web
    $Lists = $Web.Lists
    $Ctx.Load($Web)
    $Ctx.Load($Lists)
    $Ctx.ExecuteQuery()
 
    #Iterate through Each List on the web
    ForEach($List in $Lists)
    {
        #Filter Lists
        If($List.BaseType -eq "DocumentLibrary" -and $List.Hidden -eq $False  -and $List.Title -ne "Site Pages")
        {
            #Get all List items from the library - Exclude "Folder" objects
            $Query = New-Object Microsoft.SharePoint.Client.CamlQuery
            $Query.ViewXml= @"
			<View Scope='RecursiveAll'>
				<Query>
					<OrderBy><FieldRef Name='ID' Ascending='TRUE'/></OrderBy>
				</Query>
				<RowLimit Paged="TRUE">$BatchSize</RowLimit>
			</View>
"@
        #Get List Items in Batch
		Do
		{
			$ListItems = $List.GetItems($Query)
			$Ctx.Load($ListItems)
			$Ctx.ExecuteQuery()
			$ListItems.count
			$Query.ListItemCollectionPosition = $ListItems.ListItemCollectionPosition
				
				ForEach($Item in $ListItems)
				{
					if($Item.FieldValues["FSObjType"] -eq 0){
					#Get the File from Item
					$File = $Item.File
					$Ctx.Load($File)
					$Ctx.ExecuteQuery()
					#Write-Progress -PercentComplete ($Count / $ListItems.Count * 100) -Activity "Processing File $count of $($ListItems.Count) in $($List.Title) of $($Web.URL)" -Status "Scanning File '$($File.Name)'"
 
					#Get The File Hash
					$Bytes = $Item.file.OpenBinaryStream()
					$Ctx.ExecuteQuery()
					$MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
					$HashCode = [System.BitConverter]::ToString($MD5.ComputeHash($Bytes.Value))
					$MimeType = [System.Web.MimeMapping]::GetMimeMapping($File.Name)
 
					#Collect data       
					$Data = New-Object PSObject
					$Data | Add-Member -MemberType NoteProperty -name "FileName" -value $File.Name
					$Data | Add-Member -MemberType NoteProperty -Name "HashCode" -value $HashCode
					$Data | Add-Member -MemberType NoteProperty -Name "URL" -value $File.ServerRelativeUrl
					$Data | Add-Member -MemberType NoteProperty -Name "CreatedDate" -value $File.TimeCreated
					$Data | Add-Member -MemberType NoteProperty -Name "ModifiedDate" -value $File.TimeLastModified
					$Data | Add-Member -MemberType NoteProperty -Name "MimeType" -value $MimeType
					$DataCollection += $Data
					$Count++
					}
				}
		} While($Query.ListItemCollectionPosition -ne $null)
		}	
    }   
    #Export All Data to CSV
    $DataCollection | Export-Csv -Path $CSVPath -NoTypeInformation
    Write-host -f Green "Files Inventory has been Exported to $CSVPath"
	$DataCollection| Format-table -AutoSize
}
Catch {
    write-host -f Red "Error:" $_.Exception.Message
}

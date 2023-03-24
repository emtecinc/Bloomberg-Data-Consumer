#----------------------------------------------------------------------------------------------------
#Install powershell module for Azure
#Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force

# Login to Azure subscription
Connect-AzAccount  #Enter the credentials to login
Set-AzContext -Subscription "Empower-Prod-Pay-As-You-Go"  #Select the Subscrption

#Set parameters
$resourceGroupName = "bloomberg-rg"
$storageacc = "storageaccbloombg"           # storage account - destination for files to be copied (unique name)
$storageaccfun = "storageaccbloombgfun"     # storage account for function app (unique name)
$eventgridtopic = "bloombergcustomertopic"
$azfunctionapp = "bloomberg-functionapp"

$location = "eastus"
$vnetaddressspace = "10.0.0.0/24"
$subnetname = "function"
$sub_prefix = "10.0.0.0/26"
$VnetName = "bloomberg-vnet"
$funappplan = "funappplan"
$appArchivePath = ".\zipdeploy_content.zip"

#--------------------------------------------------------------------------------------------------------
#Create Resource Group if required
New-AzResourceGroup -Name $resourceGroupName -Location $location

#--------------------------------------------------------------------------------------------------------

#Create Vnet & Subnet
$vnetconfig = New-AzVirtualNetwork `
              -ResourceGroupName $resourceGroupName `
              -Location $location `
              -Name $VnetName `
              -AddressPrefix $vnetaddressspace

$subnetConfig = Add-AzVirtualNetworkSubnetConfig `
                -Name $subnetname `
                -AddressPrefix $sub_prefix  `
                -VirtualNetwork $vnetconfig `
                -ServiceEndpoint Microsoft.Storage

#Write the subnet configuration to the virtual network 
$vnetconfig | Set-AzVirtualNetwork


#----------------------------------------------------------------------------------------------------------

# Create custom topic

$eventgrid = Get-AzEventGridTopic -Name $eventgridtopic -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if($eventgrid -eq $null){
    New-AzEventGridTopic -ResourceGroupName $resourceGroupName `
                         -Name $eventgridtopic `
                         -Location $location
}
else{
    Write-Host "$eventgrid already exist"
}

# Retrieve endpoint and key to use when publishing to the topic
$endpoint = (Get-AzEventGridTopic -ResourceGroupName $resourceGroupName -Name $eventgridtopic).Endpoint
$key = (Get-AzEventGridTopicKey -ResourceGroupName $resourceGroupName -Name $eventgridtopic).Key1


#-----------------------------------------------------------------------------------------------------------------------------

# storage account for function app

$stgacc = Get-AzStorageAccountNameAvailability -Name $storageaccfun

if($stgacc.NameAvailable){
                              New-AzStorageAccount -ResourceGroupName $resourceGroupName `
                                                   -Name "$storageaccfun" `
                                                   -Location $location `
                                                   -SkuName Standard_LRS                               
}
else{
      Write-Host $stgacc.Message
}

#storage account - destination for files to be copied

$stgacc = Get-AzStorageAccountNameAvailability -Name $storageacc
if($stgacc.NameAvailable){
                               New-AzStorageAccount -ResourceGroupName $resourceGroupName `
                                                    -Name "$storageacc" `
                                                    -Location $location `
                                                    -SkuName Standard_LRS
                               $context = New-AzStorageContext -StorageAccountName $storageacc -UseConnectedAccount
                               New-AzStorageContainer -Name "customer-snapshots" -Context $context
}
else{
       Write-Host $stgacc.Message
}


#------------------------------------------------------------------------------------------------

# Azure Function
New-AzFunctionAppPlan -ResourceGroupName "$resourceGroupName" `
                      -Name "$funappplan" `
                      -Location "eastus" `
                      -Sku "S1" `
                      -WorkerType "Windows"
#                      -MaximumWorkerCount 2
#                      -MinimumWorkerCount 1
New-AzFunctionApp -Name $azfunctionapp `
                  -ResourceGroupName $resourceGroupName `
                  -PlanName "$funappplan" `
                  -StorageAccountName "$storageaccfun" `
                  -Runtime DotNet `
                  -RuntimeVersion 6 `
                  -OSType Windows `
                  -FunctionsVersion 4 -DisableApplicationInsights


$stgacc = Get-AzStorageAccountKey -StorageAccountName $storageacc -ResourceGroupName $resourceGroupName
$destkey = $stgacc[0].Value
$destconnstr = "DefaultEndpointsProtocol=https;AccountName=$storageacc;AccountKey=$destkey;EndpointSuffix=core.windows.net"

Update-AzFunctionAppSetting -ResourceGroupName $resourceGroupName -Name $azfunctionapp `
                            -AppSetting @{"WEBSITE_CONTENTOVERVNET" = "1";
                                          "WEBSITE_VNET_ROUTE_ALL" = "1";
                                          "WEBSITE_DNS_SERVER" = "168.63.129.16";
                                          "DestinationContainerName" = "customer-snapshots";
                                          "DestinationConnectionString" = $destconnstr}

# Publish function code (zip) to functionapp 
Publish-AzWebapp -ResourceGroupName $resourceGroupName `
                 -Name $azfunctionapp `
                 -ArchivePath $appArchivePath -Force                 

#------------------------------------------------------------------------------------------------------------

# Integrating Vnet with functionapp

$vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $resourceGroupName
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetname -VirtualNetwork $vnet
$deligation = Get-AzDelegation -Subnet $subnet

#Check if the subnet is delegated to Microsoft.Web/serverFarms
if($deligation.name -eq "funcDelegation" -and $deligation.ProvisioningState -eq "Succeeded" ){

    Write-Host "Delegation exists"
}
else{
     $subnet = Add-AzDelegation -Name "funcDelegation" `
     -ServiceName "Microsoft.Web/serverFarms" `
     -Subnet $subnet
     Set-AzVirtualNetwork -VirtualNetwork $vnet
}

$webApp = Get-AzResource -ResourceType Microsoft.Web/sites -ResourceGroupName $resourceGroupName -ResourceName $azfunctionapp
$webApp.Properties.virtualNetworkSubnetId = $subnet.Id
$webApp.Properties.vnetRouteAllEnabled = 'true'
$webApp | Set-AzResource -Force


#------------------------------------------------------------------------------------------------

# Deny public access to function Storage Account
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName "$resourceGroupName" `
                                      -Name $storageaccfun `
                                      -DefaultAction Deny 

# Allow vnet/subnet access for Storage Account
$vnet = Get-AzVirtualNetwork -ResourceGroupName "$resourceGroupName" -Name "$VnetName"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetname -VirtualNetwork $vnet

Add-AzStorageAccountNetworkRule -ResourceGroupName "$resourceGroupName" `
                                -Name $storageaccfun `
                                -VirtualNetworkResourceId $subnet.Id


# Deny public access to Destination Storage Account
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName "$resourceGroupName" `
                                      -Name "$storageacc" `
                                      -DefaultAction Deny 

Add-AzStorageAccountNetworkRule -ResourceGroupName "$resourceGroupName" `
                                -Name "$storageacc" `
                                -VirtualNetworkResourceId $subnet.Id
#-----------------------------------------------------------------------------------------------
# Event grid Subscription

$function = Get-AzFunctionApp -ResourceGroupName $resourceGroupName -Name $azfunctionapp
$endpoint = $function.id + "/functions/CopyBlobFile"

New-AzEventGridSubscription -TopicName $eventgridtopic `
-EventSubscriptionName "sub-copyblob-func" `
-EndpointType azurefunction `
-Endpoint $endpoint `
-ResourceGroupName $resourceGroupName

#------------------------------------------------------------------------------------------------
# Get endpoint and key1 for event grid topic 

$endpoint = (Get-AzEventGridTopic -ResourceGroupName $resourceGroupName -Name $eventgridtopic).Endpoint
$urlContentInBytes = [System.Text.Encoding]::UTF8.GetBytes($endpoint)
$endpointInbase64 = [System.Convert]::ToBase64String($urlContentInBytes) 

$key = (Get-AzEventGridTopicKey -ResourceGroupName $resourceGroupName -Name $eventgridtopic).Key1
$keyInBytes = [System.Text.Encoding]::UTF8.GetBytes($key)
$keyInbase64 = [System.Convert]::ToBase64String($fileContentInBytes) 

"Topic endpoint = $endpointInbase64"
"Access Key = $keyInbase64"
#------------------------------------------------------------------------------------------------

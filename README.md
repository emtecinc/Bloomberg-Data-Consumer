# Bloomberg-Data-Consumer
The Bloomberg Data Consumer project is a one click Microsoft Azure solution which allows Bloomberg customer to access Bloomberg data in Azure Blob Storage containers, accompanied by the "data ready" alerts delivered directly to customers via Azure EventGrid notifications.   

There are two ways of deployment:
### 1. Using ARM template

**Click me** (use CTRL+Click for new tab)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Femtecinc%2Fbloomberg-data-consumer%2Fmain%2Fazuredeploy.json) 

### 2. Using Powershell script

To download the script, find the file with name "bloomberg-infra.ps1" in same repository. 

Run this script in powershell. (**note -** before you run the script, please make sure the script file and zipdeploy_content.zip file should present in the same folder.)

## Overview
This sample deploys an Azure Functions app with an Event Grid trigger to act as a webhook within the vnet-subnet integration. 

## Resources
All default_name of resources **can be modified** and also must be **unique**. 

| Resources | default_name | Comment |
| :----- | :--- | :--- |
| Event Grid topic | bbgcustomertopic |   |
| Function App plan | bbgcustfunappplan |   |
| Virtual network (Subnet) | bbgcust-vnet (function) | Subnet Name i.e function is fix  |
| Azure Functions app (function) | bbgcust-functionapp (CopyBlobFile) | function name i.e CopyBlobFile is fix  |
| Azure Storage account  | bbgcuststorageaccfun | dedicatedly used for function related data |
| Azure Storage account | bbgcuststorageacc   | used as destination container to store blob files |


## Get the Topic Endpoint & Access key
Once the deployment is done, Event Grid topic endpoint and Access key should be provided to Bloomberg.

If deployment is done using PowerShell script then Event Grid topic endpoint and Access key will be available in envrypted format at the end of the script execution.

If deployment is done using ARM template then -

#### Go to Event Grid topic (customertopic) -> Overview -> Topic Endpoint

<img width="881" alt="image" src="https://user-images.githubusercontent.com/126143091/226527597-60933b38-6102-4498-a05b-1dd0139b7ed3.png">

#### Go to Event Grid topic (customertopic) -> Settings -> Access Key -> Key1/Key2

<img width="940" alt="image" src="https://user-images.githubusercontent.com/126143091/226530031-2c18b375-b297-466f-b1db-2794f398509b.png">

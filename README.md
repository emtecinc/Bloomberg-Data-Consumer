# Bloomberg-Data-Consumer
The Bloomberg Data Consumer project is a one click Microsoft Azure solution which allows Bloomberg customer to access Bloomberg data in Azure Blob Storage containers, accompanied by the "data ready" alerts delivered directly to customers via Azure EventGrid notifications.   

There are two ways of deployment:
### 1. Using ARM template

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Femtecinc%2Fbloomberg-data-consumer%2Fmain%2Fazuredeploy.json) **Click me** (use CTRL+Click for new tab)


### 2. Using Powershell script

To download the script, find the file with name "bloomberg-infra.ps1" in same repository. 

Run this script in powershell. (**note -** before you run the script, please make sure the script file and zipdeploy_content.zip file should present in the same folder.)

## Overview
This sample deploys an Azure Functions app with an Event Grid trigger to act as a webhook within the vnet-subnet integration. 

## Resources
All default_name of resources **can be modified** and also must be **unique**. 

| resources | default_name | Comment |
| :----- | :--- | :--- |
| Event Grid topic | bbgcustomertopic |   |
| Function App plan | bbgcustfunappplan |   |
| Virtual network (Subnet) | bbgcust-vnet (function) | Subnet Name i.e function is fix  |
| Azure Functions app (function) | bbgcust-functionapp (CopyBlobFile) | function name i.e CopyBlobFile is fix  |
| Azure Storage account  | bbgcuststorageaccfun | dedicatedly used for function related data |
| Azure Storage account | bbgcuststorageacc   | used as destination container to store blob files |

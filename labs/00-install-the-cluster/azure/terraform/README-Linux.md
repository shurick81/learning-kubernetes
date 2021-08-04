## Prerequisites

- Client device with installed software
  - Docker
- Infrastructure provider
  - Azure

#### If an Azure app identity is not created yet, create it

Feel free to login to Azure using Docker or using Azure Cloud Shell.

##### Use Docker for login to Azure

1. Start an Azure CLI container

```
sudo docker run -it --rm mcr.microsoft.com/azure-cli:2.16.0
```

2. Run the following command in the container:

```
az login
```

Follow the instructions in order to authenticate.

##### Use Azure Cloud Shell

1. Authenticate in https://portal.azure.com/

2. Select the directory (tenant) you want to manage

3. Open Cloud Shell in bash mode

##### Finish creating the app identity

1. In the container or in Cloud Shell, run the following command to list tenants and subscriptions:

```bash
echo 'tenantId                                Subscription id                         Default Subscription name';
az account list --query '[].[tenantId,id,isDefault,name]' -o tsv;
```

2. Then following commands to select a specific subscription that you want to use by the application identity:

```bash
az account set --subscription 58baf6a1-d140-4b25-8ed1-b3195bbf2c7c
```

3. Create the app with comprehensive data output:

```
az ad sp create-for-rbac --name informative-name-of-the-identity --skip-assignment
```

Alternatively, you can update existing identity instead of creating a new one:

```
az ad sp credential reset --name 2772218f-5268-4d09-aa4c-b8a9746d613e
```

#### Compose variable files

For example:

```bash
ARM_CLIENT_ID="531adb66-98a5-4e6b-b407-b1961a2794e1";
ARM_CLIENT_SECRET="xxxx";
ARM_SUBSCRIPTION_ID="d7c7a3af-f74f-4007-845c-dcacef601c53";
ARM_TENANT_ID="8b87af7d-8647-4dc7-8df4-5f69a2011bb5";
```

# Deploy Using Windows

```bash
cd ~/projects/learning-kubernetes/labs/00-install-the-cluster/azure/terraform
rm -rf .terraform.tfstate.lock.info
rm -f terraform.tfstate
rm -f terraform.tfstate.backup
sudo docker run --rm -v $(pwd)/../..:/workplace -w /workplace/azure/terraform hashicorp/terraform:light init
sudo docker run --rm -v $(pwd)/../..:/workplace -w /workplace/azure/terraform \
    -e TF_VAR_ARM_CLIENT_ID=$ARM_CLIENT_ID \
    -e TF_VAR_ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET \
    -e TF_VAR_ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID \
    -e TF_VAR_ARM_TENANT_ID=$ARM_TENANT_ID \
    hashicorp/terraform:light \
    apply -auto-approve
```

This might take about 2-3 minutes.

# Destroy Using Windows

```bash
cd ~/projects/learning-kubernetes/labs/00-install-the-cluster/azure/terraform
sudo docker run --rm -v $(pwd)/../..:/workplace -w /workplace/azure/terraform \
    -e TF_VAR_ARM_CLIENT_ID=$ARM_CLIENT_ID \
    -e TF_VAR_ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET \
    -e TF_VAR_ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID \
    -e TF_VAR_ARM_TENANT_ID=$ARM_TENANT_ID \
    hashicorp/terraform:light \
    destroy -auto-approve
```

# Taint

```
cd ~/projects/learning-kubernetes/labs/00-install-the-cluster/azure/terraform
sudo docker run --rm -v $(pwd):/workplace -w /workplace hashicorp/terraform:light taint module.WORKER0.azurerm_linux_virtual_machine.worker
sudo docker run --rm -v $(pwd):/workplace -w /workplace hashicorp/terraform:light taint module.WORKER1.azurerm_linux_virtual_machine.worker
sudo docker run --rm -v $(pwd):/workplace -w /workplace hashicorp/terraform:light taint module.CONTROLLER0.azurerm_linux_virtual_machine.controller
sudo docker run --rm -v $(pwd):/workplace -w /workplace hashicorp/terraform:light taint module.CONTROLLER1.azurerm_linux_virtual_machine.controller
sudo docker run --rm -v $(pwd):/workplace -w /workplace hashicorp/terraform:light taint module.CONTROLLER2.azurerm_linux_virtual_machine.controller
```

# Get Infrastructure Variables

Refresh variables every time you start machines

```bash
EXTERNAL_IP=$(sudo docker run --rm mcr.microsoft.com/azure-cli:2.26.1 /bin/bash -c "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none; az network public-ip show -g kubernetes-lab-00 -n kubernetes-pip --query ipAddress -o tsv")
PUBLIC_IP_ADDRESS_WORKER_0=$(sudo docker run --rm mcr.microsoft.com/azure-cli:2.26.1 /bin/bash -c "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none; az network public-ip show -g kubernetes-lab-00 -n worker-0-pip --query 'ipAddress' -o tsv")
PUBLIC_IP_ADDRESS_WORKER_1=$(sudo docker run --rm mcr.microsoft.com/azure-cli:2.26.1 /bin/bash -c "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none; az network public-ip show -g kubernetes-lab-00 -n worker-1-pip --query 'ipAddress' -o tsv")
PUBLIC_IP_ADDRESS_CONTROLLER_0=$(sudo docker run --rm mcr.microsoft.com/azure-cli:2.26.1 /bin/bash -c "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none; az network public-ip show -g kubernetes-lab-00 -n controller-0-pip --query 'ipAddress' -o tsv")
PUBLIC_IP_ADDRESS_CONTROLLER_1=$(sudo docker run --rm mcr.microsoft.com/azure-cli:2.26.1 /bin/bash -c "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none; az network public-ip show -g kubernetes-lab-00 -n controller-1-pip --query 'ipAddress' -o tsv")
PUBLIC_IP_ADDRESS_CONTROLLER_2=$(sudo docker run --rm mcr.microsoft.com/azure-cli:2.26.1 /bin/bash -c "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none; az network public-ip show -g kubernetes-lab-00 -n controller-2-pip --query 'ipAddress' -o tsv")
KUBERNETES_PUBLIC_ADDRESS=$(sudo docker run --rm mcr.microsoft.com/azure-cli:2.26.1 /bin/bash -c "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none; az network public-ip show -g kubernetes-lab-00 -n kubernetes-pip --query ipAddress -o tsv")
KUBERNETES_PUBLIC_IP_ADDRESS=$(sudo docker run --rm mcr.microsoft.com/azure-cli:2.26.1 /bin/bash -c "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --output none; az network public-ip show -g kubernetes-lab-00 -n kubernetes-pip --query ipAddress -o tsv")
```

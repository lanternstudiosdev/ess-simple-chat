# Teams HR Bot - Terraform Deployment

**🎯 Streamlined for MVP:** This Terraform configuration deploys a stateless Teams HR bot with essential resources only.

---

## Quick Start

For complete deployment instructions, see the main deployment guide:

📖 **[DEPLOYMENT.md](../../DEPLOYMENT.md)** - Complete step-by-step guide

---

## What This Terraform Configuration Deploys

### Essential Resources (MVP)

✅ **Infrastructure (8 services)**
- Resource Group
- App Service Plan (B1 - $13/month)
- Linux Web App (Python 3.11)
- Log Analytics + Application Insights

✅ **AI & Data Services (5 services)**
- Azure OpenAI + 2 Model Deployments (gpt-4o, text-embedding-3-small)
- Azure AI Search (Basic - $75/month)
- Cosmos DB Serverless + 4 Containers
- Document Intelligence (S0)
- Storage Account + 1 Blob Container

✅ **Bot Framework (2 services)**
- Bot Service Registration (Free F0 tier)
- Teams Channel

✅ **Identity & Access (3 components)**
- App Registration
- Service Principal
- Managed Identity with RBAC

**Total: ~19 resources | Estimated cost: ~$115-150/month**

---

## Removed from Original Configuration

❌ **Key Vault** - Simplified to use app settings
❌ **Entra Security Groups** - Not needed for bot auth
❌ **App Roles** - Bot uses Bot Framework auth
❌ **ACR Dependencies** - Direct Python deployment
❌ **22 Cosmos Containers** - Reduced to 4 essential containers

---

## Prerequisites

1. **Azure CLI** (version 2.50.0+)
   ```bash
   az version
   ```

2. **Terraform** (version 1.12.0+)
   ```bash
   terraform version
   ```

3. **Azure Subscription with permissions** to create:
   - App Registrations
   - Azure resources (OpenAI, Cosmos DB, etc.)

---

## Configuration

### Step 1: Copy Example Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Edit terraform.tfvars

Required values:
```hcl
param_subscription_id         = "your-subscription-id"
param_tenant_id              = "your-tenant-id"
param_location               = "usgovvirginia"  # or "eastus" for commercial
param_environment            = "dev"
param_base_name              = "hrbot"  # Keep short!
param_resource_owner_id      = "Your Name"
param_resource_owner_email_id = "you@company.gov"
global_which_azure_platform  = "AzureUSGovernment"  # or "AzureCloud"
```

Optional (use existing OpenAI):
```hcl
param_use_existing_openai_instance              = true
param_existing_azure_openai_resource_name      = "my-openai"
param_existing_azure_openai_resource_group_name = "my-rg"
```

---

## Deployment Steps

### Step 1: Login to Azure CLI

**For Azure Commercial:**
```bash
az cloud set --name AzureCloud
az login
az account set --subscription "your-subscription-id"
```

**For Azure Government:**
```bash
az cloud set --name AzureUSGovernment
az login --scope https://management.core.usgovcloudapi.net//.default
az account set --subscription "your-subscription-id"
```

### Step 2: Initialize Terraform

```bash
cd deployers/terraform
terraform init
```

### Step 3: Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the resources to be created. You should see:
- 1 Resource Group
- 1 App Service Plan (B1)
- 1 Linux Web App
- 1 Storage Account + 1 Container
- 1 Managed Identity
- 1 Azure OpenAI + 2 Model Deployments
- 1 AI Search Service
- 1 Cosmos DB + Database + 4 Containers
- 1 Document Intelligence
- 1 Bot Service + 1 Teams Channel
- 1 App Registration + Service Principal
- ~10 RBAC Role Assignments

### Step 4: Apply Configuration

```bash
terraform apply tfplan
```

Deployment time: ~15-20 minutes

### Step 5: Capture Outputs

```bash
terraform output > outputs.txt
cat outputs.txt
```

Important outputs:
- `web_app_url` - Your bot webhook URL
- `bot_app_id` - Use in Teams manifest
- `resource_group_name` - For subsequent commands

---

## Post-Deployment Steps

After Terraform completes, follow these steps in order:

1. **Create AI Search Index**
   ```bash
   python scripts/setup_search_index.py
   ```

2. **Initialize Cosmos DB Settings**
   ```bash
   python scripts/initialize_settings.py
   ```

3. **Deploy Application Code**
   ```bash
   cd application/single_app
   zip -r ../../deploy.zip .
   cd ../..
   az webapp deployment source config-zip \
     --resource-group $(terraform output -raw resource_group_name) \
     --name $(terraform output -raw web_app_url | cut -d'/' -f3 | cut -d'.' -f1) \
     --src deploy.zip
   ```

4. **Upload HR Documents**
   ```bash
   az storage blob upload-batch \
     --account-name $(terraform output -raw storage_account_name) \
     --destination public-documents \
     --source ./hr_documents/ \
     --auth-mode login
   ```

5. **Run Document Ingestion**
   ```bash
   python scripts/ingest_hr_documents.py
   ```

6. **Create Teams Manifest**
   - Use `bot_app_id` from outputs
   - See [DEPLOYMENT.md](../../DEPLOYMENT.md) Phase 4

---

## Verify Deployment

```bash
# Check bot endpoint
curl $(terraform output -raw web_app_url)/api/teams/health

# Expected: {"status": "healthy"}
```

---

## Update Configuration

To change resources after deployment:

```bash
# Edit terraform.tfvars
nano terraform.tfvars

# Plan changes
terraform plan

# Apply changes
terraform apply
```

---

## Destroy Resources

To remove all deployed resources:

```bash
terraform destroy
```

⚠️ **Warning:** This will delete all resources including data in Cosmos DB and Storage!

---

## Troubleshooting

### Terraform Errors

**Error: "User not found"**
- Ensure `param_resource_owner_email_id` exists in your tenant
- Verify with: `az ad user show --id "email@company.gov"`

**Error: "Name already exists"**
- Change `param_base_name` to something unique
- Resource names must be globally unique (storage, openai, search)

**Error: "Insufficient permissions"**
- Ensure you have permissions to create App Registrations
- May require Global Administrator or Application Administrator role

### Deployment Issues

**Bot not responding in Teams:**
- Check App Service logs: `az webapp log tail`
- Verify bot endpoint is reachable
- Confirm Teams channel is enabled

**Documents not found:**
- Run AI Search index creation
- Verify documents were uploaded to blob storage
- Check document ingestion completed successfully

---

## Cost Optimization

**Development Environment:**
- Keep App Service on B1 ($13/month)
- Use Cosmos DB Serverless
- Minimize OpenAI usage with quotas

**Production Environment:**
- Upgrade to S1 App Service with autoscale
- Consider Cosmos DB provisioned throughput
- Upgrade AI Search to Standard tier

---

## Additional Resources

- **Main Deployment Guide:** [DEPLOYMENT.md](../../DEPLOYMENT.md)
- **Configuration Changes:** `application/single_app/CONFIG_MVP_CHANGES.md`
- **File Reorganization:** `REORGANIZATION_SUMMARY.md`
- **AI Search Index Schema:** `artifacts/ai_search-index-public.json`

---

## Support

For deployment issues:
1. Check [DEPLOYMENT.md](../../DEPLOYMENT.md) Troubleshooting section
2. Review Terraform error messages carefully
3. Verify all prerequisites are met
4. Check Azure Portal for resource status

---

**Version:** 2.0.0-mvp
**Last Updated:** December 15, 2025

### .tfvars

#### Azure Environment Variables

global_which_azure_platform = "AzureUSGovernment"
param_tenant_id = "6bc5b33e-bc05-493c-b076-8f8ce1331511"
param_subscription_id = "4c1ccd07-9ebc-4701-b87f-c249066e0911"
param_location = "usgovvirginia"

#### ACR Variables

acr_name = "acr8000"
acr_resource_group_name = "sc-emma1-sbx1-rg"
acr_username = "acr8000"
acr_password = "@YOUR_ACR_PASSWORD"
image_name = "simplechat:latest"

#### SimpleChat Variables

param_environment = "sbx"
param_base_name = "rudy1"

#### Open AI Variables

param_use_existing_openai_instance = "true"
param_existing_azure_openai_resource_name = "gregazureopenai1"
param_existing_azure_openai_resource_group_name = "azureopenairg"

#### Other Settings Variables

param_resource_owner_id = "Tom Jones"
param_resource_owner_email_id = "tom@somedomain.onmicrosoft.us"
param_create_entra_security_groups = "true"

### How to deploy with tfvars file

terraform plan -var-file="./params/rudy1.tfvars"
terraform apply -var-file="./params/rudy1.tfvars" -auto-approve
terraform destroy -var-file="./params/rudy1.tfvars" -auto-approve

## Post-Deployment Manual Steps

STEP 1) Configure Azure Search indexes:
Deploy index as json files to Azure Search: ai_search-index-group.json, ai_search-index-user.json via the portal.

STEP 2) Navigate to Web UI url in a browser.

In the web ui, click on "Admin" > "app settings" to configure your app settings.

**NOTE:** When configuring the GPT / Embeddings / Image Generation endpoints, the endpoint / key provided by Azure AI Foundry deployments will cause issues.
The provided Endpoint / Key will work when "Test GPT Connection" is executed, but fail to "Fetch GPT Models".  To work around this issue, edit the Endpoint URL to the name of the OpenAI service, Fetch the GPT Models, select models as needed, then revert the name back to the original endpoint.

EX:
- Azure OpenAI GPT Endpoint: https://northcentralus.api.cognitive.microsoft.com/openai/deployments/gpt-4o/chat/completions?api-version=2025-01-01-preview

Revise to:

- Azure OpenAI GPT Endpoint: https://`<my-openaisvc-01`>.api.cognitive.microsoft.com/openai/deployments/gpt-4o/chat/completions?api-version=2025-01-01-preview
- Save pending change
- Fetch GPT Models & select required models
- Save pending change
- Revert OpenAI GPT Endpoint: https://northcentralus.api.cognitive.microsoft.com/openai/deployments/gpt-4o/chat/completions?api-version=2025-01-01-preview
- Save pending change

STEP 3) Test Web UI fully.

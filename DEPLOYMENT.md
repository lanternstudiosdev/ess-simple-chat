# Teams HR Bot - Deployment Guide

Complete guide to deploy your stateless HR Teams bot to Azure using Terraform.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Phase 1: Terraform Deployment](#phase-1-terraform-deployment)
4. [Phase 2: Post-Deployment Configuration](#phase-2-post-deployment-configuration)
5. [Phase 3: Document Ingestion](#phase-3-document-ingestion)
6. [Phase 4: Teams Integration](#phase-4-teams-integration)
7. [Phase 5: Testing](#phase-5-testing)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

- **Azure CLI** (version 2.50.0 or later)
  ```bash
  az version
  az login
  ```

- **Terraform** (version 1.12.0 or later)
  ```bash
  terraform version
  ```

- **Python 3.11+** (for local testing)
  ```bash
  python --version
  ```

### Azure Requirements

- Azure subscription (Commercial or Government)
- Permissions to create resources:
  - Resource Groups
  - App Registrations (Entra ID)
  - Azure OpenAI, AI Search, Cosmos DB, Storage, App Service
  - Bot Service

### Knowledge Base Requirements

- HR policy documents (PDF, DOCX format)
- Azure Storage access for document upload

---

## Architecture Overview

### Essential Azure Resources (MVP)

| Resource | Purpose | SKU | Monthly Cost |
|----------|---------|-----|--------------|
| **App Service** | Host Flask bot webhook | B1 | ~$13 |
| **Azure OpenAI** | GPT-4o + embeddings | S0 | Pay-per-use (~$20-50) |
| **AI Search** | Vector + hybrid search | Basic | ~$75 |
| **Cosmos DB** | Settings + document metadata | Serverless | ~$5-10 |
| **Storage Account** | HR document storage | Standard LRS | ~$1-2 |
| **Document Intelligence** | PDF/DOCX text extraction | S0 | Pay-per-page |
| **Bot Service** | Teams channel integration | F0 (Free) | $0 |
| **App Registration** | Bot authentication | N/A | $0 |

**Total Estimated Cost: ~$115-150/month**

### Cosmos DB Containers (4 only)

1. `settings` - Bot configuration
2. `public_workspaces` - HR workspace metadata
3. `public_documents` - HR document metadata
4. `file_processing` - Ingestion tracking (optional)

### Storage Blob Containers (3)

1. `public-documents` - HR documents
2. `user-documents` - (commented out, for future)
3. `group-documents` - (commented out, for future)

---

## Phase 1: Terraform Deployment

### Step 1.1: Configure Azure CLI

```bash
# For Azure Commercial
az cloud set --name AzureCloud
az login
az account set --subscription "your-subscription-id"

# For Azure Government
az cloud set --name AzureUSGovernment
az login --scope https://management.core.usgovcloudapi.net//.default
az account set --subscription "your-subscription-id"
```

### Step 1.2: Set Terraform Variables

Create `deployers/terraform/terraform.tfvars`:

```hcl
# Required Variables
param_subscription_id                = "your-subscription-id"
param_tenant_id                      = "your-tenant-id"
param_location                       = "usgovvirginia"  # or "eastus" for commercial
param_environment                    = "dev"
param_base_name                      = "hrbot"  # Short name (e.g., "hrbot", "contoso")
param_resource_owner_id              = "Your Name"
param_resource_owner_email_id        = "yourname@company.gov"

# Azure Platform Selection
global_which_azure_platform          = "AzureUSGovernment"  # or "AzureCloud"

# Azure OpenAI Configuration
param_use_existing_openai_instance   = false  # Set true if using existing OpenAI

# Bot Configuration (will be generated during deployment)
# hr_workspace_id                    = "hr-public-workspace"
```

**Note:** ACR-related variables removed as we're using direct App Service deployment.

### Step 1.3: Initialize Terraform

```bash
cd deployers/terraform
terraform init
```

### Step 1.4: Review Terraform Plan

```bash
terraform plan -out=tfplan
```

Review the resources to be created:
- ✅ Resource Group
- ✅ App Service Plan (B1)
- ✅ App Service (Linux, Python 3.11)
- ✅ Azure OpenAI + Model Deployments (gpt-4o, text-embedding-3-small)
- ✅ AI Search (Basic tier)
- ✅ Cosmos DB (Serverless) + 4 Containers
- ✅ Storage Account + 1 Blob Container (public-documents)
- ✅ Document Intelligence
- ✅ Bot Service Registration
- ✅ Teams Channel
- ✅ App Registration + Service Principal
- ✅ RBAC Assignments
- ❌ Key Vault (removed)
- ❌ Security Groups (removed)
- ❌ ACR (removed)

### Step 1.5: Deploy Infrastructure

```bash
terraform apply tfplan
```

Deployment time: ~15-20 minutes

### Step 1.6: Capture Outputs

```bash
# Save important values
terraform output -json > terraform-outputs.json

# Key outputs:
terraform output web_app_url
terraform output resource_group_name
```

---

## Phase 2: Post-Deployment Configuration

### Step 2.1: Configure Application Settings

The Terraform deployment sets most app settings automatically. Verify these are present:

```bash
RESOURCE_GROUP="hrbot-dev-rg"  # From terraform output
APP_NAME="hrbot-dev-app"       # From terraform output

az webapp config appsettings list \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --output table
```

Required settings (auto-configured by Terraform):
- `AZURE_COSMOS_ENDPOINT`
- `AZURE_COSMOS_KEY`
- `AZURE_OPENAI_URL`
- `AZURE_OPENAI_RESOURCE_NAME`
- `AZURE_SEARCH_SERVICE_NAME`
- `AZURE_SEARCH_API_KEY`
- `AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT`
- `AZURE_DOCUMENT_INTELLIGENCE_API_KEY`
- `MICROSOFT_APP_ID` (Bot app ID)
- `MICROSOFT_APP_PASSWORD` (Bot secret)
- `HR_WORKSPACE_ID` (default: "hr-public-workspace")
- `TENANT_ID`
- `CLIENT_ID`

### Step 2.2: Initialize AI Search Index

Create Python script locally: `scripts/setup_search_index.py`

```python
#!/usr/bin/env python3
"""
Create Azure AI Search index for HR documents.
Run this once after Terraform deployment.
"""
import os
import json
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import *
from azure.core.credentials import AzureKeyCredential

# Get from terraform outputs or Azure Portal
SEARCH_ENDPOINT = "https://hrbot-dev-search.search.windows.net"
SEARCH_KEY = "your-admin-key"

def create_hr_index():
    client = SearchIndexClient(
        endpoint=SEARCH_ENDPOINT,
        credential=AzureKeyCredential(SEARCH_KEY)
    )

    # Use the index schema from deployers/terraform/artifacts/ai_search-index-public.json
    with open('deployers/terraform/artifacts/ai_search-index-public.json', 'r') as f:
        index_schema = json.load(f)

    # Create index
    index = SearchIndex(
        name="simplechat-public-index",
        fields=[
            SearchField(name="id", type=SearchFieldDataType.String, key=True, filterable=True, retrievable=True),
            SearchField(name="chunk_text", type=SearchFieldDataType.String, searchable=True, retrievable=True),
            SearchField(name="embedding", type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
                       searchable=True, vector_search_dimensions=1536, vector_search_profile_name="vector-profile"),
            SearchField(name="file_name", type=SearchFieldDataType.String, searchable=True, filterable=True, retrievable=True),
            SearchField(name="public_workspace_id", type=SearchFieldDataType.String, filterable=True, retrievable=True),
            SearchField(name="document_id", type=SearchFieldDataType.String, filterable=True, retrievable=True),
            SearchField(name="chunk_id", type=SearchFieldDataType.String, retrievable=True),
            SearchField(name="page_number", type=SearchFieldDataType.Int32, filterable=True, retrievable=True),
        ],
        vector_search=VectorSearch(
            algorithms=[
                HnswAlgorithmConfiguration(name="hnsw-config", parameters=HnswParameters(metric="cosine"))
            ],
            profiles=[
                VectorSearchProfile(name="vector-profile", algorithm_configuration_name="hnsw-config")
            ]
        )
    )

    result = client.create_or_update_index(index)
    print(f"✅ Created index: {result.name}")

if __name__ == "__main__":
    create_hr_index()
```

Run the script:
```bash
python scripts/setup_search_index.py
```

### Step 2.3: Initialize Cosmos DB Settings

Create Python script: `scripts/initialize_settings.py`

```python
#!/usr/bin/env python3
"""
Initialize Cosmos DB with default settings and HR workspace.
Run once after Terraform deployment.
"""
import os
from azure.cosmos import CosmosClient

# Get from terraform outputs
COSMOS_ENDPOINT = "https://hrbot-dev-cosmos.documents.azure.us:443/"
COSMOS_KEY = "your-cosmos-key"
DATABASE_NAME = "SimpleChat"

def initialize_settings():
    client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
    database = client.get_database_client(DATABASE_NAME)

    # Initialize settings container
    settings_container = database.get_container_client("settings")
    settings_container.upsert_item({
        "id": "global_settings",
        "enable_teams_bot": True,
        "azure_openai_gpt_deployment": "gpt-4o",
        "azure_openai_embedding_deployment": "text-embedding-3-small",
        "enable_enhanced_citations": True,
        "azure_ai_search_endpoint": "https://hrbot-dev-search.search.windows.net",
        "azure_ai_search_authentication_type": "key"
    })
    print("✅ Initialized settings")

    # Initialize HR workspace
    workspaces_container = database.get_container_client("public_workspaces")
    workspaces_container.upsert_item({
        "id": "hr-public-workspace",
        "name": "HR Policies & Benefits",
        "description": "Company HR policies, benefits, and procedures",
        "created_at": "2025-01-01T00:00:00Z"
    })
    print("✅ Created HR workspace")

if __name__ == "__main__":
    initialize_settings()
```

Run the script:
```bash
python scripts/initialize_settings.py
```

### Step 2.4: Deploy Application Code

```bash
# Package application
cd application/single_app
zip -r ../../deploy.zip . -x "*.pyc" -x "__pycache__/*" -x "*.git*"

# Deploy to App Service
cd ../..
az webapp deployment source config-zip \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --src deploy.zip

# Monitor deployment
az webapp log tail --resource-group $RESOURCE_GROUP --name $APP_NAME
```

---

## Phase 3: Document Ingestion

### Step 3.1: Upload HR Documents to Blob Storage

```bash
STORAGE_ACCOUNT="hrbotdevsa"  # From terraform output
CONTAINER_NAME="public-documents"

# Upload documents
az storage blob upload-batch \
  --account-name $STORAGE_ACCOUNT \
  --destination $CONTAINER_NAME \
  --source ./hr_documents/ \
  --auth-mode login
```

### Step 3.2: Run Document Ingestion Script

Implementation needed in `application/single_app/scripts/ingest_hr_documents.py`:

```python
#!/usr/bin/env python3
"""
Ingest HR documents from Azure Blob Storage into AI Search index.
"""
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from azure.storage.blob import BlobServiceClient
from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
import config
from functions_content import extract_content_with_azure_di, generate_embedding
from functions_documents import save_chunk_to_index

def ingest_documents(container_name: str, workspace_id: str):
    """
    Ingest all documents from blob container into AI Search.
    """
    # Get blob service client
    blob_client = config.CLIENTS.get("storage_account_office_docs_client")
    container_client = blob_client.get_container_client(container_name)

    # List all blobs
    blobs = container_client.list_blobs()

    for blob in blobs:
        print(f"📄 Processing: {blob.name}")

        # Download blob
        blob_data = container_client.download_blob(blob.name).readall()

        # Extract text with Document Intelligence
        extracted_content = extract_content_with_azure_di(blob_data, blob.name)

        # Chunk by page
        for page_num, page_text in enumerate(extracted_content['pages'], start=1):
            if not page_text.strip():
                continue

            # Generate embedding
            embedding = generate_embedding(page_text)

            # Save to AI Search
            save_chunk_to_index(
                page_text_content=page_text,
                page_number=page_num,
                file_name=blob.name,
                document_id=blob.name.split('.')[0],
                public_workspace_id=workspace_id,
                embedding=embedding
            )
            print(f"  ✅ Page {page_num} indexed")

        print(f"✅ Completed: {blob.name}\n")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--container", default="public-documents")
    parser.add_argument("--workspace", default="hr-public-workspace")
    args = parser.parse_args()

    ingest_documents(args.container, args.workspace)
```

Run ingestion:
```bash
cd application/single_app
python scripts/ingest_hr_documents.py --container public-documents --workspace hr-public-workspace
```

---

## Phase 4: Teams Integration

### Step 4.1: Get Bot Details

```bash
# Get Bot App ID (from App Registration)
az ad app list --display-name "hrbot-dev-ar" --query "[0].appId" -o tsv
```

### Step 4.2: Create Teams Manifest

Create `teams_manifest/manifest.json`:

```json
{
  "$schema": "https://developer.microsoft.com/en-us/json-schemas/teams/v1.16/MicrosoftTeams.schema.json",
  "manifestVersion": "1.16",
  "version": "1.0.0",
  "id": "YOUR_BOT_APP_ID",
  "packageName": "com.company.hrbot",
  "developer": {
    "name": "Your Company",
    "websiteUrl": "https://yourcompany.com",
    "privacyUrl": "https://yourcompany.com/privacy",
    "termsOfUseUrl": "https://yourcompany.com/terms"
  },
  "name": {
    "short": "HR Bot",
    "full": "HR Policy & Benefits Assistant"
  },
  "description": {
    "short": "Ask questions about HR policies and benefits",
    "full": "Your AI-powered assistant for company HR policies, benefits, time off, and workplace procedures."
  },
  "icons": {
    "outline": "outline.png",
    "color": "color.png"
  },
  "accentColor": "#0078D4",
  "bots": [
    {
      "botId": "YOUR_BOT_APP_ID",
      "scopes": ["personal", "team"],
      "supportsFiles": false,
      "isNotificationOnly": false,
      "commandLists": [
        {
          "scopes": ["personal", "team"],
          "commands": [
            {
              "title": "help",
              "description": "Get help using the HR bot"
            },
            {
              "title": "status",
              "description": "Check bot status and document count"
            }
          ]
        }
      ]
    }
  ],
  "permissions": ["identity", "messageTeamMembers"],
  "validDomains": [
    "hrbot-dev-app.azurewebsites.us"
  ]
}
```

Replace `YOUR_BOT_APP_ID` with the actual Bot App ID from Step 4.1.

### Step 4.3: Create Teams App Package

```bash
cd teams_manifest

# Create simple 32x32 outline icon (outline.png)
# Create simple 192x192 color icon (color.png)
# Or use provided icons

# Create zip package
zip hrbot.zip manifest.json outline.png color.png
```

### Step 4.4: Upload to Teams

1. Open Microsoft Teams
2. Go to **Apps** → **Manage your apps** → **Upload an app**
3. Select **Upload a custom app**
4. Choose `hrbot.zip`
5. Click **Add** to install for yourself
6. Or click **Add to team** to install for a team

---

## Phase 5: Testing

### Step 5.1: Test Bot Endpoint

```bash
# Health check
curl https://hrbot-dev-app.azurewebsites.us/api/teams/health

# Expected: {"status": "healthy"}
```

### Step 5.2: Test in Teams

Send messages to the bot:

```
Test Query 1: "What is the vacation policy?"
Expected: Detailed response with citations from HR documents

Test Query 2: "/help"
Expected: Help message with available commands

Test Query 3: "/status"
Expected: Bot status with document count
```

### Step 5.3: Verify Document Count

```bash
# Check AI Search document count
az search query-key list \
  --resource-group $RESOURCE_GROUP \
  --service-name hrbot-dev-search

# Use key to query index
curl -X GET "https://hrbot-dev-search.search.windows.net/indexes/simplechat-public-index/docs/\$count?api-version=2023-11-01" \
  -H "api-key: YOUR_QUERY_KEY"
```

---

## Troubleshooting

### Bot Not Responding in Teams

**Check:**
1. Bot endpoint is reachable: `curl https://your-app.azurewebsites.us/api/messages`
2. Bot token validation: Check App Service logs for "Invalid bot token" errors
3. Teams channel is enabled in Bot Service
4. App Registration client secret hasn't expired

**Fix:**
```bash
# Check App Service logs
az webapp log tail --resource-group $RESOURCE_GROUP --name $APP_NAME

# Restart App Service
az webapp restart --resource-group $RESOURCE_GROUP --name $APP_NAME
```

### "HR Knowledge Base not found" Error

**Issue:** HR workspace not initialized in Cosmos DB

**Fix:**
```bash
python scripts/initialize_settings.py
```

### No Documents Found in Search

**Issue:** Documents not ingested or AI Search index not created

**Check:**
```bash
# Verify blobs uploaded
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name public-documents \
  --auth-mode login

# Verify index exists
az search index list \
  --resource-group $RESOURCE_GROUP \
  --service-name hrbot-dev-search
```

**Fix:**
```bash
# Re-run ingestion
python scripts/ingest_hr_documents.py
```

### OpenAI Deployment Errors

**Issue:** Model deployments not created or wrong model names

**Check:**
```bash
az cognitiveservices account deployment list \
  --resource-group $RESOURCE_GROUP \
  --name hrbot-dev-oai
```

**Expected deployments:**
- `gpt-4o` (model: gpt-4o, version: 2024-05-13)
- `text-embedding-3-small` (model: text-embedding-3-small)

### Cosmos DB Connection Errors

**Check:**
```bash
# Verify Cosmos DB exists
az cosmosdb show \
  --resource-group $RESOURCE_GROUP \
  --name hrbot-dev-cosmos

# Check firewall rules
az cosmosdb show \
  --resource-group $RESOURCE_GROUP \
  --name hrbot-dev-cosmos \
  --query "ipRules"
```

**Fix:** Ensure App Service has network access to Cosmos DB (should be automatic with RBAC).

---

## Cost Optimization

### Development Environment
- App Service: B1 ($13/month)
- Cosmos DB: Serverless (minimal usage: ~$5/month)
- AI Search: Basic ($75/month)
- Total: ~$100-120/month

### Production Environment
- App Service: S1 with autoscale ($70-200/month)
- Cosmos DB: Provisioned throughput ($25-50/month)
- AI Search: Standard ($250/month)
- Total: ~$350-500/month

---

## Security Best Practices

1. **Rotate Bot Secrets Regularly**
   ```bash
   az ad app credential reset --id $APP_ID
   ```

2. **Enable Managed Identity**
   - Update Terraform to use Managed Identity for Azure services
   - Remove API keys from app settings

3. **Network Security**
   - Enable Private Endpoints for Cosmos DB and Storage (production)
   - Configure App Service VNet integration

4. **Monitor Access**
   ```bash
   az monitor activity-log list --resource-group $RESOURCE_GROUP
   ```

---

## Next Steps

- [ ] Set up Application Insights dashboards
- [ ] Configure alerting for bot errors
- [ ] Implement conversation history (uncomment containers in config.py)
- [ ] Add more HR documents
- [ ] Train users on bot capabilities
- [ ] Collect feedback and iterate

---

## Support

For issues with this deployment:
1. Check Application Insights logs
2. Review App Service logs: `az webapp log tail`
3. Verify all Terraform outputs are correct
4. Consult Azure documentation for specific services

---

**Version:** 1.0.0
**Last Updated:** December 15, 2025

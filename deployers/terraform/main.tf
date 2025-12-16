####################################################################################################
# File:         main.tf
# Description:  Terraform configuration for deploying Teams HR Bot MVP to Azure
# Author:       Modified for Teams Bot MVP
# Created:      2025-Dec-15
# Version:      <v2.0.0-mvp>
####################################################################################################
#
# Disclaimer:
#
# - This script is provided as-is and is not officially supported by Microsoft.
# - It is intended for educational purposes and may require modifications to fit specific use cases.
# - Ensure you have the necessary permissions and configurations in your Azure environment before deploying.
#
# Notes:
#
# - Streamlined for stateless Teams HR bot MVP
# - Removed: Key Vault, Security Groups, ACR dependencies
# - Added: Bot Service, Teams Channel, OpenAI Deployments, Cosmos Containers, Blob Containers
#
####################################################################################################

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.29, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1.0"
    }
  }
}

# Configure the AzureRM Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
  storage_use_azuread = true
  environment         = var.global_which_azure_platform == "AzureUSGovernment" ? "usgovernment" : (var.global_which_azure_platform == "AzureCloud" ? "public" : null)
  tenant_id           = var.param_tenant_id
  subscription_id     = var.param_subscription_id
}

# Configure the AzureAD Provider
provider "azuread" {
  environment = var.global_which_azure_platform == "AzureUSGovernment" ? "usgovernment" : (var.global_which_azure_platform == "AzureCloud" ? "public" : null)
  tenant_id   = var.param_tenant_id
}

####################################################################################################
# VARIABLES
####################################################################################################

variable "global_which_azure_platform" {
  description = "Set to 'AzureUSGovernment' for Azure Government, 'AzureCloud' for Azure Commercial."
  type        = string
  default     = "AzureUSGovernment"
  validation {
    condition     = contains(["AzureUSGovernment", "AzureCloud"], var.global_which_azure_platform)
    error_message = "Invalid Azure platform. Must be 'AzureUSGovernment' or 'AzureCloud'."
  }
}

variable "param_subscription_id" {
  description = "Your Azure Subscription ID."
  type        = string
}

variable "param_tenant_id" {
  description = "Your Azure AD Tenant ID."
  type        = string
}

variable "param_location" {
  description = "Primary Azure region for deployments (e.g., usgovvirginia, eastus)."
  type        = string
}

variable "param_resource_owner_id" {
  description = "Used for tagging resources (e.g., John Doe)."
  type        = string
}

variable "param_resource_owner_email_id" {
  description = "Used for tagging resources (e.g., john@company.gov)."
  type        = string
}

variable "param_environment" {
  description = "Environment identifier (e.g., dev, test, prod)."
  type        = string
}

variable "param_base_name" {
  description = "A short base name for your project (e.g., hrbot, contoso)."
  type        = string
}

variable "param_use_existing_openai_instance" {
  description = "Set to true to use an existing Azure OpenAI instance."
  type        = bool
  default     = false
}

variable "param_existing_azure_openai_resource_name" {
  description = "Existing Azure OpenAI resource name (if using existing)."
  type        = string
  default     = ""
}

variable "param_existing_azure_openai_resource_group_name" {
  description = "Existing Azure OpenAI resource group name (if using existing)."
  type        = string
  default     = ""
}

variable "hr_workspace_id" {
  description = "ID for the HR public workspace."
  type        = string
  default     = "hr-public-workspace"
}

####################################################################################################
# LOCAL VARIABLES
####################################################################################################

locals {
  resource_group_name     = "sc-${var.param_base_name}-${var.param_environment}-rg"
  app_registration_name   = "${var.param_base_name}-${var.param_environment}-ar"
  app_service_plan_name   = "${var.param_base_name}-${var.param_environment}-asp"
  app_service_name        = "${var.param_base_name}-${var.param_environment}-app"
  app_insights_name       = "${var.param_base_name}-${var.param_environment}-ai"
  cosmos_db_name          = "${var.param_base_name}-${var.param_environment}-cosmos"
  open_ai_name            = "${var.param_base_name}-${var.param_environment}-oai"
  doc_intel_name          = "${var.param_base_name}-${var.param_environment}-docintel"
  log_analytics_name      = "${var.param_base_name}-${var.param_environment}-la"
  managed_identity_name   = "${var.param_base_name}-${var.param_environment}-id"
  search_service_name     = "${var.param_base_name}-${var.param_environment}-search"
  bot_service_name        = "${var.param_base_name}-${var.param_environment}-bot"
  storage_account_base    = "${var.param_base_name}${var.param_environment}sa"
  storage_account_name    = substr(replace(local.storage_account_base, "/[^a-z0-9]/", ""), 0, 24)

  app_service_fqdn_suffix = var.global_which_azure_platform == "AzureUSGovernment" ? ".azurewebsites.us" : ".azurewebsites.net"
  cosmos_db_url_template  = var.global_which_azure_platform == "AzureUSGovernment" ? "https://%s.documents.azure.us:443/" : "https://%s.documents.azure.com:443/"
  openai_url_template     = var.global_which_azure_platform == "AzureUSGovernment" ? "https://%s.openai.azure.us/" : "https://%s.openai.azure.com/"

  common_tags = {
    Environment     = var.param_environment
    Owner           = var.param_resource_owner_id
    CreatedDateTime = formatdate("YYYY-MM-DD", timestamp())
    Project         = "TeamsHRBot"
  }
}

####################################################################################################
# DATA SOURCES
####################################################################################################

data "azuread_user" "owner_user" {
  user_principal_name = var.param_resource_owner_email_id
}

data "azuread_client_config" "current" {}

data "azurerm_cognitive_account" "existing_openai" {
  count               = var.param_use_existing_openai_instance ? 1 : 0
  name                = var.param_existing_azure_openai_resource_name
  resource_group_name = var.param_existing_azure_openai_resource_group_name
}

####################################################################################################
# RESOURCE GROUP
####################################################################################################

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.param_location
  tags     = local.common_tags
}

####################################################################################################
# LOG ANALYTICS & APPLICATION INSIGHTS
####################################################################################################

resource "azurerm_log_analytics_workspace" "la" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  tags                = local.common_tags
}

resource "azurerm_application_insights" "ai" {
  name                = local.app_insights_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.la.id
  tags                = local.common_tags
}

####################################################################################################
# STORAGE ACCOUNT & BLOB CONTAINERS
####################################################################################################

resource "azurerm_storage_account" "sa" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  access_tier                     = "Hot"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true # Enable for App Service access
  shared_access_key_enabled       = false
  tags                            = local.common_tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

# Blob container for HR documents
resource "azurerm_storage_container" "public_documents" {
  name                  = "public-documents"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

####################################################################################################
# MANAGED IDENTITY
####################################################################################################

resource "azurerm_user_assigned_identity" "id" {
  name                = local.managed_identity_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

####################################################################################################
# APP SERVICE PLAN & WEB APP
####################################################################################################

resource "azurerm_service_plan" "asp" {
  name                = local.app_service_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1" # Basic tier for MVP (~$13/month)
  tags                = local.common_tags
}

resource "azurerm_linux_web_app" "app" {
  name                                           = local.app_service_name
  location                                       = azurerm_resource_group.rg.location
  resource_group_name                            = azurerm_resource_group.rg.name
  service_plan_id                                = azurerm_service_plan.asp.id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  app_settings = {
    "AZURE_ENDPOINT"                               = var.global_which_azure_platform == "AzureUSGovernment" ? "usgovernment" : "public"
    "AZURE_ENVIRONMENT"                            = var.global_which_azure_platform == "AzureUSGovernment" ? "usgovernment" : "public"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"               = "true"
    "AZURE_COSMOS_AUTHENTICATION_TYPE"             = "key"
    "AZURE_COSMOS_ENDPOINT"                        = format(local.cosmos_db_url_template, azurerm_cosmosdb_account.cosmos.name)
    "AZURE_COSMOS_KEY"                             = azurerm_cosmosdb_account.cosmos.primary_key
    "TENANT_ID"                                    = var.param_tenant_id
    "CLIENT_ID"                                    = azuread_application.app_registration.client_id
    "SECRET_KEY"                                   = random_password.secret_key.result
    "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"     = azuread_application_password.app_registration_secret.value
    "AZURE_OPENAI_RESOURCE_NAME"                   = var.param_use_existing_openai_instance ? var.param_existing_azure_openai_resource_name : azurerm_cognitive_account.openai[0].name
    "AZURE_OPENAI_RESOURCE_GROUP_NAME"             = var.param_use_existing_openai_instance ? var.param_existing_azure_openai_resource_group_name : azurerm_resource_group.rg.name
    "AZURE_OPENAI_URL"                             = var.param_use_existing_openai_instance ? format(local.openai_url_template, var.param_existing_azure_openai_resource_name) : format(local.openai_url_template, azurerm_cognitive_account.openai[0].name)
    "AZURE_SEARCH_SERVICE_NAME"                    = azurerm_search_service.search.name
    "AZURE_SEARCH_API_KEY"                         = azurerm_search_service.search.primary_key
    "AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT"         = azurerm_cognitive_account.docintel.endpoint
    "AZURE_DOCUMENT_INTELLIGENCE_API_KEY"          = azurerm_cognitive_account.docintel.primary_access_key
    "APPINSIGHTS_INSTRUMENTATIONKEY"               = azurerm_application_insights.ai.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING"        = azurerm_application_insights.ai.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION"   = "~3"
    "MICROSOFT_APP_ID"                             = azuread_application.app_registration.client_id
    "MICROSOFT_APP_PASSWORD"                       = azuread_application_password.app_registration_secret.value
    "MICROSOFT_APP_TYPE"                           = "MultiTenant"
    "MICROSOFT_APP_TENANT_ID"                      = var.param_tenant_id
    "TEAMS_BOT_APP_ID"                             = azuread_application.app_registration.client_id
    "TEAMS_BOT_APP_PASSWORD"                       = azuread_application_password.app_registration_secret.value
    "HR_WORKSPACE_ID"                              = var.hr_workspace_id
  }

  site_config {
    always_on                         = true
    minimum_tls_version               = "1.2"
    container_registry_use_managed_identity = false

    application_stack {
      python_version = "3.11"
    }
  }

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.id.id]
  }

  tags = local.common_tags
}

# Generate random secret key for Flask
resource "random_password" "secret_key" {
  length  = 32
  special = true
}

####################################################################################################
# ENTRA APP REGISTRATION & SERVICE PRINCIPAL
####################################################################################################

resource "azuread_application" "app_registration" {
  display_name = local.app_registration_name
  owners       = [data.azuread_client_config.current.object_id, data.azuread_user.owner_user.object_id]

  web {
    redirect_uris = [
      "https://${local.app_service_name}${local.app_service_fqdn_suffix}/.auth/login/aad/callback",
    ]
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }
}

resource "azuread_application_password" "app_registration_secret" {
  application_id = azuread_application.app_registration.id
  rotate_when_changed = {
    rotation = 180
  }
}

resource "azuread_service_principal" "app_registration_sp" {
  client_id = azuread_application.app_registration.client_id
  owners    = [data.azuread_user.owner_user.object_id]
}

####################################################################################################
# COSMOS DB (Serverless with 4 containers)
####################################################################################################

resource "azurerm_cosmosdb_account" "cosmos" {
  name                = local.cosmos_db_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "GlobalDocumentDB"
  offer_type          = "Standard"

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }

  tags = local.common_tags
}

resource "azurerm_cosmosdb_sql_database" "db" {
  name                = "SimpleChat"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

# Essential containers for stateless Teams bot
resource "azurerm_cosmosdb_sql_container" "settings" {
  name                  = "settings"
  resource_group_name   = azurerm_resource_group.rg.name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.db.name
  partition_key_paths   = ["/id"]
  partition_key_version = 1
}

resource "azurerm_cosmosdb_sql_container" "public_workspaces" {
  name                  = "public_workspaces"
  resource_group_name   = azurerm_resource_group.rg.name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.db.name
  partition_key_paths   = ["/id"]
  partition_key_version = 1
}

resource "azurerm_cosmosdb_sql_container" "public_documents" {
  name                  = "public_documents"
  resource_group_name   = azurerm_resource_group.rg.name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.db.name
  partition_key_paths   = ["/id"]
  partition_key_version = 1
}

resource "azurerm_cosmosdb_sql_container" "file_processing" {
  name                  = "file_processing"
  resource_group_name   = azurerm_resource_group.rg.name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.db.name
  partition_key_paths   = ["/document_id"]
  partition_key_version = 1
}

####################################################################################################
# AZURE OPENAI & MODEL DEPLOYMENTS
####################################################################################################

resource "azurerm_cognitive_account" "openai" {
  count               = var.param_use_existing_openai_instance ? 0 : 1
  name                = local.open_ai_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "OpenAI"
  sku_name            = "S0"
  tags                = local.common_tags
}

# GPT-4o deployment
resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = var.param_use_existing_openai_instance ? data.azurerm_cognitive_account.existing_openai[0].id : azurerm_cognitive_account.openai[0].id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-05-13"
  }

  sku {
    name     = "Standard"
    capacity = 10
  }
}

# Text embedding deployment
resource "azurerm_cognitive_deployment" "embeddings" {
  name                 = "text-embedding-3-small"
  cognitive_account_id = var.param_use_existing_openai_instance ? data.azurerm_cognitive_account.existing_openai[0].id : azurerm_cognitive_account.openai[0].id

  model {
    format  = "OpenAI"
    name    = "text-embedding-3-small"
    version = "1"
  }

  sku {
    name     = "Standard"
    capacity = 10
  }
}

####################################################################################################
# DOCUMENT INTELLIGENCE
####################################################################################################

resource "azurerm_cognitive_account" "docintel" {
  name                  = local.doc_intel_name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  kind                  = "FormRecognizer"
  sku_name              = "S0"
  custom_subdomain_name = local.doc_intel_name
  tags                  = local.common_tags
}

####################################################################################################
# AZURE AI SEARCH
####################################################################################################

resource "azurerm_search_service" "search" {
  name                          = local.search_service_name
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  sku                           = "basic"
  replica_count                 = 1
  partition_count               = 1
  semantic_search_sku           = "standard"
  public_network_access_enabled = true
  tags                          = local.common_tags
}

####################################################################################################
# AZURE BOT SERVICE & TEAMS CHANNEL
####################################################################################################

resource "azurerm_bot_service_azure_bot" "bot" {
  name                = local.bot_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = "global"
  sku                 = "F0" # Free tier
  microsoft_app_id    = azuread_application.app_registration.client_id
  endpoint            = "https://${local.app_service_name}${local.app_service_fqdn_suffix}/api/messages"
  tags                = local.common_tags

  depends_on = [
    azurerm_linux_web_app.app,
    azuread_application.app_registration
  ]
}

resource "azurerm_bot_channel_ms_teams" "teams" {
  bot_name            = azurerm_bot_service_azure_bot.bot.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_bot_service_azure_bot.bot.location
}

####################################################################################################
# RBAC ASSIGNMENTS
####################################################################################################

# Managed Identity: OpenAI Contributor
resource "azurerm_role_assignment" "managed_identity_openai_contributor" {
  scope                = var.param_use_existing_openai_instance ? data.azurerm_cognitive_account.existing_openai[0].id : azurerm_cognitive_account.openai[0].id
  role_definition_name = "Cognitive Services Contributor"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# Managed Identity: OpenAI User
resource "azurerm_role_assignment" "managed_identity_openai_user" {
  scope                = var.param_use_existing_openai_instance ? data.azurerm_cognitive_account.existing_openai[0].id : azurerm_cognitive_account.openai[0].id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# Managed Identity: Cosmos DB Contributor
resource "azurerm_role_assignment" "managed_identity_cosmosdb_contributor" {
  scope                = azurerm_cosmosdb_account.cosmos.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# Managed Identity: Storage Blob Data Contributor
resource "azurerm_role_assignment" "managed_identity_storage_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# App Service System Identity: OpenAI User
resource "azurerm_role_assignment" "app_service_smi_openai_user" {
  scope                = var.param_use_existing_openai_instance ? data.azurerm_cognitive_account.existing_openai[0].id : azurerm_cognitive_account.openai[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# App Service System Identity: Storage Blob Data Contributor
resource "azurerm_role_assignment" "app_service_smi_storage_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# Service Principal: OpenAI Contributor
resource "azurerm_role_assignment" "app_reg_sp_openai_contributor" {
  scope                = var.param_use_existing_openai_instance ? data.azurerm_cognitive_account.existing_openai[0].id : azurerm_cognitive_account.openai[0].id
  role_definition_name = "Cognitive Services OpenAI Contributor"
  principal_id         = azuread_service_principal.app_registration_sp.object_id
}

####################################################################################################
# OUTPUTS
####################################################################################################

output "resource_group_name" {
  description = "Name of the created Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "web_app_url" {
  description = "The URL of the deployed App Service"
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "bot_app_id" {
  description = "The Microsoft App ID for the bot"
  value       = azuread_application.app_registration.client_id
}

output "bot_endpoint" {
  description = "The webhook endpoint for the bot"
  value       = azurerm_bot_service_azure_bot.bot.endpoint
}

output "cosmos_endpoint" {
  description = "Cosmos DB endpoint"
  value       = azurerm_cosmosdb_account.cosmos.endpoint
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint"
  value       = var.param_use_existing_openai_instance ? format(local.openai_url_template, var.param_existing_azure_openai_resource_name) : format(local.openai_url_template, azurerm_cognitive_account.openai[0].name)
}

output "search_service_name" {
  description = "Azure AI Search service name"
  value       = azurerm_search_service.search.name
}

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.sa.name
}

output "deployment_instructions" {
  description = "Next steps for deployment"
  value = <<-EOT

  ✅ Infrastructure deployed successfully!

  📋 Next Steps:
  1. Create AI Search index: python scripts/setup_search_index.py
  2. Initialize Cosmos DB: python scripts/initialize_settings.py
  3. Deploy app code: az webapp deployment source config-zip --src deploy.zip
  4. Upload HR documents to blob storage
  5. Run document ingestion: python scripts/ingest_hr_documents.py
  6. Create Teams manifest and upload to Teams

  📖 See DEPLOYMENT.md for detailed instructions

  EOT
}

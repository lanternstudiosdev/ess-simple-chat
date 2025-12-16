# Archived Complex Features

This directory contains complex features from the original web application that are **not needed** for the Teams HR Bot MVP.

Files are organized by area of concern for easy reference and potential future restoration.

## Directory Structure

### 🤖 `agent_orchestration/`
Multi-agent orchestration systems (Magnetic, GroupChat)
- Complex agent coordination
- Agent logging and citations
- Not needed: Teams bot uses simple single-response pattern

### 🧠 `semantic_kernel/`
Semantic Kernel initialization and memory management
- Per-user kernel management
- Fact memory storage
- Not needed: Teams bot uses direct GPT calls

### 🔐 `web_authentication/`
Session-based web authentication
- MSAL authentication flows
- Session management
- Not needed: Teams uses Bot Framework authentication

### 💬 `conversation_management/`
Complex multi-turn conversation management
- 2034-line route_backend_chats.py
- Conversation metadata extraction
- Multi-turn history management
- Not needed: Teams bot MVP is single-shot Q&A

### 👥 `group_management/`
Group workspace functionality
- Group creation/management
- Group documents
- Group prompts
- Not needed: Teams bot uses public workspace only

### 🎭 `agent_management/`
Agent CRUD and configuration
- Personal agents
- Global agents
- Agent-plugin associations
- Not needed: No agent system in Teams MVP

### 🔌 `plugin_system/`
Plugin management and validation
- Dynamic plugin loading
- Plugin validation endpoints
- Not needed: No plugin system in Teams MVP

### 📋 `openapi_validation/`
OpenAPI/Swagger integration
- OpenAPI security analysis
- JSON schema validation
- Swagger documentation generation
- Not needed: Teams bot has simple REST webhook

### 📝 `prompt_management/`
Prompt template management
- User prompts
- Public prompts
- Prompt CRUD
- Not needed: Teams bot uses hardcoded system prompts

### ✨ `enhanced_features/`
Advanced optional features
- User management
- Feedback collection
- Content safety
- Enhanced citations
- Database migrations
- Not needed for MVP

## Teams Bot Simplified Stack

**What We Keep:**
- ✅ `config.py` - Azure service configs
- ✅ `app.py` - Flask app (simplified)
- ✅ `chat_engine.py` - Reusable chat logic
- ✅ `route_teams_bot.py` - Teams webhook
- ✅ `functions_teams_bot.py` - Bot business logic
- ✅ `functions_search.py` - Hybrid search
- ✅ `functions_documents.py` - Document processing
- ✅ `functions_content.py` - Embedding/extraction
- ✅ `functions_public_workspaces.py` - HR workspace
- ✅ `functions_settings.py` - App settings
- ✅ `functions_appinsights.py` - Logging
- ✅ `scripts/ingest_hr_documents.py` - Doc ingestion

**Architecture:**
```
Employee asks in Teams
↓
Teams Bot Framework
↓
route_teams_bot.py webhook
↓
chat_engine.py (perform_search + generate_completion)
↓
Hybrid search → GPT-4 + RAG → Response with citations
↓
Back to Teams
```

---
**Archived:** December 15, 2025
**Reason:** Teams HR Bot MVP - Remove complexity
**Status:** Preserved by concern area for reference

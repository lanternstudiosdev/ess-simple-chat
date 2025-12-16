# Configuration Changes for Teams HR Bot MVP

## Date: December 15, 2025
## Version: 0.229.099

---

## Summary

Streamlined `config.py` for stateless Teams HR bot MVP by commenting out 22 unnecessary Cosmos DB containers while preserving them for future use.

---

## Active Cosmos DB Containers (4)

### Essential Containers
1. ✅ **settings** - Bot configuration and feature flags
   - Partition Key: `/id`
   - Purpose: Application settings, enable_teams_bot flag

2. ✅ **public_workspaces** - HR workspace metadata
   - Partition Key: `/id`
   - Purpose: HR knowledge base configuration

3. ✅ **public_documents** - HR document metadata
   - Partition Key: `/id`
   - Purpose: Track uploaded HR documents (PDFs, DOCX)

4. ✅ **file_processing** - Document ingestion tracking (optional)
   - Partition Key: `/document_id`
   - Purpose: Monitor document processing pipeline status

---

## Commented Out Containers (22)

### Stateful Conversation Support (2 containers)
Enable these for multi-turn conversations with history:
- `conversations` - Conversation metadata
- `messages` - Individual message history

### Group Collaboration (7 containers)
Not needed for individual HR bot queries:
- `groups`
- `group_documents`
- `group_prompts`
- `group_messages`
- `group_conversations`
- `group_agents`
- `group_actions`

### User-Specific Features (3 containers)
Not needed for stateless bot:
- `documents` (user documents)
- `user_settings`
- `prompts` (user prompts)

### Agent Orchestration (6 containers)
Archived multi-agent system features:
- `personal_agents`
- `personal_actions`
- `global_agents`
- `global_actions`
- `agent_facts`

### Additional Features (4 containers)
Future enhancements:
- `safety` - Content safety violations
- `feedback` - User feedback
- `archived_conversations`
- `archived_messages`
- `public_prompts`

---

## New Configuration Constants

Added at end of Cosmos DB section:

```python
# Teams Bot Framework Authentication
TEAMS_BOT_APP_ID = os.getenv('TEAMS_BOT_APP_ID', '')
TEAMS_BOT_APP_PASSWORD = os.getenv('TEAMS_BOT_APP_PASSWORD', '')

# HR Workspace Configuration
HR_WORKSPACE_ID = os.getenv('HR_WORKSPACE_ID', 'hr-public-workspace')
```

---

## Environment Variables Required

Add to `.env` file:

```bash
# Teams Bot Configuration
TEAMS_BOT_APP_ID=your-bot-app-id-here
TEAMS_BOT_APP_PASSWORD=your-bot-client-secret-here
HR_WORKSPACE_ID=hr-public-workspace
```

---

## Cost Impact

**Before (26 containers):**
- Cosmos DB: ~$25-50/month (many containers, minimal usage)

**After (4 containers):**
- Cosmos DB Serverless: ~$5-10/month
- **Savings: ~$15-40/month**

---

## Migration Path

### To Enable Multi-Turn Conversations:

1. Uncomment in `config.py`:
   ```python
   cosmos_conversations_container_name = "conversations"
   cosmos_conversations_container = cosmos_database.create_container_if_not_exists(...)
   
   cosmos_messages_container_name = "messages"
   cosmos_messages_container = cosmos_database.create_container_if_not_exists(...)
   ```

2. Update `functions_teams_bot.py`:
   - Modify `handle_bot_query()` to save/retrieve conversation history
   - Use `chat_engine.build_chat_history()` method

3. Restart application

---

## Benefits

### Simplified Architecture
- ✅ 85% reduction in Cosmos DB containers (26 → 4)
- ✅ Lower complexity
- ✅ Easier debugging
- ✅ Faster startup

### Cost Optimization
- ✅ Lower Cosmos DB costs
- ✅ Fewer container operations
- ✅ Reduced storage

### Clear Upgrade Path
- ✅ All containers preserved as comments
- ✅ Easy to enable stateful features
- ✅ Well-documented sections

---

## Testing Checklist

- [ ] App starts without errors
- [ ] `cosmos_settings_container` accessible
- [ ] `cosmos_public_workspaces_container` accessible
- [ ] `cosmos_public_documents_container` accessible
- [ ] `cosmos_file_processing_container` accessible
- [ ] Teams bot endpoint responds to queries
- [ ] Document ingestion saves to correct containers

---

## Related Files

- `config.py` - Main configuration (updated)
- `route_teams_bot.py` - Uses `HR_WORKSPACE_ID`, `TEAMS_BOT_APP_ID`
- `functions_teams_bot.py` - Uses `TEAMS_BOT_APP_ID` for token validation
- `app.py` - Needs import cleanup (next step)

---

## Next Steps

1. ✅ **COMPLETED:** Comment out unnecessary Cosmos containers
2. ✅ **COMPLETED:** Add Teams bot configuration constants
3. ⏭️ **NEXT:** Update `app.py` to remove archived route imports
4. ⏭️ **NEXT:** Implement `scripts/ingest_hr_documents.py`
5. ⏭️ **NEXT:** Create Terraform deployment configuration
6. ⏭️ **NEXT:** Test end-to-end flow

---

## Rollback Instructions

If you need to restore all containers:

```bash
# In config.py, uncomment all container definitions
# Search for: "# cosmos_" and remove the "# " prefix
# Restart the application
```


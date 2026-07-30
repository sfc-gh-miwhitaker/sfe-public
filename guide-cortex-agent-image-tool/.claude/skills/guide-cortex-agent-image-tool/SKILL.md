---
name: guide-cortex-agent-image-tool
description: >
  SE guide for building a custom image-generation tool for Cortex Agents.
  Covers two patterns: SPCS-hosted model and external API. Includes agent spec,
  UDF wiring, SPCS service spec, and image return format details.
  Trigger terms: image tool, image generation, generate image, DALL-E snowflake,
  custom tool cortex agent, SPCS image, generic tool agent.
---

# Guide: Cortex Agent Image Tool

## Purpose

Reference guide for building a custom image-generation tool inside a Cortex Agent.
Covers the full stack: what "tools" are, why a UDF is the bridge, and two
production-ready patterns (SPCS and external API).

## Architecture

```
User → Cortex Agent
         ↓  (generic tool call)
     Snowflake UDF / Stored Proc
         ↓  (two paths)
   ┌──────────────┬──────────────┐
   SPCS Service     External Function
   (image gen       (DALL-E /
    model inside     Stability AI)
    Snowflake)
         ↓
   Returns JSON with image_url or base64
         ↓
   Agent includes in response
```

## Key Files

| File | Role |
|------|------|
| `README.md` | Full guide — architecture, code, step-by-step |
| `ELI5.md` | Plain-language companion |
| `AGENTS.md` | Project instructions |

## Extension Playbook

### How to add a new image model to the SPCS path

1. Build and push a new Docker image with the alternate model loaded
2. `ALTER SERVICE image_gen_service FROM SPECIFICATION ...` with new image tag
3. UDF stays the same — no agent spec changes required
4. Test with `SELECT generate_image_udf('a sunset over mountains')`

### How to switch from SPCS to External API

1. Create a Snowflake Secret with the API key
2. Create a Network Rule + External Access Integration for the target API host
3. Write a Python UDF that calls the external endpoint and returns JSON
4. Update `tool_resources.identifier` in the agent spec to point to the new UDF
5. Test end-to-end via `agent:run`

## Gotchas

- The agent's `generic` tool does NOT call a raw HTTP endpoint — it calls a
  Snowflake UDF or stored procedure. The UDF is the required bridge.
- SPCS service functions use the Snowflake external function data format
  (`{"data": [[row_index, col1, col2], ...]}`) — the Flask app must implement
  this protocol, not a plain REST response.
- Presigned stage URLs expire — set TTL longer than your longest expected session.
- The orchestration model sees only the text/JSON response from the tool, not the
  image pixels. If you need the model to reason about the image, pipe base64 back
  through `SNOWFLAKE.CORTEX.COMPLETE` with a vision model.
- External API path requires `EXTERNAL_ACCESS_INTEGRATIONS` on the UDF and a
  NETWORK_RULE allowlisting the target host.

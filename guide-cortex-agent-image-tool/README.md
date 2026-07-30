![Guide](https://img.shields.io/badge/Type-Guide-blue)
![Deploy](https://img.shields.io/badge/Deploy-Reference%20Only-lightgrey)
![Expires](https://img.shields.io/badge/Expires-2026--08--29-orange)
![Status](https://img.shields.io/badge/Status-Active-success)

# Give Your AI Assistant the Ability to Create Images

A Cortex Agent is an AI assistant that lives inside Snowflake. Out of the box it
can answer questions about your data, search documents, and run SQL. But you can
also give it *custom abilities* — called **tools** — that do anything a function
can do. This guide shows you how to build one of those tools so the agent can
generate images on demand.

**Audience:** anyone curious about how AI assistants can be extended. No deep
Snowflake background assumed in the first half; the second half is a complete
technical recipe for practitioners.

**Created:** 2026-07-30 | **Expires:** 2026-08-29 | **Status:** ACTIVE

Pair-programmed by SE Community + Cortex Code

> **No support provided.** Reference only; test before you rely on it in
> production. Syntax verified against Snowflake docs on the created date above.

---

## New to this? Read these words once

| Term | In plain words |
|------|----------------|
| **Cortex Agent** | An AI assistant inside Snowflake that answers questions by thinking and calling tools. |
| **Tool** | A named ability the agent can call, like "search these documents" or "look up revenue." |
| **Generic tool** | A custom tool you define yourself — the agent calls a function you wrote. |
| **Snowflake UDF** | A function stored in Snowflake that you can call with SQL. It is the bridge between the agent and your custom code. |
| **SPCS** | Snowpark Container Services — Snowflake's way to run Docker containers inside your account, close to your data. |
| **External Function** | A Snowflake function that calls a URL outside Snowflake (e.g. an image generation API). |
| **Presigned URL** | A temporary, time-limited web link to a file — like a "view for 15 minutes" link. |

> **The one-line mental model.** The agent decides to generate an image → it
> calls your custom tool → the tool calls a UDF → the UDF calls either an SPCS
> container or an external API → an image URL comes back → the agent includes
> it in the chat response.

---

## Why can't the agent just call an API directly?

Cortex Agents can only call tools that are registered in their configuration.
And the only way to register a custom tool is to point it at a **Snowflake
function** (a UDF or stored procedure). That function is the bridge. You write
the function; it can do anything — call an SPCS service, hit an external API,
run SQL, etc.

The agent never makes raw HTTP calls. This is intentional: it keeps everything
auditable, governed, and within Snowflake's security perimeter.

---

## Two ways to build an image-generation tool

| | Path 1: SPCS | Path 2: External API |
|--|--------------|----------------------|
| Where the model runs | Inside Snowflake (container) | Outside Snowflake (e.g. OpenAI) |
| Data leaves Snowflake? | No | Yes (prompts go to external API) |
| Setup complexity | Higher (build + push Docker image) | Lower (just a UDF + secret) |
| Cost | Compute pool credits + model download | API credits per image |
| Best for | Sensitive data, cost control at scale, fine-tuned models | Fast prototypes, access to latest commercial models |

Both paths produce identical results from the agent's perspective. You pick one
based on your security posture and how fast you want to ship.

---

## Path 1: SPCS image generator (fully inside Snowflake)

### Step 1 — Write the container service

Your Docker container needs to expose an HTTP endpoint that Snowflake can call.
Snowflake uses a specific request/response format (the same one used by External
Functions), so your Flask app must speak that protocol.

```python
# image_service.py
from flask import Flask, request, make_response
import base64, os

app = Flask(__name__)

# Load your image model at startup (SDXL-Turbo shown here)
from diffusers import AutoPipelineForText2Image
import torch
pipe = AutoPipelineForText2Image.from_pretrained(
    "stabilityai/sdxl-turbo",
    torch_dtype=torch.float16,
    variant="fp16"
)
pipe.to("cuda")

@app.get("/healthcheck")
def healthcheck():
    return "ready"

@app.post("/generate")
def generate():
    # Snowflake sends rows in this format:
    # {"data": [[row_index, prompt], [row_index, prompt], ...]}
    body = request.get_json()
    results = []
    for row in body["data"]:
        row_index, prompt = row[0], row[1]
        image = pipe(prompt=prompt, num_inference_steps=1, guidance_scale=0.0).images[0]
        # Encode as base64 string so it travels as JSON
        buf = io.BytesIO()
        image.save(buf, format="PNG")
        b64 = base64.b64encode(buf.getvalue()).decode("utf-8")
        results.append([row_index, b64])
    return make_response({"data": results})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

```dockerfile
# Dockerfile
FROM nvcr.io/nvidia/pytorch:24.01-py3
COPY image_service.py ./
RUN pip install flask diffusers transformers accelerate
CMD ["python", "image_service.py"]
```

### Step 2 — Push the image and create the SPCS service

```sql
-- Push the image first (from your terminal):
-- docker build --platform linux/amd64 -t <your-registry>/image_gen:latest .
-- snow spcs image-registry login
-- docker push <your-registry>/image_gen:latest

CREATE SERVICE image_gen_service
  IN COMPUTE POOL my_gpu_pool      -- GPU pool for inference
  FROM SPECIFICATION $$
  spec:
    containers:
    - name: image_gen
      image: /mydb/myschema/myrepo/image_gen:latest
      readinessProbe:
        port: 8080
        path: /healthcheck
    endpoints:
    - name: generate
      port: 8080
  $$
  MIN_INSTANCES = 1
  MAX_INSTANCES = 3;
```

> **Tip:** Use `DESCRIBE SERVICE image_gen_service` to watch the status column
> flip from PENDING → RUNNING before you proceed.

### Step 3 — Wrap the service in a UDF

The UDF is what the agent calls. It takes a text prompt and returns JSON with
the image (as a base64 string or a URL if you wrote the image to a stage).

```sql
-- Create the UDF that calls the SPCS endpoint
CREATE OR REPLACE FUNCTION mydb.myschema.generate_image(prompt STRING)
  RETURNS VARIANT
  SERVICE = image_gen_service
  ENDPOINT = generate
  AS '/generate';
```

Test it directly before wiring into the agent:

```sql
SELECT mydb.myschema.generate_image('a snow-covered mountain at sunset');
-- Returns: {"image_b64": "iVBORw0KGgo...", "prompt": "a snow-covered mountain..."}
```

### Step 4 — Register the UDF as an agent tool

```json
{
  "tools": [
    {
      "tool_spec": {
        "type": "generic",
        "name": "generate_image",
        "description": "Generates an image from a text description. Use this when the user asks to create, draw, or visualize something. Returns the image as a base64-encoded PNG and the original prompt.",
        "input_schema": {
          "type": "object",
          "properties": {
            "prompt": {
              "type": "string",
              "description": "A detailed text description of the image to generate. Include style, subject, lighting, and mood for best results. Example: 'A photorealistic golden retriever running on a beach at sunset, shallow depth of field.'"
            }
          },
          "required": ["prompt"]
        }
      }
    }
  ],
  "tool_resources": {
    "generate_image": {
      "type": "function",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "MY_WAREHOUSE"
      },
      "identifier": "MYDB.MYSCHEMA.GENERATE_IMAGE"
    }
  }
}
```

---

## Path 2: External API (e.g. DALL-E or Stability AI)

This path is faster to set up. Your UDF calls an external HTTP endpoint. You
need a Snowflake Secret for the API key and a Network Rule to allow the outbound
call.

### Step 1 — Store the API key safely

```sql
CREATE SECRET mydb.myschema.dalle_api_key
  TYPE = generic_string
  SECRET_STRING = 'sk-...your-openai-key...';  -- pragma: allowlist secret
```

### Step 2 — Allow the outbound network call

```sql
CREATE NETWORK RULE openai_rule
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('api.openai.com:443');

CREATE EXTERNAL ACCESS INTEGRATION openai_access
  ALLOWED_NETWORK_RULES = (openai_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (mydb.myschema.dalle_api_key)
  ENABLED = TRUE;
```

### Step 3 — Write the UDF

```sql
CREATE OR REPLACE FUNCTION mydb.myschema.generate_image_external(prompt STRING)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  EXTERNAL_ACCESS_INTEGRATIONS = (openai_access)
  SECRETS = ('api_key' = mydb.myschema.dalle_api_key)
  PACKAGES = ('requests')
  HANDLER = 'generate'
AS $$
import requests, _snowflake, json

def generate(prompt):
    api_key = _snowflake.get_generic_secret_string('api_key')
    response = requests.post(
        "https://api.openai.com/v1/images/generations",
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        json={"model": "dall-e-3", "prompt": prompt, "n": 1, "size": "1024x1024"},
        timeout=60
    )
    response.raise_for_status()
    data = response.json()
    return {"image_url": data["data"][0]["url"], "prompt": prompt}
$$;
```

Test it:

```sql
SELECT mydb.myschema.generate_image_external('a futuristic city skyline at night');
-- Returns: {"image_url": "https://oaidalleapiprodscus.blob.core.windows.net/...", "prompt": "..."}
```

### Step 4 — Register in the agent spec (identical pattern)

Same JSON as Path 1 — just change the `identifier` to point to the new UDF:

```json
"tool_resources": {
  "generate_image": {
    "type": "function",
    "execution_environment": {
      "type": "warehouse",
      "warehouse": "MY_WAREHOUSE"
    },
    "identifier": "MYDB.MYSCHEMA.GENERATE_IMAGE_EXTERNAL"
  }
}
```

---

## What the agent does with the result

The tool returns JSON to the agent's context. The agent then includes that in
its response. What happens in the UI depends on the client:

| Response shape | Snowflake Intelligence | Custom app |
|----------------|------------------------|------------|
| `{"image_url": "https://..."}` | Renders inline if URL is accessible | You handle rendering |
| `{"image_b64": "iVBOR..."}` | Not rendered automatically | Decode and render in your UI |

**Practical recommendation:** Use presigned stage URLs for SPCS path. Write
the image to a Snowflake stage and generate a presigned URL with a TTL that
outlasts the session (e.g. 1 hour):

```sql
-- Inside your UDF or stored proc, after generating the image:
PUT file:///tmp/image.png @mydb.myschema.mystage AUTO_COMPRESS=FALSE;
SELECT GET_PRESIGNED_URL('@mydb.myschema.mystage', 'image.png', 3600) AS url;
```

---

## One thing that surprises people

The orchestration model (the AI brain of the agent) can only *read text*. It
receives your tool's JSON response as text. It does **not** see the pixels of
the image.

This means:
- The model can tell the user "here is your image: [url]"
- The model *cannot* look at the image and describe what it sees (unless you
  separately run it through a vision model)

If you need the agent to reason about generated images, add a second step: after
generating, call `SNOWFLAKE.CORTEX.COMPLETE` with a vision-capable model and
the base64 image to get a description, then include that description in the
tool response alongside the URL.

---

## Full agent specification (ready to use)

Replace `MYDB`, `MYSCHEMA`, `MY_WAREHOUSE` with your values.

```sql
CREATE AGENT mydb.myschema.image_creator_agent
  FROM SPECIFICATION $$
  {
    "instructions": {
      "response": "You are a creative AI assistant. When users ask you to generate, draw, or create an image, use the generate_image tool. Show the image URL in your response and describe what was created.",
      "orchestration": "Use generate_image whenever the user asks to create, draw, visualize, or generate any visual content. Craft a detailed, descriptive prompt from the user's request before calling the tool."
    },
    "tools": [
      {
        "tool_spec": {
          "type": "generic",
          "name": "generate_image",
          "description": "Generates an image from a text description. Returns a URL to the generated image and the prompt used. Use this for any request to create, draw, or visualize something.",
          "input_schema": {
            "type": "object",
            "properties": {
              "prompt": {
                "type": "string",
                "description": "Detailed text description. Include subject, style, lighting, mood, and any relevant details. More specific prompts produce better images."
              }
            },
            "required": ["prompt"]
          }
        }
      }
    ],
    "tool_resources": {
      "generate_image": {
        "type": "function",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "MY_WAREHOUSE"
        },
        "identifier": "MYDB.MYSCHEMA.GENERATE_IMAGE"
      }
    }
  }
  $$;
```

---

## Quick reference checklist

**SPCS path:**
- [ ] Docker image built for `linux/amd64`, pushed to Snowflake image registry
- [ ] `CREATE COMPUTE POOL` with GPU node type (e.g. `GPU_NV_S` for SDXL-Turbo)
- [ ] SPCS service running and `DESCRIBE SERVICE` shows `RUNNING`
- [ ] Service function (UDF) created and returns valid JSON when tested directly
- [ ] Agent spec registered, `generate_image` tool pointing to UDF

**External API path:**
- [ ] `CREATE SECRET` with API key
- [ ] `CREATE NETWORK RULE` allowlisting the API host
- [ ] `CREATE EXTERNAL ACCESS INTEGRATION` referencing rule + secret
- [ ] Python UDF created with `EXTERNAL_ACCESS_INTEGRATIONS` and `SECRETS` set
- [ ] UDF returns valid JSON when tested directly
- [ ] Agent spec registered, `generate_image` tool pointing to UDF

**Both paths:**
- [ ] Test the UDF with `SELECT your_udf('a test prompt')` before hooking up the agent
- [ ] If returning URLs: verify presigned URL TTL is set appropriately
- [ ] If returning base64: verify your UI or client renders it

---

## Where to go next

- [Snowpark Container Services: Working with services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-services) — detailed SPCS reference
- [Cortex Agents REST API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api) — full agent spec schema
- [External Access Integrations](https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access) — network rules + secrets

---

## Development Tools

This guide was built using [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
with project-level AI instructions in `AGENTS.md` and `.claude/skills/`.

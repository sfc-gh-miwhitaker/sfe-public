# Working Spec: Wrap Your Own Code as a Tool

The sibling spec, [same-account-agent-to-agent.md](same-account-agent-to-agent.md), wraps a **stored procedure** so one agent can call another. This page wraps a **function** so an agent can call something Snowflake has no built-in tool for — a model you host yourself, or a third-party HTTP API. The worked example is image generation, because it exercises both back ends and surfaces a result-handling problem that pure-SQL tools never hit.

Pair-programmed by SE Community + Cortex Code

> **Read the sibling spec first.** The generic-tool mechanics — `tool_spec` `type: "generic"`, the `input_schema` block, the matching `tool_resources` key, and testing the wrapped object standalone before wiring it up — are covered there and are identical here. The only delta is that `tool_resources` says `type: "function"` instead of `type: "procedure"`.

> **The code is illustrative.** Names, hosts, and model identifiers are placeholders. Third-party model names in particular change often — see the note in Path 2.

## Extra vocabulary

Three terms show up only on this page — **service function**, **External Access Integration**, and **presigned URL**. All three, plus Agent, Tool, and SPCS, are defined in the [main glossary](README.md#new-to-snowflake-read-these-words-once).

## Why the function is mandatory

An agent cannot make raw HTTP calls. It can only invoke tools registered in its specification, and a custom tool must point at a Snowflake function or stored procedure. That object is the bridge, and it is the only way out: everything the agent reaches stays auditable, governed, and inside Snowflake's security perimeter.

Your bridge function can then do anything — call a container, call an external API, run SQL.

## Two back ends

| | Path 1: SPCS | Path 2: External API |
| -- | -- | -- |
| Where the model runs | Inside Snowflake (container) | Outside Snowflake |
| Data leaves Snowflake? | No | Yes — prompts go to the provider |
| Setup complexity | Higher (build + push a Docker image) | Lower (a function + a secret) |
| Cost shape | Compute pool credits + model download | Provider charges per call |
| Best for | Sensitive inputs, cost control at scale, self-hosted or fine-tuned models | Fast prototypes, access to the newest commercial models |

Both look identical from the agent's side. Pick on security posture and how fast you need to ship.

---

## Path 1: SPCS (fully inside Snowflake)

### Step 1 — Write the container service

Snowflake calls your container using the **external function data format**, not a plain REST shape: rows arrive as `{"data": [[row_index, arg1, ...], ...]}` and must come back the same way. This is the single most common reason a working container fails as a service function.

```python
# image_service.py
from flask import Flask, request, make_response
import base64, io

app = Flask(__name__)

# Load your image model once at startup.
from diffusers import AutoPipelineForText2Image
import torch
pipe = AutoPipelineForText2Image.from_pretrained(
    "<HUGGINGFACE_MODEL_ID>",
    torch_dtype=torch.float16,
    variant="fp16",
)
pipe.to("cuda")

@app.get("/healthcheck")
def healthcheck():
    return "ready"

@app.post("/generate")
def generate():
    body = request.get_json()
    results = []
    for row in body["data"]:
        row_index, prompt = row[0], row[1]
        image = pipe(prompt=prompt, num_inference_steps=1, guidance_scale=0.0).images[0]
        buf = io.BytesIO()
        image.save(buf, format="PNG")
        results.append([row_index, base64.b64encode(buf.getvalue()).decode("utf-8")])
    return make_response({"data": results})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

```dockerfile
# Dockerfile
FROM <GPU_BASE_IMAGE>
COPY image_service.py ./
RUN pip install flask diffusers transformers accelerate
CMD ["python", "image_service.py"]
```

### Step 2 — Push the image and create the service

```sql
-- From your terminal, before the SQL below:
--   docker build --platform linux/amd64 -t <registry>/image_gen:latest .
--   snow spcs image-registry login
--   docker push <registry>/image_gen:latest

CREATE SERVICE image_gen_service
  IN COMPUTE POOL my_gpu_pool
  FROM SPECIFICATION $$
  spec:
    containers:
    - name: image_gen
      image: /my_db/my_schema/my_repo/image_gen:latest
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

> Watch `DESCRIBE SERVICE image_gen_service` until the status flips from PENDING to RUNNING before going further. A GPU compute pool bills while it is up, so suspend the service when it is idle.

### Step 3 — Wrap the service in a function

```sql
CREATE OR REPLACE FUNCTION my_db.my_schema.generate_image(prompt STRING)
  RETURNS VARIANT
  SERVICE = image_gen_service
  ENDPOINT = generate
  AS '/generate';
```

### Step 4 — Register it as a tool

```yaml
tools:
  - tool_spec:
      type: "generic"
      name: "generate_image"
      description: "Generates an image from a text description. Use when the user asks to create, draw, or visualize something. Returns the image and the prompt used."
      input_schema:
        type: "object"
        properties:
          prompt:
            type: "string"
            description: "Detailed description of the image: subject, style, lighting, mood. More specific prompts produce better images."
        required: ["prompt"]
tool_resources:
  generate_image:
    type: "function"
    execution_environment:
      type: "warehouse"
      warehouse: "MY_WAREHOUSE"
    identifier: "my_db.my_schema.generate_image"
```

`CREATE AGENT ... FROM SPECIFICATION` takes YAML; the REST API takes the equivalent JSON body.

---

## Path 2: External API

Your function calls a provider over HTTPS. You need a secret for the credential and a network rule permitting the outbound call.

### Step 1 — Store the credential

```sql
CREATE SECRET my_db.my_schema.image_api_key
  TYPE = generic_string
  SECRET_STRING = '<YOUR_PROVIDER_API_KEY>';  -- pragma: allowlist secret
```

### Step 2 — Allow the outbound call

```sql
CREATE NETWORK RULE image_api_rule
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('<PROVIDER_HOST>:443');

CREATE EXTERNAL ACCESS INTEGRATION image_api_access
  ALLOWED_NETWORK_RULES = (image_api_rule)
  ALLOWED_AUTHENTICATION_SECRETS = (my_db.my_schema.image_api_key)
  ENABLED = TRUE;
```

### Step 3 — Write the function

```sql
CREATE OR REPLACE FUNCTION my_db.my_schema.generate_image_external(prompt STRING)
  RETURNS VARIANT
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  EXTERNAL_ACCESS_INTEGRATIONS = (image_api_access)
  SECRETS = ('api_key' = my_db.my_schema.image_api_key)  -- pragma: allowlist secret
  PACKAGES = ('requests')
  HANDLER = 'generate'
AS $$
import requests, _snowflake

def generate(prompt):
    api_key = _snowflake.get_generic_secret_string('api_key')
    response = requests.post(
        "https://<PROVIDER_HOST>/v1/images/generations",
        headers={"Authorization": f"Bearer {api_key}",
                 "Content-Type": "application/json"},
        json={"model": "<IMAGE_MODEL_NAME>", "prompt": prompt,
              "n": 1, "size": "1024x1024"},
        timeout=60,
    )
    response.raise_for_status()
    data = response.json()
    return {"image_url": data["data"][0]["url"], "prompt": prompt}
$$;
```

> **Do not hardcode a vendor model name from a guide.** Commercial image models are renamed, versioned, and retired faster than anything else in this stack, and a stale identifier fails at call time, not at create time. Look up `<IMAGE_MODEL_NAME>` in your provider's current model list, and re-check it whenever this function starts erroring.

### Step 4 — Register it

Same tool spec as Path 1; only the pointer changes.

```yaml
tool_resources:
  generate_image:
    type: "function"
    execution_environment:
      type: "warehouse"
      warehouse: "MY_WAREHOUSE"
    identifier: "my_db.my_schema.generate_image_external"
```

---

## What the agent does with the result

Your function's JSON lands in the agent's context and the agent passes it along. What the user actually sees depends on the client:

| Response shape | Snowflake Intelligence | Custom app |
| --- | --- | --- |
| `{"image_url": "https://..."}` | Renders inline when the URL is reachable | You handle rendering |
| `{"image_b64": "iVBOR..."}` | Not rendered automatically | Decode and render yourself |

**Prefer presigned stage URLs, especially on the SPCS path.** Write the image to a stage and return a link whose lifetime outlasts the conversation — a base64 blob bloats the agent's context and renders nowhere by default.

```sql
PUT file:///tmp/image.png @my_db.my_schema.my_stage AUTO_COMPRESS = FALSE;

SELECT GET_PRESIGNED_URL('@my_db.my_schema.my_stage', 'image.png', 3600) AS url;
```

Presigned URLs expire. If someone reopens the conversation after the TTL, the image is gone — set the TTL longer than your longest expected session.

## The orchestrator can only read text

This is the point that surprises everyone, and it generalizes past images to any tool returning binary or rich output.

The orchestration model receives your tool's JSON **as text**. It never sees the pixels. So:

- It can say "here is your image: [url]".
- It **cannot** look at the image and tell you whether it is any good, whether it matches the prompt, or what is in it.

Ask the agent "does that image look right?" and it genuinely does not know. If the agent must reason about what it generated, add a second step inside the tool: pass the image to `SNOWFLAKE.CORTEX.COMPLETE` with a vision-capable model, then return that description alongside the URL. The agent reasons over the description, not the image.

---

## Checklist

**SPCS path**

- [ ] Docker image built for `linux/amd64` and pushed to the Snowflake image registry
- [ ] Compute pool created with a GPU node type
- [ ] `DESCRIBE SERVICE` shows RUNNING
- [ ] Service function created and returning valid JSON
- [ ] Container speaks the `{"data": [[row_index, ...]]}` format both ways
- [ ] Service suspended when idle so the GPU pool stops billing

**External API path**

- [ ] `CREATE SECRET` holds the credential (never inline in the function body)
- [ ] `CREATE NETWORK RULE` allowlists the provider host
- [ ] `CREATE EXTERNAL ACCESS INTEGRATION` references both rule and secret
- [ ] Function declares `EXTERNAL_ACCESS_INTEGRATIONS` and `SECRETS`
- [ ] Model identifier checked against the provider's current model list
- [ ] Prompt content reviewed — it leaves your account on this path

**Both paths**

- [ ] Function returns valid JSON when called directly, before any agent wiring
- [ ] Returning URLs: presigned TTL outlasts the session
- [ ] Returning base64: your client actually renders it
- [ ] Anything the agent must reason about is present as *text* in the response

## References

- [Snowpark Container Services: working with services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-services)
- [Snowpark Container Services: service functions](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/additional-considerations-services-jobs)
- [External network access: network rules and secrets](https://docs.snowflake.com/en/developer-guide/external-network-access/creating-using-external-network-access)
- [Cortex Agents REST API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api)
- [`GET_PRESIGNED_URL`](https://docs.snowflake.com/en/sql-reference/functions/get_presigned_url)

> Simplified from: `guide-cortex-agent-image-tool/README.md`

## One-Sentence Version

You can teach Snowflake's AI assistant to create pictures by writing a
middleman function that the assistant calls — either running an image model
inside Snowflake itself, or sending a request to an outside service like DALL-E.

---

## The Story

Imagine an AI assistant at a help desk. It knows how to answer questions, but
when someone asks it to *draw* something, it doesn't have hands. To fix that,
you build a "draw button" — a named function the assistant knows it can press,
which goes off and creates an image on its behalf.

The assistant never draws directly. It just says "I want to use the draw
button, here's what to draw" — and the button does the actual work and hands
back a picture (or a link to one). This separation is intentional: it keeps a
record of every tool the assistant can use, which is important for security and
auditing.

The "draw button" can be wired to two different machines. The first machine
(SPCS path) lives inside your Snowflake account — a Docker container running an
image generation model on a GPU, never sending your prompts outside. The second
machine (External API path) sends a request to a commercial service like
OpenAI's DALL-E and gets an image back. Same button press, two different back
rooms.

The one detail that surprises people: the AI assistant can see the *link* to
the image it generated, but it cannot actually *look* at the pixels. It's like
an assistant who can press "print" and hand you the paper, but who is working
in a dark room and has never seen what came out.

---

## The Cast

| Term | Plain words |
|------|-------------|
| **Cortex Agent** | The AI assistant living in Snowflake. |
| **Generic tool** | A custom ability you give the assistant — you define what it does. |
| **UDF (User Defined Function)** | A function you write and store in Snowflake; it's the "draw button" the assistant presses. |
| **SPCS** | A way to run Docker containers inside Snowflake so your code — and your data — stays inside your account. |
| **External Function** | A Snowflake function that reaches outside to call a web API, like OpenAI. |
| **Presigned URL** | A temporary web link to a file — valid for an hour or so, then it expires. |
| **External Access Integration** | Snowflake's permission slip that allows a specific function to reach a specific outside address. |

---

## What Changed

- **Before:** Cortex Agents could answer data questions and search documents,
  but couldn't generate new visual content.
- **After:** You can add a custom tool that runs image generation, wired to
  either an in-house model or a commercial API.
- **The wiring:** The agent → calls a UDF → the UDF calls the image generator
  → a URL or image data comes back → the agent shares it with the user.
- **Important:** The AI brain doesn't directly talk to the image generator.
  The UDF is the required middleman, every time.

---

## What to Watch Out For

**Image links expire.** If you use a presigned URL (the temporary web link),
it stops working after the time limit you set. If someone opens a conversation
later, the image may already be gone. Set the expiry longer than your longest
expected session.

**Your data may leave Snowflake on the External API path.** When you use
DALL-E or another outside service, the text prompt you send leaves your
account. For most prompts that's fine; for prompts that contain sensitive
business terms, use the SPCS path instead.

**The assistant can't see what it created.** If you ask the assistant "does
that image look right?", it genuinely doesn't know. It only sees the URL or
the raw data string, not the visual result. If you need the assistant to
describe or reason about the image, that requires an extra step (running the
image through a vision model separately).

**GPU compute pools cost money while they're running.** The SPCS path uses a
GPU node. If you leave the service running overnight with no traffic, you're
paying for an idle GPU. Set `MAX_INSTANCES` to scale down or suspend the
service when not in use.

---

## The One Thing to Remember

The AI assistant cannot call an image generator directly — it can only press a
Snowflake function (a UDF) that you build, and that function is what actually
creates the image. Everything else is just choosing which back room the
function calls.

---

> For the full technical details, see the source document: `README.md`

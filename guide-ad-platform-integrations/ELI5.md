> Simplified from: `guide-ad-platform-integrations/README.md`

# Snowflake, Google Ads, and Meta Ads — Explained Simply

## One-Sentence Version

Google lets you plug Snowflake straight into Google Ads to send it customer lists;
Meta lets an AI assistant press buttons in your Meta ad account — and people
constantly mistake the second thing for the first.

## The Story

Think of your Snowflake account as a warehouse full of filing cabinets holding
everything you know about your customers. Two different companies have shown up
offering to connect to that warehouse, and they want completely different things.

**Google brought a delivery truck.** Google Ads has a feature called Data Manager.
You point it at one shelf in your warehouse, and every night a Google truck backs
up to the loading dock and copies what is on that shelf. Google uses the copy to
find those same people on its ad platforms. Snowflake is one of seventeen data
sources Google's truck knows how to visit — no middleman needed. The truck
comes to you; you never drive anywhere.

**Meta brought a telephone.** Meta's "Ads MCP Server" is a phone line into your
Meta advertising account. An AI assistant can call that line and say "pause the
campaign that is losing money" or "tell me how last week went." That is genuinely
useful — but notice the phone never visits your warehouse. It cannot see your
filing cabinets at all. It is a way to give instructions, not a way to move boxes.

So when someone asks "can Snowflake connect to Meta the way it connects to Google
Ads?" the honest answer is no. Google built a loading dock. Meta built a phone.
If you want to send customer lists to Meta, you still need to hire a courier
company or write the shipping code yourself.

## The Cast

- **Snowflake** — your warehouse. Where the customer data lives.
- **Google Ads Data Manager** — the nightly delivery truck. Copies one shelf from
  your warehouse into Google Ads.
- **Customer Match** — what Google does with the copy: finds your customers among
  its users so you can advertise to them.
- **A view** — a labeled shelf you build on purpose, showing only what the truck
  is allowed to take. Not the whole filing cabinet.
- **PAT (Programmatic Access Token)** — a temporary key you cut for the truck
  driver. It expires on its own, which is a feature and also a trap.
- **MCP (Model Context Protocol)** — a standard shape for phone lines, so any AI
  assistant can call any company's line without custom wiring.
- **Meta Ads MCP Server** — Meta's phone line. Currently an "open beta," meaning
  it works but Meta reserves the right to change it.
- **Cortex Agent / CoWork / Cortex Code** — the assistants on your side that can
  place the call.

## What Changed

- **Before:** getting Snowflake data into Google Ads meant exporting files or
  paying a third-party tool to shuttle them.
- **After:** Google connects to Snowflake directly, on a schedule, with no
  middleman.
- **Before:** managing Meta ads meant clicking through Meta's website, or writing
  code against Meta's API and holding a long-lived password.
- **After:** an AI assistant can do it through a phone line that Meta itself
  operates, with no code and no password to store.
- **Unchanged:** there is still no easy way to send customer lists from Snowflake
  to Meta.

## What to Watch Out For

**The key expires and nothing tells you.** The temporary key you give Google's
truck driver lasts 15 days by default. You cannot extend it after you make it —
you have to cut a new one. When it expires, the truck just quietly stops showing
up. Set a calendar reminder.

**Google's trucks change license plates.** Snowflake likes to keep a list of
which vehicles are allowed at the loading dock. Google says its trucks use
addresses that "change without notice." That is a real conflict. There is a clean
way around it — a specific kind of Snowflake account type that does not require
the list — but you have to know to use it.

**Do not do the encryption work yourself.** Google will scramble the personal
details for you, for free, using a method it has published and had audited
independently. Doing it yourself in Snowflake costs money and is easy to get
subtly wrong. Let Google do it.

**Dates will betray you.** Google reads `02/01/2026` as February 1st. If your
data contains even one date it can tell is day-first, Google throws away the
entire shipment on purpose. Write dates in the boring international format.

**A phone line can spend your money.** If you give an AI assistant permission to
change Meta campaigns, it can change what you spend. Start by only letting it
read things. Set a hard spending cap in Meta's own settings too — that is the one
protection that does not depend on you configuring the assistant correctly.

**Snowflake did not build the phone line, and says so.** Snowflake's own warning
is blunt: outside phone lines are "not provided, maintained, or verified by
Snowflake," and checking whether one is trustworthy is your job. With advertising
data, that is a real responsibility, not paperwork.

## The Open Questions

The guide is honest about what nobody has confirmed, and so is this.

Meta's instructions live on web pages that machines cannot read — only humans
with a browser can. So the exact phone number, the full list of things the
assistant can do, and the limits on how often it can call are all **unconfirmed**.
Multiple blogs repeat an installation command that turns out not to exist at all.

Nobody has publicly connected Meta's phone line to Snowflake and shown it working.
The Snowflake side of the instructions is solid and documented. The Meta side is
an educated guess. Expect the first attempt to need debugging.

## The One Thing to Remember

Google Ads Data Manager moves your data; Meta's MCP server moves your
instructions — and only one of them is a finished product.

> For the full technical details, see the source document.

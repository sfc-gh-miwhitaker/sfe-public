> Simplified from: `guide-ad-platform-integrations/README.md`

# Snowflake and the Ad Platforms — Explained Simply

## One-Sentence Version

Getting advertising data between Snowflake and Google or Meta uses several
completely different mechanisms, and which one you need depends entirely on which
way the data is moving and what kind of data it is.

## The Story

Think of your Snowflake account as a warehouse. Sometimes you want to *send*
things out of it, and sometimes you want to *bring* things in. Those turn out to
be very different jobs.

**Sending to Google: Google sends a truck.** Google Ads has a tool called Data
Manager. You point it at one shelf in your warehouse, and every night a Google
truck backs up to your loading dock and copies what's on that shelf. Google uses
the copy to find those same people on its ad platforms. You build the shelf and
hand over a key. That's the whole job — Google owns the truck, the route, and the
schedule.

**Bringing data in: you run the truck.** Snowflake makes its own connectors that
pull advertising performance data *from* Meta and Google *into* your warehouse.
But these don't run themselves. They run on a Snowflake system called Openflow,
which you have to set up first — a deployment, a runtime, some networking rules.
It's less like receiving a delivery and more like buying a van and hiring a
driver.

So the two halves of this look symmetrical and aren't. Sending to Google needs a
shelf and a key. Receiving from Meta or Google needs infrastructure. Knowing that
before you promise anyone a timeline is most of the value here.

## The Cast

- **Snowflake** — your warehouse, where the data lives.
- **Google Ads Data Manager** — Google's nightly truck. Copies one shelf out of
  your warehouse into Google Ads. Google built it and Google runs it.
- **Customer Match** — what Google does with the copy: finds your customers among
  its users so you can advertise to them.
- **A view** — a labeled shelf you build on purpose, showing only what the truck
  is allowed to take. Not the whole filing cabinet.
- **PAT (Programmatic Access Token)** — a temporary key you cut for the driver.
  It expires on its own, which is both a safety feature and a trap.
- **Openflow** — Snowflake's data-movement system. A platform you stand up, not a
  button you press.
- **A connector** — a pre-built recipe that runs on Openflow and knows how to
  talk to one specific service, like Meta Ads.
- **A runtime** — the actual worker inside Openflow that runs your recipe. This
  is the part that costs money while it's running.
- **Network rule and external access integration** — the permission slip that
  lets your runtime reach out to the internet. Without it, it can't reach
  anything at all.

## What Changed

- **Before:** getting Snowflake data into Google Ads meant exporting files or
  paying a middleman tool.
- **After:** Google connects to Snowflake directly, on a schedule, no middleman.
- **Before:** pulling Meta or Google ad performance into Snowflake meant a
  third-party tool or your own code.
- **After:** Snowflake ships its own connectors for both — but they run on
  Openflow, so there's a platform to set up first.
- **Sending *sales results* to Meta:** Snowflake publishes a free recipe on GitHub that builds
  this pipeline for you. You tell Snowflake's coding assistant "set up Meta CAPI," it finds your
  purchase data, scrambles the personal details, and starts telling Meta which ads actually led
  to sales. It asks your permission three times before it turns anything on.
- **Letting a marketer ask Meta questions:** there's a second piece that pulls campaign data back
  from Meta so a marketer can ask "why did our ads do worse this week?" and get an answer that
  also looks at your own sales data. It can also *prepare* changes to a campaign for someone to
  approve — so it isn't only looking, it can reach back and touch live ad spend. This one you
  can't just download; you have to ask Snowflake for access.
- **The Meta send-out gap, narrowed:** sending *sales results* to Meta now has an official path
  (above). Sending a *list of customers* to Meta still doesn't — for that you go through a
  middleman: Snowflake's clean-room connector, or a partner app from the Snowflake Marketplace.

## What to Watch Out For

**The key expires and nothing tells you.** The token you give Google's truck
driver lasts 15 days by default, and you can't extend it after you make it — you
cut a new one. When it expires, the truck just quietly stops showing up. Set a
calendar reminder.

**Google's trucks change license plates.** Snowflake likes keeping a list of
which vehicles are allowed at the dock. Google says its trucks use addresses that
change without notice. There's a clean way around it, but you have to know to use
it.

**Let Google do the scrambling.** Google will hash the personal details for you,
free, using a published and independently reviewed method. Doing it yourself
costs money and is easy to get subtly wrong.

**Dates will betray you.** Google reads `02/01/2026` as February 1st. If your
data contains even one date it can tell is day-first, Google throws away the
entire shipment on purpose. Use the boring international format.

**Openflow's van can't leave the driveway by default.** A new runtime has no
internet access at all. You have to explicitly allow the two addresses it needs:
one for Meta, one for Google.

**An admin account can't drive the van.** If your Snowflake login defaults to the
top-level admin role, Openflow will refuse to let you into a runtime. Use a
different default role.

**Meta only remembers three years.** You can't pull ad data older than 37 months.
That's Meta's limit, not Snowflake's.

**Hitting Meta's rate limit fails silently.** The connector keeps trying and no
data arrives. Nothing errors out — it just doesn't work. Raising the limit means
upgrading your Meta app's access level.

**"Incremental" only works on daily.** If you group your data any way other than
day-by-day, the connector re-pulls everything every time.

## The Open Questions

**Which Meta API version is supported.** The Snowflake docs list one specific
version. Meta retires versions on its own schedule. Confirm the current supported
version before you build something long-lived on it.

**The Openflow setup steps were not tested.** The permissions and networking in
this guide were run against a real Snowflake account and verified. The deployment,
runtime, and connector configuration were not — that needed an Openflow
deployment the test account didn't have. Those steps come from documentation, not
from watching them work.

**Two Meta things share a name.** "The Meta MCP" usually means the new pairing that
lets a marketer ask questions about Meta campaigns. That is a different product
from Snowflake's Openflow connector, which just copies Meta's numbers into tables.
If someone asks about "the Meta MCP," make sure you know which one they mean.

**Half of it you can't download.** The piece that sends sales results to Meta is
public on GitHub. The piece that reads Meta data back is available only by asking
Snowflake. Don't promise both on the same day.

**The audience-list middleman has an expiry date.** Snowflake's clean-room
connector to Meta only works through a web screen that Snowflake is retiring — the
first shutoff date is October 2026. If you build on it, check first what replaces it.

## The One Thing to Remember

Four different jobs that sound like one: sending customer lists to Google needs a
view and a token; sending sales results to Meta needs a free skill from GitHub;
pulling ad performance into Snowflake needs an entire Openflow platform; and
sending customer *lists* to Meta still needs a middleman. Same-sounding requests,
very different amounts of work.

> For the full technical details, see the source document.

# Delta Sharing Behind a Firewall — Plain English

> Simplified from: guide-delta-sharing-ip-allowlist/README.md

## One-Sentence Version

A vendor will only hand over your data if the request arrives from an address you registered with them in advance, and Snowflake's easiest way of fetching that data cannot tell you what address it will use — so the answer is almost always to run a small delivery service in your own cloud account, which does have a fixed address, and hand the data to Snowflake afterwards.

## The Story

Think of the vendor as a warehouse that only opens its loading dock for trucks with registered licence plates. You send them your plate numbers, they write them on a clipboard, and the guard checks the clipboard. Anything not on the list is turned away.

Snowflake has a wonderfully simple way to collect from that warehouse. It is two lines of paperwork and it works beautifully — but Snowflake will not tell you which truck it sends. There is no plate number to register. The collection method is fine; the guard is the problem.

**So the answer is to run your own truck.** Park it at your own address, with a plate that is yours permanently, drive it to the dock, collect the goods, and unload into Snowflake afterwards. It is the only arrangement that gives the guard exactly what the clipboard asks for, and it is what warehouse guidance usually recommends anyway.

Before you buy a truck, though, ask the warehouse three questions. They might accept a different kind of ID, or drop the plate check entirely for a better one. Any single yes and you are back to the two lines of paperwork. Asking costs nothing and the answer arrives in days.

There is one more option people reach for: running the truck inside Snowflake's own yard. Snowflake will give you a plate for that — but it belongs to a fleet of 256 shared with other customers, and it changes on a schedule. A guard who asked for one or two plates may simply refuse. It is worth trying only if they say in advance that they will accept it.

## The Cast

- **Delta Sharing** — the vendor's method of handing over data. A published standard, so plenty of tools can read it.
- **Bearer token** — a password-like string. Whoever holds it can read the data, which is exactly why the vendor also checks your address.
- **IP allowlist** — the guard's clipboard. A list of addresses permitted to make requests.
- **Catalog integration** — Snowflake's two-line method of reading the vendor's data directly. Simple, and no registered address.
- **Snowpark Container Services** — Snowflake's way of running your own small program inside Snowflake. Programs run this way *do* get a registered address.
- **Stable egress IP** — the address range Snowflake will use. Published, and it changes on a schedule.
- **NAT gateway** — a single fixed address in your own cloud account that everything behind it appears to come from. Yours permanently.
- **Full historical refresh** — the vendor resends everything every day, not just what changed. This changes how you load it.

## What Changed

- Snowflake can now read Delta Sharing feeds natively. Since July 2026 this is a finished, supported feature, not an experiment.
- That native method has no address you can register, so a vendor who insists on an allowlist blocks it.
- Running your own small program inside Snowflake does get you a registerable address.
- The address is a block of 256, shared with other Snowflake customers in your region. It is not yours alone.
- The address block expires on a published schedule, and there is no automatic way to tell the vendor about the new one.

## What to Watch Out For

**You will not be giving the vendor one address.** They will ask for one to three. Snowflake gives you a block of 256, shared with other Snowflake customers nearby. This is still reasonably safe — the password is what actually protects your data — but it is not what the form asked for. Say so yourself, early. Do not let the security reviewer discover it.

**The address expires and nobody will remind you.** Snowflake publishes replacements about two months ahead. The vendor updates their clipboard by support ticket, not automatically. Miss the window and the feed stops with a connection error and no explanation. Put it in a calendar with the ticket instructions attached.

**There are two clipboards, not one.** The vendor emails the password as a download link, and that link is usually address-restricted too. So the person clicking it needs *their* office address registered, separately from Snowflake's. Register only Snowflake's and you cannot even collect the password. This trips people up on day one.

**The vendor sends you to two different buildings.** The first request goes to the vendor's front desk, which then points you at a separate storage location for the actual files. Both addresses need permission, and you must ask the vendor for the second one. If the file listing works but the download fails, this is why.

**Running the program inside Snowflake still needs the vendor to agree.** This is the trap. The address block is shared and 256 wide, so it is not a technical solution that bypasses the vendor — it is still a request they can refuse. Ask them whether they will accept it *before* building anything, not after.

**If your Snowflake account runs on Google Cloud, the inside-Snowflake approach does not work.** Snowflake does not publish a registerable address there. Use your own address instead.

**Splitting the work across two places means two things that can break.** If you run the program in your own cloud account, one schedule fetches the data and a different one loads it into Snowflake. The fix is a small "finished" marker file: the loader waits for it and never reads a half-written batch. Do not rely on the second schedule simply starting later.

**Much of this is unproven.** The address-checking commands were run for real, and some of the setup commands were checked for correct spelling but never actually run. The program has never talked to a real vendor, and none of the cloud-network setup was built. The guide says all of this plainly and lists exactly which parts were tested — read that table before you promise anyone a delivery date.

## The One Thing to Remember

Run your own truck with your own permanent plate — that is the answer, and everything else is an attempt to avoid it. Before building it, ask the vendor three questions: will you accept a shared address range, will you accept a different kind of login, will you drop the address check for that login. One yes saves weeks of work, and asking costs nothing.

> For the full technical details, see the source document.

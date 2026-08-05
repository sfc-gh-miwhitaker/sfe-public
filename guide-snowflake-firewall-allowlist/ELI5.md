# ELI5: Snowflake Firewall Allowlisting

## The One-Sentence Version

Snowflake doesn't have a fixed list of IP addresses you can put in your firewall — you need to allowlist by website name (DNS) for outbound traffic, and use a special expiring IP list for inbound traffic.

## The Analogy

Think of Snowflake like a big office building that keeps moving floors between skyscrapers in a city (cloud provider). The **address** (hostname) stays the same — "Snowflake, Floor 5, Tower West" — but the building's **GPS coordinates** (IP address) might shift. Your security guard (firewall) needs to recognize the address name, not memorize GPS coordinates that change.

For the reverse direction — when Snowflake needs to visit your building — they do have a fixed set of company cars with known license plates (egress IPs). But those plates expire and get replaced, so your guard needs a system to check for new plates regularly.

## What the Network Admin Needs to Know

1. **"Let our users reach Snowflake"** → Allow specific website names (FQDNs) outbound on ports 443 and 80. Get the list from the Snowflake team. No static IPs exist for this direction.

2. **"Let Snowflake reach our servers"** → There IS a list of IP ranges you can add. But they expire. You need automation to refresh them.

3. **"I want zero internet exposure"** → Use PrivateLink. Traffic stays private, uses your own IP space. Problem solved permanently.

## Who Does What

| Person | Action |
|--------|--------|
| Snowflake admin | Runs `SYSTEM$ALLOWLIST()` and provides the hostname list |
| Network admin | Adds those hostnames to outbound firewall rules |
| Snowflake admin | Runs `SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES()` for inbound IPs |
| Network admin | Adds those CIDRs to inbound rules + sets up refresh automation |
| Both teams | Agree on PrivateLink if static-IP-only policy exists |

## The Bottom Line

The Snowflake team isn't stonewalling you. The IPs genuinely are dynamic — it's how cloud infrastructure works. The guide gives you the exact queries to ask for and the automation patterns to keep rules current.

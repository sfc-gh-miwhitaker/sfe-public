> Simplified from: [Connect Power BI to Snowflake Using Your Microsoft Login](README.md)

# Power BI + Snowflake OAuth — Plain Language Version

## One-Sentence Version

Instead of storing a Snowflake password inside Power BI, this guide switches Power BI to use your employees' regular Microsoft work logins — so Snowflake knows exactly who is looking at what.

---

## The Story

Think of Snowflake as a secure vault and Power BI as the window people use to look inside. Right now, there's probably one master key (a shared password) that Power BI uses for everyone. Whoever opens a report, the vault sees the same key holder — it can't tell Alice from Bob.

This guide replaces the master key with individual badges. Each employee's Microsoft login becomes their personal Snowflake badge. When Alice opens a report, Power BI asks Microsoft to vouch for her, Microsoft issues a temporary digital pass, and Snowflake checks it. Alice gets in as herself — and if she's not supposed to see certain data, Snowflake can enforce that automatically.

Setting this up takes three things: a few SQL commands in Snowflake, a one-time configuration in Microsoft Entra (your company's Microsoft identity system), and a settings change in Power BI.

The trickiest part isn't the setup — it's making sure every Power BI user's Snowflake account is linked to their work email address. A lot of Snowflake accounts were created with usernames like `ALICE_SMITH` instead of `alice@contoso.com`. When Microsoft sends `alice@contoso.com` as her badge, Snowflake can't find a match and the login fails. The guide walks through how to check for this and fix it.

---

## The Cast

| Concept | Plain language |
|---|---|
| **OAuth** | A system where Microsoft vouches for who your employees are, so they don't need a separate Snowflake password |
| **Microsoft Entra ID** | Your company's Microsoft identity system — the same one behind Office 365 and Teams |
| **SCIM** | An automated sync that creates and removes Snowflake accounts when you add/remove people in Entra groups |
| **Security integration** | A Snowflake setting that says "trust Microsoft's vouching system" |
| **LOGIN_NAME** | The field on each Snowflake user that must match their work email for the badge to work |
| **DirectQuery** | Power BI asks Snowflake live every time someone opens a report |
| **Import** | Power BI copies data on a schedule and shows the cached copy |

---

## What the setup involves

- **Snowflake (you):** Run two SQL blocks — one sets up the Microsoft trust, one sets up the automated user sync
- **Microsoft Entra (you or your IT team):** Follow one Microsoft tutorial to connect Entra to Snowflake
- **Power BI (you):** Change two settings — one in Desktop when connecting, one in Service after publishing

---

## The one thing that trips everyone up

Snowflake needs to know that `alice@contoso.com` in Microsoft is the same person as the `ALICE_SMITH` account in Snowflake. The way it makes that connection is by matching the Microsoft email to a field called `LOGIN_NAME` in Snowflake. If that field contains a username instead of an email address, the match fails — and the error message Power BI shows doesn't explain this clearly. The guide has a three-path decision for handling existing Snowflake accounts.

---

## The one thing to remember

Every Power BI user's Snowflake account needs a `LOGIN_NAME` that is their exact work email address. Everything else in the setup is a one-time configuration — this is the ongoing rule that keeps things working as people join and leave.

---

> For the full technical details, see the [README](README.md).

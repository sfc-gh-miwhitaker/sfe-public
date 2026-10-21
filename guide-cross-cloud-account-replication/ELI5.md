# Replicate a Snowflake Account from AWS to Azure, Explained Simply

Pair-programmed by SE Community + Cortex Code

## The short version

You have a Snowflake account in AWS. You want an identical twin in Azure that stays up to date, so you can switch to it if AWS has a bad day, or move there for good.

## The analogy

Think of a shop with a warehouse in one city. You open a second warehouse in another city and hire a truck that drives over every 10 minutes with whatever changed: new stock, new staff badges, new rules on the door. The second warehouse keeps its doors locked (read-only) until you say "this one is the main shop now."

- **The truck** is the *failover group*: one list of everything to copy, plus a schedule.
- **The shop's phone number** is the *connection URL*. Customers dial one number, and you choose which warehouse answers. Switching cities doesn't change the number.

## The five steps

1. **Look around** (read-only). Check that you're on Business Critical, see which Azure regions you can use, and list what can't be copied.
2. **Build the second warehouse.** An org admin creates the Azure account and allows both accounts to replicate.
3. **Load the truck** (AWS side). One command lists everything: users, roles, warehouses, databases, integrations, network rules, settings. A second command creates the shared phone number.
4. **Open the receiving dock** (Azure side). Create the matching copy. The first full delivery starts on its own.
5. **Check, and switch when ready.** Confirm deliveries are arriving. When you choose, make Azure the main shop with two commands.

## What the truck can't carry

Keys to other buildings. The Azure copy has its own ID badge, so anything outside Snowflake that trusted the AWS badge (S3 buckets, APIs, private network links) must also be told to trust the Azure one. People using MFA set it up once more. A few kinds of tables (external, hybrid, event, temporary) stay behind.

## Who pays

The Azure account pays for each delivery. The price depends on how much changed and how often the truck runs.

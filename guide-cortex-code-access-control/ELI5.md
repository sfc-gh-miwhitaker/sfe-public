# ELI5 — Cortex Code Access Control

Cortex Code (the AI coding assistant in Snowflake) is turned on for everyone by default. This guide shows an admin how to turn it off for most people and only allow specific teams to use it.

## The short version

1. Remove the default "everyone can use this" permission
2. Create a new role for people who should have access
3. Give that role to the right users
4. Watch usage with built-in SQL queries

## Why would you do this?

- Control AI credit spend before it surprises you
- Only enable CoCo for teams that actually need it
- Meet internal approval processes before rolling out new tools

## What's the catch?

- The permission that controls CoCo also controls other Cortex AI features (Agents, Analyst, Search). Revoking it blocks all of them, not just CoCo.
- People with ACCOUNTADMIN as a secondary role can still sneak through. The guide explains how to test accurately.
- There's up to a 1-hour delay before usage shows up in the monitoring views.

Pair-programmed by SE Community + Cortex Code

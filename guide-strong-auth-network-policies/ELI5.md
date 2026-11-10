# Network Policies from Login History, Explained Simply

Pair-programmed by SE Community + Cortex Code

**Last verified:** 2026-11-10 | **Expires:** 2027-01-09

## The problem

Snowflake is retiring the "just a password" way of signing in. People will need a second step, like a code on their phone. Programs that sign in by themselves (nightly loads, dashboards, scripts) will not be allowed to use passwords at all.

Those programs need a new kind of key. The most common one is a **programmatic access token**, which is like a long, hard-to-guess password that only works for one program and expires on a schedule. Snowflake adds one safety rule: by default, a program can only get and use this token if it is also limited to signing in from known places.

## The "known places" part

Every computer on the internet has an address, a bit like a street address. Snowflake already keeps a diary of every sign-in: who signed in, when, and from which address. A **network policy** is a guest list of addresses. Anyone not on the list is turned away at the door.

So the job is: read the diary, write a guest list for each program, and only then hand that program its new key.

## How the guide does it

1. **Find who needs help.** A short report lists every account still using a plain password, and spots programs that were never labelled as programs (Snowflake would otherwise treat them like people and ask them for a phone code they cannot give).
2. **Read the diary for each program.** Every address gets a label: seen often and recently (keep it), seen once (probably someone's laptop), not seen for a month (ask if it still exists), or only ever failed (do not trust it).
3. **Write a draft guest list.** The guide writes the commands for you but does not run them. Snowflake also has a built-in helper that suggests a list; the guide shows how to use it safely, because it includes every address it ever saw and reuses the same name every time.
4. **Practice first.** A pretend program lets you walk through every step without touching anything real.
5. **Change one program at a time, in a safe order.** Test the guest list against past sign-ins. Turn the list on while the old password still works, so a missing address shows up as one failed run you can fix. Only then give the program its new key and switch the old password off for good.
6. **Keep watching.** A weekly check shows anyone turned away at the door and any keys about to expire.

## Why the order matters

If you swap the key and turn on the guest list at the same time, and something breaks, you cannot tell which change caused it. Doing them one after the other means each problem has exactly one cause.

## What you need

An administrator role in Snowflake, a worksheet in the web interface, and the date your account must be ready by, which the Strong Authentication Hub in the Trust Center shows you.

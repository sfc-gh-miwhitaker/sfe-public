> Simplified from: guide-snowflake-ml-lifecycle/README.md

# Snowflake ML Lifecycle — Explained Simply

## One-Sentence Version

Snowflake can run the whole life of a machine learning model — ingredients, training, storage, serving, checkups, and billing — next to your data, but you have to test its speed on your own model.

## The Story

Think of a model as a dish a restaurant serves. The Feature Store is the prep kitchen: ingredients are cleaned and portioned once, so every cook uses the same ones. Training is testing the recipe. The Model Registry is the recipe binder, where each version is kept with notes on how well it did.

Serving comes in two styles. Batch scoring is catering: cook a big tray on a schedule. Real-time serving is the à la carte counter: an order comes in and a plate goes out in moments. A task graph is the weekly schedule that tells the kitchen to re-test the recipe with fresh ingredients.

A model monitor is the health inspector. It compares today's dishes to a reference plate and flags when things drift. Alerts are the phone call when the inspector finds a problem.

The team comparing this to their current kitchen on AWS wants to know if the counter is as fast. Nobody can honestly say without timing your dish, in your dining room, at your rush hour. So the guide gives you a stopwatch plan instead of a number.

## The Cast

- **Feature Store:** one shared place where model inputs are defined, so training and serving use the same logic.
- **ML Jobs:** your training code, sent to run on Snowflake machines called a compute pool.
- **Model Registry:** the versioned binder of models, with their scores and a marked "current" version.
- **Warehouse inference:** scoring big tables of data on a schedule.
- **SPCS model service:** a web address other apps call for instant predictions.
- **Model monitor:** a scheduled check for drift (inputs changing) and accuracy (predictions going wrong).
- **ML Lineage:** a record of which data trained which model, for auditors.

## What Changed

- Before: features, training, serving, and monitoring live in separate tools and copies of data.
- After: they live beside the data, under the same access rules as the data.
- Before: a model trained on AWS stays on AWS.
- After: it can be copied into the Snowflake binder and served here.

## What to Watch Out For

- **Idle machines still cost money.** A service can go to sleep after 30 idle minutes. The machine pool underneath keeps billing for its own idle time, one hour by default.
- **Cold start.** The first request after a nap waits while the service wakes up.
- **The reference plate must exist first.** The monitor copies its comparison data when it is created. If that table is empty, drift checks never work until you rebuild the monitor.
- **Lineage has gaps.** It does not track where predictions get written. It does not copy to other accounts.
- **Two binders drift apart.** If AWS stays the official record, never promote models in Snowflake.
- **No speed claims.** Measure both systems from where your real callers sit.

## The One Thing to Remember

Run your own model through a timed test before believing anyone's speed or cost comparison — including this one.

> For the full technical details, see the source document.

Pair-programmed by SE Community + Cortex Code

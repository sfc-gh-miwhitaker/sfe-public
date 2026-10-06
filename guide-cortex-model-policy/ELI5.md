# Choose the AI Models Your Team Can Use

Pair-programmed by SE Community + Cortex Code

> Simplified from: [Choose Which AI Models Your Snowflake Users Can Use](README.md)

## One-Sentence Version

Your administrator can approve specific AI models instead of automatically giving users access to every new model.

## The Story

Imagine a workshop where everyone's badge opens every tool cabinet, including cabinets installed next month. A new tool appears without anyone approving it individually. The badge already includes it.

You can replace that broad badge with permission for specific cabinets. First, give people access to the tools they need. Then remove every broad badge they can use, plus any separate permission for an unwanted tool.

There are two places broad access can come from: Snowflake's automatic permission and permissions your administrators added. Removing one does not remove the other. The guide helps your administrator inspect both before changing anything.

Finally, test as an ordinary worker, not the workshop administrator. An approved tool should work, and an excluded tool should fail because access was denied.

## The Cast

- **Model:** the AI engine doing the work; one tool in the workshop.
- **Account role:** a bundle of permissions, like a worker's badge.
- **Model application role:** permission to use a particular AI model.
- **All-models role:** permission covering current models and future releases.
- **Approved list:** the exact models your organization has chosen to permit.
- **Secondary roles:** additional active badges that can quietly restore access.
- **Account administrator:** the administrator who retains access to every model.

## What Changed

- Snowflake is retiring the older account setting for model lists.
- Model permissions are now the recommended way to control access.
- During the transition, the account's enabled software changes determine whether the old setting still participates.
- An explicit approved list keeps newly released models from automatically becoming usable through an all-models permission.

## What to Watch Out For

Granting one approved model does not block other models. Remove every permission path that still allows them.

An empty catalog is not enough proof. You might be looking in the wrong place. A failed request might mean regional unavailability rather than denied access.

Test the actual application and the user's normal permissions, not only a specially restricted test session. Administrators remain an exception.

Existing automated work might need models beyond those shown in a chat menu. Removing those permissions can interrupt that work.

Some models turn text into numbers for search. Their model restrictions require a specific software change to be enabled. Check this before claiming complete coverage.

A model developer's location does not establish where your request runs. Your organization can still decline that model under its own approval policy.

Seeing a model in a list does not prove anyone used it. Check usage records before drawing that conclusion.

The inventory worksheet changes nothing. Applying the later instructions changes real access, so an administrator must review them first.

## The One Thing to Remember

Approve the models you want, remove broad access, and prove the restriction works for real users.

> For the full technical details, see the source document.

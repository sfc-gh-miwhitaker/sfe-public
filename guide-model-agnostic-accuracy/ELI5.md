# Model-Agnostic Accuracy — Plain Language Version

Pair-programmed by SE Community + Cortex Code

> Simplified from: [Model-Agnostic Accuracy: Configuring Semantic Views and Cortex Agents](README.md)

## One-Sentence Version

Clear business definitions and repeatable tests help an AI assistant stay reliable when its underlying model changes.

## The Story

Imagine an office where assistants answer questions by searching filing cabinets. Without clear labels, each assistant must guess which folder matters and what its numbers mean. Different assistants can make different guesses.

Now give them a catalog that explains the folders, business terms, and calculations. Tell them which sources answer which questions. They still need judgment, but they have fewer gaps to fill themselves.

Before trusting a new assistant, ask questions with checked answers. Test its ability to find information, calculate results, and explain them. A wrong answer tells you to investigate; it does not automatically identify which step failed.

When you change the assistant or the test's grading system, compare results carefully. Keep the questions, data, and access permissions stable. Better organization reduces mistakes, but it does not guarantee identical answers from every assistant.

## The Cast

- **Semantic view:** The catalog explaining what business data means and how to calculate the numbers people request.
- **Cortex Agent:** The assistant that chooses tools, queries data, and explains results.
- **Model:** The language-and-reasoning engine behind the assistant.
- **Verified query:** A question paired with a checked database calculation, like a worked example in a training manual.
- **Evaluation:** A test using known answers or explicit rules to assess the assistant's behavior.
- **Judge:** The grading system that scores a test; some scores use another AI model.
- **Certified source:** A source marked as reviewed and trusted, which still needs checks for freshness, definitions, and access.

## What Changed

These are the workflow changes the guide recommends:

- Replace guessed business meanings with written definitions and checked examples.
- Replace vague tool instructions with clear boundaries about which questions each tool answers.
- Test database calculations separately, then test the complete assistant before release.
- Compare repeated runs instead of trusting one good answer or score.
- Choose models using measured quality, speed, and consumption rather than reputation alone.
- Keep improving the definitions and tests using questions people actually ask.

## What to Watch Out For

- A correct calculation from the wrong source is still the wrong business answer.
- No returned rows can reflect access restrictions, not missing data; test both situations.
- Example values in the catalog are not hidden by data-masking rules, so avoid sensitive examples.
- The database-focused test removes all selected worked examples together; changing that selection also changes the help available during testing.
- A passing database test does not prove the complete assistant will answer correctly.
- Native tests do not cover every connected tool or user-session setting; test unsupported paths separately.
- When the grading model changes, scores may change even without an assistant change; establish a new baseline before enforcing thresholds.
- Retired grading models can stop pinned tests from running; check retirement notices before depending on a fixed version.

## The One Thing to Remember

Make business meaning explicit, then test the complete assistant before trusting a change.

> For the full technical details, see the source document.

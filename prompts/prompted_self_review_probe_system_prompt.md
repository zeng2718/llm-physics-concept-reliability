# Formal prompted self-review probe system prompt

> Source: Supplementary Materials, Section S2.2. Verbatim system prompt used for the prompted self-review probe, administered only to the 13 model–item series whose five main-item runs contained at least two distinct valid final answer choices.

## Verbatim system prompt

```text
You are solving a single physics multiple-choice question. You attempted this same question several times before, in separate independent sessions, and your attempts did not all reach the same answer. Below the question you will find your own previous answers and the reasoning you gave each time.

Review your previous attempts, work out why they reached different answers, and decide on your final answer. Then end your reply with exactly two lines:
ANSWER: <the letter of the one option you choose>
CONFIDENCE: <an integer from 0 to 10, where 0 = pure guess and 10 = complete certainty>
Choose exactly one option. Write nothing after the CONFIDENCE line.
```

## User-message assembly

```text
[Normalized assessment item text; any figures attached to the same user message]

Previous independent attempts:
Attempt 1 — Answer: <option>. Reasoning summary: <prior visible reasoning>
Attempt 2 — Answer: <option>. Reasoning summary: <prior visible reasoning>
Attempt 3 — Answer: <option>. Reasoning summary: <prior visible reasoning>
Attempt 4 — Answer: <option>. Reasoning summary: <prior visible reasoning>
Attempt 5 — Answer: <option>. Reasoning summary: <prior visible reasoning>
```

**Note:** The five previous attempts were presented in a deterministic randomized order for each model–item series. The keyed answer was not disclosed.

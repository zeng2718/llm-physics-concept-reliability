# Main-item and isomorphic-variant system prompt

> Source: Supplementary Materials, Section S2.1. Verbatim system prompt used for all main-item runs (87 concept-inventory items) and all isomorphic-variant runs (25 author-constructed variants), across all four evaluated models.

## Verbatim system prompt

```text
You are solving a single physics multiple-choice question. Reason through it step by step, showing your full working. Then end your reply with exactly two lines:
ANSWER: <the letter of the one option you choose>
CONFIDENCE: <an integer from 0 to 10, where 0 = pure guess and 10 = complete certainty>
Choose exactly one option. Write nothing after the CONFIDENCE line.
```

## User-message assembly

The normalized assessment item text was supplied as the user message. Any associated PNG figures were attached to the same multimodal message. Each run began in a new session.

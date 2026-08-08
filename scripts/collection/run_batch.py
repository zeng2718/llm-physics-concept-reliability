#!/usr/bin/env python3
"""Collect formal main-item, isomorphic-variant, and prompted self-review runs.

Output is appended to ``results/{model}__{run_type}.jsonl`` and completed
item-run pairs are skipped when a batch is resumed.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import config
from items import load_items, load_variant_items, Item, is_plausible_option
from parse import parse_response
from adapters import build_adapter, build_user_content, Result
import adapters

_TIMEOUT_S = int(adapters._TIMEOUT.read or 600)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_done(out_path: Path) -> set[tuple[str, int]]:
    done = set()
    if out_path.exists():
        for line in out_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
                done.add((r["item_id"], r["run_index"]))
            except Exception:
                continue
    return done


def _is_timeout(e: Exception) -> bool:
    return "timeout" in type(e).__name__.lower() or "timed out" in str(e).lower()


def _call_with_retry(adapter, messages, retries=2, backoff=4.0) -> Result:
    """Retry transient failures, but do not retry a full request timeout."""
    last = None
    for attempt in range(retries):
        try:
            return adapter.complete(messages)
        except Exception as e:                      # noqa: BLE001
            last = e
            if _is_timeout(e):
                raise
            if attempt < retries - 1:
                time.sleep(backoff * (attempt + 1))
    raise last


def _record(model, item: Item, run_type, run_index, temperature,
            result: Result, parsed: dict, is_variant: bool = False) -> dict:
    valid_option = is_plausible_option(parsed["stated_letter"], item.options)
    # Mark a truncated or timed-out response without a valid answer as DNF;
    # any partial provider-exposed reasoning remains available for auditing.
    answered = parsed["parse_ok"] and parsed["stated_letter"] is not None
    status = "non_convergence" if (not answered and
             result.finish_reason in ("length", "timeout")) else "ok"
    return {
        "model": model,
        "item_id": item.item_id,
        "domain": item.domain,
        "run_type": run_type,
        "run_index": run_index,
        "is_variant": is_variant,
        "temperature": temperature,
        "has_figure": item.has_figure,
        "n_figures": len(item.figures),
        "reasoning": parsed["reasoning"],
        "stated_letter": parsed["stated_letter"],
        "valid_option": valid_option,
        "confidence": parsed["confidence"],
        "parse_ok": parsed["parse_ok"],
        "parse_notes": parsed["notes"],
        "reasoning_content": result.reasoning_content,
        "finish_reason": result.finish_reason,
        "usage": result.usage,
        "raw_response": result.content,
        "status": status,
        "timestamp": _now(),
    }


def _dnf_record(model, item: Item, run_type, run_index, temperature, error: str,
                is_variant: bool = False) -> dict:
    """Record a timeout as DNF so that a resumed batch does not retry it."""
    return {
        "model": model,
        "item_id": item.item_id,
        "domain": item.domain,
        "run_type": run_type,
        "run_index": run_index,
        "is_variant": is_variant,
        "temperature": temperature,
        "has_figure": item.has_figure,
        "n_figures": len(item.figures),
        "reasoning": "",
        "stated_letter": None,
        "valid_option": False,
        "confidence": None,
        "parse_ok": False,
        "parse_notes": f"DNF: non-convergence after >{int(_TIMEOUT_S)} s: {error}",
        "reasoning_content": None,
        "finish_reason": "timeout",
        "usage": {},
        "raw_response": "",
        "status": "non_convergence",
        "error": error,
        "timestamp": _now(),
    }


def run_main(adapter, item: Item, run_index, temperature, run_type) -> dict:
    user_content = build_user_content(item.text, item.figures)
    messages = [
        {"role": "system", "content": config.SYSTEM_PROMPT_MAIN},
        {"role": "user", "content": user_content},
    ]
    res = _call_with_retry(adapter, messages)
    parsed = parse_response(res.content)
    return _record(adapter_model, item, run_type, run_index, temperature, res, parsed)


def run_variant(adapter, item: Item, run_index, temperature) -> dict:
    """Run an isomorphic variant with the same prompt as a main item."""
    user_content = build_user_content(item.text, item.figures)
    messages = [
        {"role": "system", "content": config.SYSTEM_PROMPT_MAIN},
        {"role": "user", "content": user_content},
    ]
    res = _call_with_retry(adapter, messages)
    parsed = parse_response(res.content)
    return _record(adapter_model, item, "variant", run_index, temperature, res, parsed,
                   is_variant=True)


def _process_one(runner, adapter, it: Item, ri, eff_temp, run_type):
    """Execute one request and return ``(record, error)`` without file I/O."""
    try:
        rec = runner(adapter, it, ri, eff_temp, "main") if run_type == "main" \
            else runner(adapter, it, ri, eff_temp)
        return rec, None
    except NotImplementedError:
        raise
    except Exception as e:                       # noqa: BLE001
        return None, f"{type(e).__name__}: {e}"


_PROMPTED_SELF_REVIEW_PRIORS = None
_PROMPTED_SELF_REVIEW_SUMMARY_CAP = 10000


def _prompted_self_review_priors() -> dict:
    """Load the current model's five prior main-item runs by item ID."""
    global _PROMPTED_SELF_REVIEW_PRIORS
    if _PROMPTED_SELF_REVIEW_PRIORS is None:
        path = config.RESULTS_DIR / f"{adapter_model}__main.jsonl"
        if not path.exists():
            raise FileNotFoundError(f"Prompted self-review requires prior main-run data: {path}")
        by: dict = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            by.setdefault(r["item_id"], []).append(r)
        _PROMPTED_SELF_REVIEW_PRIORS = by
    return _PROMPTED_SELF_REVIEW_PRIORS


def run_prompted_self_review(adapter, item: Item, run_index, temperature) -> dict:
    """Run prompted self-review in a new session for an inconsistent series.

    The item and five prior answers/reasoning records are presented in an
    item-specific deterministic random order. Eligibility requires at least two
    distinct valid final answer choices across the five main-item runs.
    """
    attempts = [r for r in sorted(_prompted_self_review_priors().get(item.item_id, []),
                                  key=lambda x: x["run_index"])
                if r.get("parse_ok") and r.get("stated_letter")]
    if len(attempts) < 2 or len({a["stated_letter"] for a in attempts}) < 2:
        raise RuntimeError(
            f"{item.item_id}: ineligible for prompted self-review "
            f"({len(attempts)} valid attempts; "
            f"{len({a['stated_letter'] for a in attempts})} distinct choices)")
    # The frozen prefix preserves the exact deterministic ordering used in the
    # study; it is not a public name for the prompted self-review condition.
    seed = int(hashlib.md5(f"probe6:{item.item_id}".encode()).hexdigest()[:8], 16)
    shuffled = attempts[:]
    random.Random(seed).shuffle(shuffled)
    lines, meta = [], []
    for i, a in enumerate(shuffled, 1):
        reasoning = (a.get("reasoning") or "").strip()
        trunc = len(reasoning) > _PROMPTED_SELF_REVIEW_SUMMARY_CAP
        shown = reasoning[:_PROMPTED_SELF_REVIEW_SUMMARY_CAP] + (" …[truncated]" if trunc else "")
        lines.append(f"Attempt {i} — Answer: {a['stated_letter']}. Reasoning summary: {shown}")
        meta.append({"attempt_label": i, "src_run_index": a["run_index"],
                     "letter": a["stated_letter"], "reasoning_len": len(reasoning), "truncated": trunc})
    full_text = item.text.rstrip() + "\n\nPrevious independent attempts:\n" + "\n".join(lines)
    user_content = build_user_content(full_text, item.figures)
    messages = [
        {"role": "system", "content": config.SYSTEM_PROMPT_PROMPTED_SELF_REVIEW},
        {"role": "user", "content": user_content},
    ]
    res = _call_with_retry(adapter, messages)
    parsed = parse_response(res.content)
    rec = _record(
        adapter_model,
        item,
        "prompted_self_review",
        run_index,
        temperature,
        res,
        parsed,
    )
    rec["prompted_self_review_seed"] = seed
    rec["prompted_self_review_order"] = meta
    rec["prompted_self_review_prior_letters"] = [a["stated_letter"] for a in attempts]
    return rec


def summarize(records: list[dict]):
    n = len(records)
    if not n:
        print("No new runs in this batch.")
        return
    ok = sum(r["parse_ok"] for r in records)
    no_conf = sum(r["confidence"] is None for r in records)
    empty = sum(not r["reasoning"] for r in records)
    bad_opt = sum(r["stated_letter"] is not None and not r["valid_option"] for r in records)
    avg_len = sum(len(r["reasoning"]) for r in records) / n
    print("\nValidation summary")
    print(f"New runs: {n}")
    print(f"Parsed successfully: {ok}/{n}")
    print(f"Missing confidence: {no_conf}")
    print(f"Empty visible reasoning: {empty}")
    print(f"Invalid option labels: {bad_opt}")
    print(f"Mean reasoning length: {avg_len:.0f} characters")


def main():
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="kimi", choices=list(config.MODELS))
    ap.add_argument("--domains", default="F,EM,T")
    ap.add_argument("--run-type", default="main",
                    choices=["main", "variant", "prompted_self_review"])
    ap.add_argument("--runs", type=int, default=config.RUN_DEFAULTS["n_runs"])
    ap.add_argument("--limit", type=int, default=None, help="Run only the first N items")
    ap.add_argument("--items", default=None,
                    help="Comma-separated item IDs; takes precedence over --limit")
    ap.add_argument("--temperature", type=float, default=config.RUN_DEFAULTS["temperature"])
    ap.add_argument("--max-tokens", type=int, default=config.RUN_DEFAULTS["max_tokens"])
    ap.add_argument("--sleep", type=float, default=0.0, help="Delay after each serial request")
    ap.add_argument("--concurrency", type=int, default=1, help="Concurrent request count")
    ap.add_argument("--mock", action="store_true", help="Run the offline pipeline fixture")
    ap.add_argument("--out-dir", default=str(config.RESULTS_DIR))
    args = ap.parse_args()

    global adapter_model
    adapter_model = args.model
    spec = config.MODELS[args.model]
    domains = [d.strip() for d in args.domains.split(",") if d.strip()]
    items = load_variant_items() if args.run_type == "variant" else load_items(domains)
    if args.items:
        want = {s.strip() for s in args.items.split(",") if s.strip()}
        items = [it for it in items if it.item_id in want]
        missing = want - {it.item_id for it in items}
        if missing:
            print(f"Item IDs not found in the requested inventories: {sorted(missing)}")
    elif args.limit:
        items = items[: args.limit]

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{args.model}__{args.run_type}.jsonl"
    done = _load_done(out_path)

    adapter = build_adapter(spec, args.temperature, args.max_tokens, mock=args.mock)
    runner = {
        "main": run_main,
        "variant": run_variant,
        "prompted_self_review": run_prompted_self_review,
    }[args.run_type]
    if args.run_type == "prompted_self_review":
        priors = _prompted_self_review_priors()
        eligible = {
            item_id
            for item_id, attempts in priors.items()
            if len({
                r.get("stated_letter")
                for r in attempts
                if r.get("parse_ok") and r.get("stated_letter")
            }) >= 2
        }
        items = [item for item in items if item.item_id in eligible]

    # The recorded effective temperature can differ from a CLI value when the
    # provider fixes sampling for its reasoning mode.
    eff_temp = spec.get("effective_temperature", args.temperature)
    sent = "sent" if spec.get("send_temperature", True) else "provider-fixed; not sent"
    print(f"model={args.model} ({'MOCK' if args.mock else spec['model_id']}) | "
          f"items={len(items)} | runs/item={args.runs} | type={args.run_type} | "
          f"temperature={eff_temp} ({sent})")
    print(f"output={out_path} | previously completed={len(done)}")

    # Build the task list after excluding completed item-run pairs.
    tasks = [(it, ri) for it in items for ri in range(1, args.runs + 1)
             if (it.item_id, ri) not in done]
    total = len(tasks)
    conc = 1 if args.run_type == "prompted_self_review" else max(1, args.concurrency)
    if conc > 200:
        print(f"Warning: concurrency {conc} exceeds the configured account limit of 200")
    print(f"pending tasks={total} | concurrency={conc}")

    new_records = []
    counter = {"n": 0}

    def _write(rec, fh):
        fh.write(json.dumps(rec, ensure_ascii=False, default=str) + "\n")
        fh.flush()
        new_records.append(rec)

    def handle(rec, err, it, ri, fh):
        """Write one record and report progress from the main thread."""
        counter["n"] += 1
        idx = counter["n"]
        if err:
            # Record a timeout as DNF so resumable runs do not silently replace
            # it. Leave other transient errors unrecorded for an explicit retry.
            if "timeout" in err.lower() or "timed out" in err.lower():
                dnf = _dnf_record(adapter_model, it, args.run_type, ri, eff_temp, err,
                                  is_variant=(args.run_type == "variant"))
                _write(dnf, fh)
                print(f"[{idx}/{total}] {it.item_id} run{ri}: DNF recorded", flush=True)
            else:
                print(f"[{idx}/{total}] retryable error, not recorded: {it.item_id} run{ri}: {err}", flush=True)
            return
        _write(rec, fh)
        flag = "ok" if rec["parse_ok"] else f"!! {rec['parse_notes']}"
        print(f"[{idx}/{total}] {it.item_id} run{ri}: ans={rec['stated_letter']} "
              f"conf={rec['confidence']} [{flag}]", flush=True)

    with out_path.open("a", encoding="utf-8") as fh:
        if conc == 1:
            for it, ri in tasks:
                try:
                    rec, err = _process_one(runner, adapter, it, ri, eff_temp, args.run_type)
                except NotImplementedError as e:
                    print(f"[skip] {e}")
                    summarize(new_records)
                    return
                handle(rec, err, it, ri, fh)
                if args.sleep:
                    time.sleep(args.sleep)
        else:
            from concurrent.futures import ThreadPoolExecutor, as_completed
            with ThreadPoolExecutor(max_workers=conc) as ex:
                futs = {ex.submit(_process_one, runner, adapter, it, ri, eff_temp, args.run_type): (it, ri)
                        for it, ri in tasks}
                for fut in as_completed(futs):
                    it, ri = futs[fut]
                    rec, err = fut.result()
                    handle(rec, err, it, ri, fh)

    summarize(new_records)


if __name__ == "__main__":
    main()

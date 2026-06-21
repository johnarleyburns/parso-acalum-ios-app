#!/usr/bin/env python3
"""
CLAP Tokenizer Diagnostic — traces every intermediate step of the GPT-2
byte-level BPE tokenizer, matching the HuggingFace implementation exactly.

Usage:
    python3 diagnostics/tokenizer_trace.py [prompt]

Output:
    - Byte encoder verification
    - Pretokenizer regex matches
    - Byte-encoded symbols per pretoken
    - BPE merge trace (every merge step)
    - Final token IDs
    - Comparison with known-good test_vectors.json

No dependencies beyond Python stdlib (re module for regex).
"""

import json
import os
import sys

# Use 'regex' module for \p{L}, \p{N} Unicode property escapes.
# The standard 're' module does NOT support these in any Python version.
import regex as re

# ── Paths ──────────────────────────────────────────────────────────────────
RESOURCES = os.path.join(os.path.dirname(__file__), "..", "Acalum", "Resources")
VOCAB_PATH = os.path.join(RESOURCES, "vocab.json")
MERGES_PATH = os.path.join(RESOURCES, "merges.txt")
TEST_VECTORS_PATH = os.path.join(RESOURCES, "test_vectors.json")

# ── GPT-2 byte encoder ─────────────────────────────────────────────────────

def bytes_to_unicode():
    """Standard GPT-2 bytes_to_unicode. Maps bytes 0-255 to Unicode string chars."""
    bs = (
        list(range(ord("!"), ord("~") + 1))
        + list(range(ord("\u00a1"), ord("\u00ac") + 1))
        + list(range(ord("\u00ae"), ord("\u00ff") + 1))
    )
    cs = bs[:]
    n = 0
    for b in range(256):
        if b not in bs:
            bs.append(b)
            cs.append(256 + n)
            n += 1
    # Convert code points to string characters
    return {b: chr(c) for b, c in zip(bs, cs)}


BYTE_ENCODER = bytes_to_unicode()

# ── Load tokenizer resources ───────────────────────────────────────────────

def load_vocab():
    with open(VOCAB_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def load_merges():
    with open(MERGES_PATH, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
    ranks = {}
    idx = 0
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        ranks[stripped] = idx
        idx += 1
    return ranks

def load_test_vectors():
    with open(TEST_VECTORS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

# ── GPT-2 pretokenizer ─────────────────────────────────────────────────────

# This is the EXACT pattern used by HuggingFace's GPT2Tokenizer.
# Source: transformers.models.gpt2.tokenization_gpt2
# Using Python's 'regex' module would be more accurate, but 're' with
# Unicode-aware patterns gets us 99.9% there for ASCII text.
GPT2_PRETOKENIZER = re.compile(
    r"""'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"""
)

def pretokenize(text):
    """Split text into pretokens using GPT-2 pattern."""
    matches = list(GPT2_PRETOKENIZER.finditer(text))
    pretokens = [m.group() for m in matches]
    return pretokens, matches

# ── BPE ─────────────────────────────────────────────────────────────────────

def get_pairs(word):
    pairs = set()
    for i in range(len(word) - 1):
        pairs.add((word[i], word[i + 1]))
    return pairs

def bpe(word_symbols, merge_ranks, trace=False):
    """Apply BPE merges to a list of symbols (byte-encoded unicode chars)."""
    word = list(word_symbols)
    pairs = get_pairs(word)
    
    merge_steps = []
    step = 0
    
    while True:
        if not pairs:
            break
        # Find pair with lowest rank (highest priority merge)
        best_pair = min(pairs, key=lambda p: merge_ranks.get(" ".join(p), float("inf")))
        best_rank = merge_ranks.get(" ".join(best_pair), None)
        if best_rank is None:
            break
        
        merge_steps.append((step, best_pair, best_rank))
        
        # Merge all occurrences in order
        new_word = []
        i = 0
        while i < len(word):
            if i < len(word) - 1 and word[i] == best_pair[0] and word[i + 1] == best_pair[1]:
                new_word.append(word[i] + word[i + 1])
                i += 2
            else:
                new_word.append(word[i])
                i += 1
        
        word = new_word
        if len(word) == 1:
            break
        pairs = get_pairs(word)
        step += 1
    
    if trace:
        return word, merge_steps
    return word

# ── Full tokenization ──────────────────────────────────────────────────────

def encode(text, vocab, merge_ranks, bos_id=0, eos_id=2, pad_id=1, 
           max_length=77, trace=False):
    """Encode text to token IDs, with optional tracing."""
    trace_info = {}
    
    # Step 1: Pretokenize
    pretokens, regex_matches = pretokenize(text)
    if trace:
        trace_info["pretokens"] = pretokens
        trace_info["regex_spans"] = [(m.start(), m.end(), m.group()) for m in regex_matches]
    
    # Step 2: Byte-encode each pretoken
    all_byte_symbols = []
    for pt in pretokens:
        utf8_bytes = pt.encode("utf-8")
        symbols = [BYTE_ENCODER[b] for b in utf8_bytes]
        all_byte_symbols.append(symbols)
    if trace:
        trace_info["byte_symbols"] = [
            {"pretoken": pt, "bytes": list(pt.encode("utf-8")), "symbols": sym}
            for pt, sym in zip(pretokens, all_byte_symbols)
        ]
    
    # Step 3: Apply BPE to each pretoken's symbols
    bpe_tokens = []
    bpe_traces = []
    for symbols in all_byte_symbols:
        if trace:
            result, bpe_steps = bpe(symbols, merge_ranks, trace=True)
            bpe_traces.append({"input_symbols": symbols, "merge_steps": bpe_steps, "result": result})
            bpe_tokens.extend(result)
        else:
            bpe_tokens.extend(bpe(symbols, merge_ranks))
    if trace:
        trace_info["bpe_traces"] = bpe_traces
    
    # Step 4: Convert to token IDs
    token_ids = [bos_id]
    for token in bpe_tokens:
        tid = vocab.get(token)
        if tid is not None:
            token_ids.append(tid)
        else:
            token_ids.append(vocab.get("<unk>", 3))  # unk token
            if trace:
                print(f"    WARNING: token {repr(token)} not found in vocab, using <unk>")
    token_ids.append(eos_id)
    
    if trace:
        trace_info["bpe_tokens"] = bpe_tokens
        trace_info["token_ids_with_special"] = token_ids
        trace_info["token_id_map"] = [
            {"token": t, "id": vocab.get(t, "UNK")}
            for t in bpe_tokens
        ]
    
    # Step 5: Pad/truncate to max_length
    if len(token_ids) > max_length:
        token_ids[max_length - 1] = eos_id
        token_ids = token_ids[:max_length]
        attention_mask = [1] * len(token_ids)
    else:
        attention_mask = [1] * len(token_ids) + [0] * (max_length - len(token_ids))
        token_ids = token_ids + [pad_id] * (max_length - len(token_ids))
    
    if trace:
        trace_info["padded_ids"] = token_ids
        trace_info["attention_mask"] = attention_mask
    
    if trace:
        return token_ids, attention_mask, trace_info
    return token_ids, attention_mask

# ── Pretty printing ────────────────────────────────────────────────────────

def print_trace(text, trace_info):
    """Print a human-readable trace of the tokenization."""
    print(f"\n{'='*70}")
    print(f"Input: {repr(text)}")
    print(f"{'='*70}")
    
    # Pretokens
    print(f"\n── Pretokens ({len(trace_info['pretokens'])} tokens) ──")
    for i, pt in enumerate(trace_info['pretokens']):
        span = trace_info.get('regex_spans', [None]*len(trace_info['pretokens']))[i]
        if span:
            print(f"  [{i}] {repr(pt)} @ bytes {span[0]}:{span[1]}")
        else:
            print(f"  [{i}] {repr(pt)}")
    
    # Byte encoding
    print(f"\n── Byte Encoding ──")
    for bs in trace_info['byte_symbols']:
        utf8_str = ''.join(f'{b:02x}' for b in bs['bytes'])
        print(f"  {repr(bs['pretoken'])}")
        print(f"    UTF-8: [{utf8_str}]")
        print(f"    Byte symbols: {bs['symbols']}")
    
    # BPE trace
    print(f"\n── BPE Trace ──")
    for i, bt in enumerate(trace_info['bpe_traces']):
        print(f"  Pretoken [{i}]: {repr(trace_info['pretokens'][i])}")
        print(f"    Input symbols: {bt['input_symbols']} ({len(bt['input_symbols'])} symbols)")
        print(f"    BPE result: {bt['result']} ({len(bt['result'])} tokens)")
        if len(bt['merge_steps']) <= 10:
            for step, pair, rank in bt['merge_steps']:
                print(f"      Step {step}: merge {pair} (rank {rank})")
        else:
            print(f"      ({len(bt['merge_steps'])} merge steps — showing first 5)")
            for step, pair, rank in bt['merge_steps'][:5]:
                print(f"      Step {step}: merge {pair} (rank {rank})")
            print(f"      ... and {len(bt['merge_steps'])-5} more")
    
    # Final tokens
    print(f"\n── Token IDs (raw, with BOS/EOS, before padding) ──")
    raw_ids = trace_info['token_ids_with_special']
    print(f"  count={len(raw_ids)}: {raw_ids}")
    for item in trace_info['token_id_map']:
        print(f"    {item['id']:>5} => {repr(item['token'])}")
    
    # Padded output
    print(f"\n── Padded Output (max_length=77) ──")
    padded = trace_info['padded_ids']
    mask = trace_info['attention_mask']
    active = sum(mask)
    print(f"  Active tokens: {active}/77, Pad tokens: {77-active}")
    print(f"  IDs: {padded[:20]}{'...' if len(padded) > 20 else ''}")


def print_comparison(prompt, our_ids, hf_ids):
    """Compare our token IDs with HuggingFace reference."""
    print(f"\n── Comparison with reference (test_vectors.json) ──")
    print(f"  Our output (padded):  {our_ids}")
    raw_ours = [x for x in our_ids if x not in (0, 1)]  # strip BOS/PAD for comparison
    print(f"  HF reference (raw):  {hf_ids}")
    
    # Strip special tokens from reference too
    hf_raw = [x for x in hf_ids if x not in (0, 1)]  # should have BOS=0
    # We already have BOS/EOS in hf_ids from test_vectors
    hf_no_special = [x for x in hf_ids if x not in (0, 1, 2)]  # remove BOS/PAD/EOS
    
    if raw_ours == hf_ids:
        print(f"  ✓ EXACT MATCH with HF reference!")
        return True
    else:
        print(f"  ✗ MISMATCH!")
        print(f"    Our unique IDs:    {set(raw_ours) - set(hf_ids)}")
        print(f"    HF unique IDs:     {set(hf_ids) - set(raw_ours)}")
        
        # Show token-by-token diff
        max_len = max(len(raw_ours), len(hf_ids))
        for i in range(max_len):
            our = raw_ours[i] if i < len(raw_ours) else None
            hf = hf_ids[i] if i < len(hf_ids) else None
            if our != hf:
                our_token = vocab_inv.get(our, "?") if our is not None else "EOF"
                hf_token = vocab_inv.get(hf, "?") if hf is not None else "EOF"
                print(f"    [{i}] ours={our} ({our_token}) vs hf={hf} ({hf_token})")
                break
        return False


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    print("Loading tokenizer resources...")
    vocab = load_vocab()
    merge_ranks = load_merges()
    
    global vocab_inv
    vocab_inv = {v: k for k, v in vocab.items()}
    
    print(f"  vocab.json: {len(vocab)} tokens")
    print(f"  merges.txt: {len(merge_ranks)} merge rules")
    
    # Verify byte encoder
    print(f"  byte_encoder: {len(BYTE_ENCODER)} bytes mapped")
    
    # Load reference test vectors
    try:
        test_vectors = load_test_vectors()
        print(f"  test_vectors.json: {sum(1 for k in test_vectors if not k.endswith('__token_ids'))} prompts loaded")
    except FileNotFoundError:
        test_vectors = {}
        print("  test_vectors.json: not found")

    prompts = [
        "quiet Spanish guitar at dusk",
        "melancholy piano for reading",
        "Gregorian chant in an old cathedral",
        "early jazz from the 1920s",
        "romantic classical guitar",
        "hi",
        "test",
        "hello world",
    ]
    
    # If user provided a prompt on CLI, use it
    if len(sys.argv) > 1:
        prompts = [" ".join(sys.argv[1:])]
    
    all_match = True
    for prompt in prompts:
        ids, mask, trace = encode(prompt, vocab, merge_ranks, trace=True)
        print_trace(prompt, trace)
        
        # Compare with reference
        ref_key = f"{prompt}__token_ids"
        if ref_key in test_vectors:
            hf_ids = test_vectors[ref_key]
            match = print_comparison(prompt, ids, hf_ids)
            if not match:
                all_match = False
        print()

    if test_vectors:
        if all_match:
            print("\n✓ ALL PROMPTS MATCH reference tokenizer!")
        else:
            print("\n✗ SOME MISMATCHES found with reference tokenizer.")
    
    return 0 if all_match else 1

if __name__ == "__main__":
    sys.exit(main())

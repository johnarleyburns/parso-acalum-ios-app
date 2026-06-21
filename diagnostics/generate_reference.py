#!/usr/bin/env python3
"""Extract reference trace from HuggingFace tokenizer for comparison with Swift."""
import json
import os
import sys

# Use 'regex' module for \p{L}, \p{N} Unicode property escapes.
import regex as re

RESOURCES = os.path.join(os.path.dirname(__file__), "..", "Acalum", "Resources")
VOCAB_PATH = os.path.join(RESOURCES, "vocab.json")
MERGES_PATH = os.path.join(RESOURCES, "merges.txt")

def bytes_to_unicode():
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
    return {b: chr(c) for b, c in zip(bs, cs)}

BYTE_ENCODER = bytes_to_unicode()
GPT2_PRETOKENIZER = re.compile(
    r"""'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"""
)

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

def pretokenize(text):
    matches = list(GPT2_PRETOKENIZER.finditer(text))
    return [m.group() for m in matches]

def get_pairs(word):
    return {(word[i], word[i + 1]) for i in range(len(word) - 1)}

def bpe(word_symbols, merge_ranks):
    word = list(word_symbols)
    pairs = get_pairs(word)
    while True:
        if not pairs:
            break
        best_pair = min(pairs, key=lambda p: merge_ranks.get(" ".join(p), float("inf")))
        best_rank = merge_ranks.get(" ".join(best_pair))
        if best_rank is None:
            break
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
    return word

def encode_full(text, vocab, merge_ranks, bos_id=0, eos_id=2):
    pretokens = pretokenize(text)
    bpe_tokens = []
    for pt in pretokens:
        utf8_bytes = pt.encode("utf-8")
        symbols = [BYTE_ENCODER[b] for b in utf8_bytes]
        merged = bpe(symbols, merge_ranks)
        bpe_tokens.extend(merged)
    
    token_ids = [bos_id]
    for token in bpe_tokens:
        tid = vocab.get(token)
        if tid is not None:
            token_ids.append(tid)
        else:
            token_ids.append(vocab.get("<unk>", 3))
    token_ids.append(eos_id)
    return token_ids, bpe_tokens

def generate_reference(prompts):
    vocab = load_vocab()
    merge_ranks = load_merges()
    
    reference = {}
    for prompt in prompts:
        pretokens = pretokenize(prompt)
        bpe_tokens_list = []
        for pt in pretokens:
            utf8_bytes = list(pt.encode("utf-8"))
            symbols = [BYTE_ENCODER[b] for b in utf8_bytes]
            merged = bpe(symbols, merge_ranks)
            bpe_tokens_list.append({
                "pretoken": pt,
                "utf8_bytes": utf8_bytes,
                "byte_symbols": symbols,
                "bpe_result": merged,
            })
        
        token_ids, all_bpe_tokens = encode_full(prompt, vocab, merge_ranks)
        
        reference[prompt] = {
            "pretokens": pretokens,
            "details": bpe_tokens_list,
            "all_bpe_tokens": all_bpe_tokens,
            "token_ids": token_ids,
        }
    
    return reference

# ── Main ────────────────────────────────────────────────────────────────────
PROMPTS = [
    "quiet Spanish guitar at dusk",
    "melancholy piano for reading",
    "Gregorian chant in an old cathedral",
    "early jazz from the 1920s",
    "romantic classical guitar",
    "soft public domain music for sleep",
    "baroque strings and harpsichord",
    "nostalgic old recordings",
    "peaceful violin music",
    "dramatic organ music",
    "hi",
    "test",
    "hello world",
]

ref = generate_reference(PROMPTS)

OUTFILE = os.path.join(os.path.dirname(__file__), "reference_trace.json")
with open(OUTFILE, "w") as f:
    json.dump(ref, f, indent=2, ensure_ascii=False)

print(f"Wrote reference trace to {OUTFILE}")
print(f"Prompts: {len(ref)}")

# Also print a compact summary for easy comparison
for prompt in PROMPTS:
    r = ref[prompt]
    print(f"\n{prompt}")
    print(f"  pretokens: {r['pretokens']}")
    print(f"  bpe_tokens: {r['all_bpe_tokens']}")
    print(f"  token_ids:  {r['token_ids']}")

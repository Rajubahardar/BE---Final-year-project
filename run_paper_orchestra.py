import os
import re
import json
import time
import shutil
from difflib import SequenceMatcher
from pathlib import Path
import requests
from google import genai
from google.genai import types

ROOT = Path(__file__).resolve().parent
IN_DIR = ROOT / "paper_orchestra_input"
OUT_DIR = ROOT / "paper_orchestra_output"
OUT_DIR.mkdir(parents=True, exist_ok=True)
(OUT_DIR / "figures").mkdir(parents=True, exist_ok=True)

MODEL = "gemini-3-flash-preview"
S2_API_KEY = os.getenv("S2_API_KEY", "")
MIN_INTERVAL_SEC = 14.0  # Keeps throughput <= 4.2 RPM (strictly under 5 RPM Free Tier cap)
_last_call_ts = 0.0

client = genai.Client(http_options=types.HttpOptions(api_version="v1beta"))


def call_gemini(contents: str, json_mode: bool = False) -> str:
    global _last_call_ts
    for attempt in range(1, 6):
        wait = MIN_INTERVAL_SEC - (time.time() - _last_call_ts)
        if wait > 0:
            time.sleep(wait)
        try:
            _last_call_ts = time.time()
            cfg = types.GenerateContentConfig(response_mime_type="application/json") if json_mode else None
            resp = client.models.generate_content(model=MODEL, contents=contents, config=cfg)
            return resp.text
        except Exception as e:
            err_str = str(e)
            if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                m = re.search(r"retry in (\d+)", err_str, flags=re.IGNORECASE)
                sleep_s = int(m.group(1)) + 5 if m else 65
                print(f"   Rate limit hit (attempt {attempt}/5). Sleeping {sleep_s}s...")
                time.sleep(sleep_s)
            else:
                raise
    raise RuntimeError("Exceeded retry attempts due to Gemini rate limits.")


def extract_block(text: str, lang: str) -> str:
    m = re.search(rf"```{lang}\s*(.*?)```", text, flags=re.DOTALL | re.IGNORECASE)
    return m.group(1).strip() if m else text.strip()


for fig in (IN_DIR / "figures").glob("*.png"):
    dst = OUT_DIR / "figures" / fig.name
    if not dst.exists():
        try:
            shutil.copyfile(fig, dst)
        except Exception:
            pass

idea_md = (IN_DIR / "idea.md").read_text(encoding="utf-8")
exp_log = (IN_DIR / "experimental_log.md").read_text(encoding="utf-8")
template_tex = (IN_DIR / "template.tex").read_text(encoding="utf-8")
guidelines_md = (IN_DIR / "conference_guidelines.md").read_text(encoding="utf-8")
det_path = IN_DIR / "deterministic_tables.tex"
det_tables = det_path.read_text(encoding="utf-8") if det_path.exists() else ""
available_figs = sorted([f.name for f in (IN_DIR / "figures").glob("*.png")])


# =========================================================================
# STAGE 1: OUTLINE AGENT (Reuses cached outline.json if already generated)
# =========================================================================
outline_file = OUT_DIR / "outline.json"
if outline_file.exists() and outline_file.stat().st_size > 50:
    print("[Stage 1/5] Loaded cached outline.json")
    outline = json.loads(outline_file.read_text(encoding="utf-8"))
else:
    print("[Stage 1/5] Running Outline Agent...")
    outline_prompt = f"""
    You are a senior power-systems researcher drafting an IEEE paper.
    Convert idea.md, experimental_log.md, template.tex, and conference_guidelines.md into a single valid JSON object with keys:
    - "intro_search_queries": list of 4 targeted search queries for foundational grid-forming inverter & WSCC 9-bus papers.
    - "related_work_queries": list of 6 targeted search queries covering (a) PLL weak-grid instability in GFL inverters, (b) Virtual Synchronous Generators & RoCoF feedforward, and (c) Synchronverters & multi-domain EMT/phasor simulation.
    - "section_plan": detailed writing bullets for Abstract, Introduction, Related Work, Methodology, Experiments, Sensitivity Analysis, and Conclusion.

    [IDEA]\n{idea_md}\n[EXPERIMENTAL LOG]\n{exp_log}\n[GUIDELINES]\n{guidelines_md}
    """
    outline = json.loads(call_gemini(outline_prompt, json_mode=True))
    outline_file.write_text(json.dumps(outline, indent=2), encoding="utf-8")


# =========================================================================
# STAGE 2: PLOTTING AGENT (Single batched JSON call for all figure captions)
# =========================================================================
cap_file = OUT_DIR / "figure_captions.json"
if cap_file.exists() and cap_file.stat().st_size > 50:
    print("[Stage 2/5] Loaded cached figure_captions.json")
    captions = json.loads(cap_file.read_text(encoding="utf-8"))
else:
    print("[Stage 2/5] Generating IEEE captions for all figures (batched)...")
    cap_prompt = f"""
    Generate concise, publication-grade IEEE figure captions for every filename in {json.dumps(available_figs)}.
    Return a single JSON object mapping each exact filename to its plain-text caption.
    Rules: Plain text only, NO 'Figure X:' prefix, NO markdown bold/italics.
    Context:\n{idea_md[:1800]}
    """
    captions = json.loads(call_gemini(cap_prompt, json_mode=True))
    cap_file.write_text(json.dumps(captions, indent=2), encoding="utf-8")


# =========================================================================
# STAGE 3: LITERATURE REVIEW AGENT (Batched discovery + Semantic Scholar)
# =========================================================================
bib_file = OUT_DIR / "references.bib"
cmap_file = OUT_DIR / "citation_map.json"
lit_file = OUT_DIR / "draft_lit.tex"

if cmap_file.exists() and cmap_file.stat().st_size > 50:
    print("[Stage 3/5] Loaded cached citation_map.json")
    verified_papers = json.loads(cmap_file.read_text(encoding="utf-8"))
else:
    print("[Stage 3/5] Discovering & verifying real citations via Semantic Scholar...")
    queries = outline.get("intro_search_queries", []) + outline.get("related_work_queries", [])
    cand_text = call_gemini(
        "List 25 real, well-known peer-reviewed IEEE/academic paper titles (with first author and year) "
        f"covering these topics:\n{json.dumps(queries)}\nReturn one paper per line, plain text only."
    )
    candidate_titles = [
        re.sub(r"^[\-\*\d\.\)\s]+", "", line).strip()
        for line in cand_text.splitlines()
        if len(line.strip()) > 15
    ]

    verified_papers = {}
    headers = {"x-api-key": S2_API_KEY} if S2_API_KEY else {}
    for raw_title in candidate_titles[:25]:
        query_str = re.sub(r"\(.*?\)", "", raw_title)[:140]
        try:
            r = requests.get(
                "https://api.semanticscholar.org/graph/v1/paper/search",
                params={"query": query_str, "limit": 1, "fields": "title,authors,year,venue,abstract"},
                headers=headers,
                timeout=15,
            )
            time.sleep(1.1)
            if r.status_code == 200 and r.json().get("data"):
                p = r.json()["data"][0]
                ratio = SequenceMatcher(None, query_str.lower(), p["title"].lower()).ratio()
                if ratio >= 0.65 and p.get("authors") and p.get("year"):
                    first_last = re.sub(r"[^A-Za-z]", "", p["authors"][0]["name"].split()[-1])
                    key = f"{first_last}{p['year']}_{p['paperId'][:5]}"
                    verified_papers[key] = p
        except Exception:
            continue

    bib_entries = []
    for key, p in verified_papers.items():
        authors_bib = " and ".join(a["name"] for a in p["authors"])
        venue = p.get("venue") or "IEEE Transactions on Power Systems"
        bib_entries.append(
            f"@article{{{key},\n"
            f"  title={{{p['title']}}},\n"
            f"  author={{{authors_bib}}},\n"
            f"  journal={{{venue}}},\n"
            f"  year={{{p['year']}}}\n}}"
        )
    bib_file.write_text("\n\n".join(bib_entries), encoding="utf-8")
    cmap_file.write_text(json.dumps(verified_papers, indent=2), encoding="utf-8")
    print(f"   Verified {len(verified_papers)} authentic papers in references.bib")

if lit_file.exists() and lit_file.stat().st_size > 200:
    draft_tex = lit_file.read_text(encoding="utf-8")
else:
    print("[Stage 3/5] Drafting Introduction and Related Work...")
    lit_prompt = f"""
    Role: Senior Power Systems Researcher.
    Fill ONLY the Introduction and Related Work sections of template.tex using ONLY citation keys from the verified papers below.
    Do NOT invent citations. Cite at least 80% of the verified papers.
    Return the complete updated LaTeX file wrapped in ```latex ... ```.

    [VERIFIED PAPERS]\n{json.dumps({k: {'title': v['title'], 'year': v['year'], 'abstract': (v.get('abstract') or '')[:350]} for k, v in verified_papers.items()}, indent=2)}
    [OUTLINE]\n{json.dumps(outline, indent=2)}
    [IDEA]\n{idea_md}
    [TEMPLATE]\n{template_tex}
    """
    draft_tex = extract_block(call_gemini(lit_prompt), "latex")
    lit_file.write_text(draft_tex, encoding="utf-8")


# =========================================================================
# STAGE 4: SECTION WRITING AGENT
# =========================================================================
v0_file = OUT_DIR / "paper_v0.tex"
if v0_file.exists() and v0_file.stat().st_size > 500:
    print("[Stage 4/5] Loaded cached paper_v0.tex")
    draft_tex = v0_file.read_text(encoding="utf-8")
else:
    print("[Stage 4/5] Drafting Methodology, Experiments, Sensitivity & Conclusion...")
    write_prompt = f"""
    Role: Senior Power Systems Researcher.
    Complete all remaining placeholder sections in the LaTeX manuscript (Abstract, Methodology, Experiments, Sensitivity Analysis, Conclusion).
    Critical Rules:
    1. Keep the already-written Introduction and Related Work intact.
    2. Embed the exact pre-generated booktabs table code provided in [DETERMINISTIC TABLES] without changing a single digit.
    3. Include figures from figures/ using \\includegraphics[width=\\columnwidth]{{figures/<filename>}} with the plain-text captions in [CAPTIONS].
    4. Use formal equations from [IDEA] and exact numbers from [EXPERIMENTAL LOG]. Never claim hardware-in-the-loop tests.
    5. Return the FULL compilable LaTeX file wrapped in ```latex ... ```.

    [CURRENT LATEX]\n{draft_tex}
    [DETERMINISTIC TABLES]\n{det_tables}
    [CAPTIONS]\n{json.dumps(captions, indent=2)}
    [IDEA]\n{idea_md}
    [EXPERIMENTAL LOG]\n{exp_log}
    """
    draft_tex = extract_block(call_gemini(write_prompt), "latex")
    v0_file.write_text(draft_tex, encoding="utf-8")


# =========================================================================
# STAGE 5: CONTENT REFINEMENT AGENT (1-Round Simulated Peer Review)
# =========================================================================
print("[Stage 5/5] Running IEEE Peer-Review Critique & Refinement...")
rev_text = call_gemini(
    "Act as a strict IEEE Transactions reviewer. List 4 concrete weaknesses in clarity, "
    "equation variable definitions, or physical interpretation of S1-S4 and (H, D) results. "
    "Do NOT request new simulations.\n\n" + draft_tex
)
draft_tex = extract_block(
    call_gemini(
        "Revise the LaTeX paper to address the reviewer feedback below. "
        "Preserve all numeric values from experimental_log.md and deterministic_tables.tex, "
        "keep all \\cite{...} keys valid against references.bib, and return the FULL LaTeX file in ```latex ... ```.\n\n"
        f"[REVIEWER FEEDBACK]\n{rev_text}\n[EXPERIMENTAL LOG]\n{exp_log}\n[CURRENT LATEX]\n{draft_tex}"
    ),
    "latex",
)

(OUT_DIR / "paper.tex").write_text(draft_tex, encoding="utf-8")
(OUT_DIR / "worklog.json").write_text(json.dumps([{"round": 1, "review": rev_text}], indent=2), encoding="utf-8")
print("Done! Final manuscript saved to:", OUT_DIR / "paper.tex")
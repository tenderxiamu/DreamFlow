"""用真实人设 prompt 跑多轮对话，比较模型质量与延迟。"""
import json, re, time, sys, urllib.request

KEY = "wbpk_pUURzTry1oNEGkRUYBORY5_fbRCvGIGwL0DglMprAzUX9yhrocoDCeK"
URL = "https://dreamflow-sleep.app.workbuddy.host/.cloud/llm/chat/completions"
DART = "dreamflow_flutter/lib/data/df_persona.dart"

src = open(DART, encoding="utf-8").read()
m = re.search(r"static const String core = r'''(.*?)''';", src, re.S)
CORE = m.group(1)


def system(now_label="2026年10月28日 周三 23:47", stage="现在是深夜，他很可能是躺下了还睡不着。回复要更短、更轻，最多两句，尽量不提问，不要把他聊精神起来。", round_=0):
    s = CORE + "\n【此刻】\n现在是 " + now_label + "。\n" + stage + "\n"
    if round_ > 0:
        s += f"这是你们今天聊的第 {round_} 轮之后的回复，不要再用开场白，直接接住他上一句。\n"
    return s


TURNS = [
    "今天开会被领导当众说了一顿，现在躺床上脑子里全是那个画面",
    "就是觉得自己挺没用的",
    "嗯",
    "你是谁啊",
    "我最近总是凌晨三点醒，怎么办",
    "现在几点了",
]


def run(model, turns):
    msgs = [{"role": "system", "content": system()}]
    out = []
    for i, t in enumerate(turns):
        msgs.append({"role": "user", "content": t})
        body = json.dumps({"model": model, "messages": msgs, "stream": True,
                           "temperature": 0.85, "max_tokens": 300}).encode()
        req = urllib.request.Request(URL, data=body, method="POST", headers={
            "x-wb-webapp-access-key": KEY, "Content-Type": "application/json",
            "Accept": "text/event-stream"})
        t0 = time.time(); ttft = None; txt = ""
        with urllib.request.urlopen(req, timeout=90) as r:
            for raw in r:
                s = raw.decode("utf-8", "ignore").strip()
                if not s.startswith("data:"):
                    continue
                p = s[5:].strip()
                if p == "[DONE]":
                    break
                try:
                    f = json.loads(p)
                except Exception:
                    continue
                for c in (f.get("choices") or []):
                    cc = (c.get("delta") or {}).get("content")
                    if cc:
                        if ttft is None:
                            ttft = time.time() - t0
                        txt += cc
        total = time.time() - t0
        msgs.append({"role": "assistant", "content": txt})
        out.append((t, txt, ttft, total))
    return out


for model in sys.argv[1:]:
    print("=" * 70)
    print("MODEL", model)
    try:
        for q, a, ttft, total in run(model, TURNS):
            tt = f"{ttft:.2f}" if ttft else "n/a"
            print(f"\n[{tt}s | {total:.2f}s] U: {q}")
            print("A:", a.strip().replace("\n", " ⏎ "))
    except Exception as e:
        print("FAIL", type(e).__name__, str(e)[:150])

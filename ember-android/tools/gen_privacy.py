# 앱의 Policy.kt 에서 개인정보처리방침 문서(md·html)를 만든다. 방침을 고치면 이 스크립트를 다시 돌린다.
import re, html, pathlib
src = pathlib.Path('app/src/main/java/app/ember/ideas/ui/strings/Policy.kt').read_text(encoding='utf8')
def sections(obj):
    body = src[src.index(f'object {obj}'):]
    body = body[:body.index('\n}\n')]
    out = []
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)" to\s*((?:"(?:[^"\\]|\\.)*"\s*\+?\s*)+),', body):
        text = ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(2)))
        out.append((m.group(1), text))
    return out
ko, en = sections('KoPolicy'), sections('EnPolicy')
md = ['# Ember 개인정보처리방침', '', '시행일 2026년 11월 5일', '']
for t, b in ko: md += [f'## {t}', '', b, '']
md += ['---', '', '# Ember Privacy Policy', '', 'Effective November 5, 2026', '']
for t, b in en: md += [f'## {t}', '', b, '']
pathlib.Path('docs/privacy-policy.md').write_text('\n'.join(md), encoding='utf8')
def block(lang, title, date, secs):
    h = [f'<section lang="{lang}"><h1>{html.escape(title)}</h1><p class="date">{date}</p>']
    for t, b in secs: h.append(f'<h2>{html.escape(t)}</h2><p>{html.escape(b)}</p>')
    return '\n'.join(h) + '</section>'
page = f'''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ember 개인정보처리방침 / Privacy Policy</title>
<style>
body{{margin:0;background:#0F0E13;color:#F4F1EC;font:16px/1.7 -apple-system,"Pretendard","Apple SD Gothic Neo","Noto Sans KR",sans-serif}}
main{{max-width:720px;margin:0 auto;padding:40px 20px 80px}}
h1{{font-size:28px;margin:0 0 4px}} h2{{font-size:18px;margin:28px 0 6px}}
p{{color:#B0AABB;margin:0}} .date{{color:#8E889A;font-size:14px}}
section+section{{margin-top:64px;padding-top:40px;border-top:1px solid #353141}}
@media (prefers-color-scheme: light){{body{{background:#FAF7F2;color:#1C1A22}}p{{color:#5F5969}}section+section{{border-color:#C9BEB0}}}}
</style></head><body><main>
{block("ko", "Ember 개인정보처리방침", "시행일 2026년 11월 5일", ko)}
{block("en", "Ember Privacy Policy", "Effective November 5, 2026", en)}
</main></body></html>
'''
pathlib.Path('docs/privacy.html').write_text(page, encoding='utf8')
print(len(ko), len(en))

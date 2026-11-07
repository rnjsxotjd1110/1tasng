# assets/legal 의 약관·방침 Markdown 으로 스토어 등록용 웹 페이지(docs/*.html)를 만든다.
# 사업자 정보는 gradle.properties 의 ember.biz.* 값을 쓴다. 약관이나 방침을 고치면 다시 돌린다.
#   python3 tools/gen_legal.py
import html, pathlib, re

root = pathlib.Path(__file__).resolve().parent.parent
props = {}
for line in (root / 'gradle.properties').read_text(encoding='utf8').splitlines():
    line = line.strip()
    if line and not line.startswith('#') and '=' in line:
        k, v = line.split('=', 1)
        props[k.strip()] = v.strip()

def values(ko):
    miss = '[미입력]' if ko else '[not set]'
    g = lambda k: props.get(k, '') or miss
    return {
        'BIZ_NAME': g('ember.biz.name'), 'BIZ_CEO': g('ember.biz.ceo'), 'BIZ_REG_NO': g('ember.biz.regNo'),
        'BIZ_SALES_NO': g('ember.biz.salesNo'), 'BIZ_ADDRESS': g('ember.biz.address'), 'BIZ_PHONE': g('ember.biz.phone'),
        'BIZ_EMAIL': props.get('ember.biz.email') or props.get('ember.reportEmail') or miss,
        'PRIVACY_OFFICER': g('ember.biz.privacyOfficer'), 'DB_REGION': g('ember.biz.dbRegion'),
        'DELETE_URL': g('ember.deleteUrl'), 'EFFECTIVE_DATE': g('ember.legalEffective'),
    }

def inline(t):
    t = html.escape(t)
    return re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)

def md_to_html(md):
    out, lines, i = [], md.splitlines(), 0
    while i < len(lines):
        l = lines[i]
        if l.startswith('# '): out.append(f'<h1>{inline(l[2:])}</h1>')
        elif l.startswith('## '): out.append(f'<h2>{inline(l[3:])}</h2>')
        elif l.strip() == '---': out.append('<hr>')
        elif l.startswith('|'):
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                rows.append([c.strip() for c in lines[i].strip('|').split('|')]); i += 1
            head, body = rows[0], [r for r in rows[2:]]
            out.append('<div class="t"><table><thead><tr>' + ''.join(f'<th>{inline(c)}</th>' for c in head) + '</tr></thead><tbody>' +
                       ''.join('<tr>' + ''.join(f'<td>{inline(c)}</td>' for c in r) + '</tr>' for r in body) + '</tbody></table></div>')
            continue
        elif l.startswith('- '):
            items = []
            while i < len(lines) and lines[i].startswith('- '):
                items.append(f'<li>{inline(lines[i][2:])}</li>'); i += 1
            out.append('<ul>' + ''.join(items) + '</ul>')
            continue
        elif l.strip(): out.append(f'<p>{inline(l)}</p>')
        i += 1
    return '\n'.join(out)

STYLE = '''body{margin:0;background:#141116;color:#F3EEE8;font:16px/1.7 -apple-system,"IBM Plex Sans KR","Apple SD Gothic Neo","Noto Sans KR",sans-serif}
main{max-width:760px;margin:0 auto;padding:40px 20px 80px}h1{font-size:28px;margin:0 0 4px}h2{font-size:18px;margin:28px 0 6px}
p,li{color:#B4AAB5}strong{color:#F3EEE8}a{color:#FF8A57}hr{border:0;border-top:1px solid #3A3340;margin:28px 0}
.t{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:14px;margin:8px 0}th,td{border:1px solid #3A3340;padding:8px;text-align:left;vertical-align:top}th{background:#1E1A21}
section+section{margin-top:64px;padding-top:40px;border-top:1px solid #3A3340}
@media (prefers-color-scheme: light){body{background:#FAF7F2;color:#1C1A22}p,li{color:#5F5969}strong{color:#1C1A22}th{background:#EFE8DF}th,td,hr{border-color:#C9BEB0}}'''

def page(title, sections):
    body = '\n'.join(f'<section lang="{lang}">{h}</section>' for lang, h in sections)
    return f'<!doctype html>\n<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title><style>{STYLE}</style></head><body><main>\n{body}\n</main></body></html>\n'

legal = root / 'app/src/main/assets/legal'
def doc(name, ko):
    md = (legal / f'{name}_{"ko" if ko else "en"}.md').read_text(encoding='utf8')
    for k, v in values(ko).items(): md = md.replace('{{' + k + '}}', v)
    return md

docs = root / 'docs'
for name, title in [('privacy', 'Ember 개인정보 처리방침 / Privacy Policy'), ('terms', 'Ember 이용약관 / Terms of Service')]:
    (docs / f'{name}.html').write_text(page(title, [('ko', md_to_html(doc(name, True))), ('en', md_to_html(doc(name, False)))]), encoding='utf8')
# 예전 스크립트가 만들던 Markdown 사본도 같은 내용으로 맞춘다.
(docs / 'privacy-policy.md').write_text(doc('privacy', True) + '\n\n---\n\n' + doc('privacy', False), encoding='utf8')

v = values(True)
delete_ko = f'''# Ember 계정 삭제

Ember 크레딧 계정과 서버의 기록을 지우는 방법이에요.

## 앱에서 지우기

1. Ember 앱의 **대장간** 탭 → **Claude 연결**을 열어요.
2. 크레딧 화면 아래의 **크레딧 계정 삭제**를 누르고 확인해요.

## 앱 없이 요청하기

앱을 지웠거나 쓸 수 없으면 {v["BIZ_EMAIL"]}로 "Ember 계정 삭제 요청"이라고 보내 주세요. 크레딧 계정을 만든 Google 계정의 이메일 주소로 보내 주시면 본인 확인 후 10일 안에 지우고 알려 드려요.

## 지워지는 것과 남는 것

- **바로 지워져요**: 크레딧 계정, 남은 크레딧, 사용 기록, 신고 내용, 기기 식별자
- **법에 따라 남아요**: 결제 기록(계정과 연결을 끊고 결제일로부터 5년, 전자상거래법)
- **부정 이용 방지를 위해 남아요**: Google 계정 식별자를 되돌릴 수 없게 바꾼 값(삭제 후 3년)
- 남은 유료 크레딧의 환불이 필요하면 삭제 전에 요청해 주세요.
- 휴대폰 안의 프로젝트는 앱의 **모든 데이터 지우기**나 앱 삭제로 지워요.
'''
delete_en = f'''# Delete your Ember account

How to delete your Ember credit account and its server records.

## In the app

1. Open the **Workshop** tab → **Claude access** in Ember.
2. Tap **Delete credit account** at the bottom of the credits screen and confirm.

## Without the app

If you've uninstalled the app, email {v["BIZ_EMAIL"]} with "Ember account deletion request" from the email of the Google account you used. We verify it and delete within 10 days.

## What is deleted and what is kept

- **Deleted right away**: credit account, remaining credits, usage history, reports, device identifier
- **Kept by law**: purchase records (unlinked from the account, 5 years from purchase, Korean e-commerce law)
- **Kept to prevent abuse**: an irreversible hash of your Google account ID (3 years after deletion)
- Request any refund of remaining paid credits before deleting.
- Projects on your phone are deleted with **Erase all data** in the app or by uninstalling.
'''
(docs / 'delete-account.html').write_text(page('Ember 계정 삭제 / Delete account', [('ko', md_to_html(delete_ko)), ('en', md_to_html(delete_en))]), encoding='utf8')
print('docs/privacy.html, docs/terms.html, docs/delete-account.html')

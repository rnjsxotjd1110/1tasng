# Ember Privacy Policy

Effective {{EFFECTIVE_DATE}}

{{BIZ_NAME}} ("we") operates the Ember app and processes personal information as described below, in line with Korea's Personal Information Protection Act.

## 1. What we process, why, and for how long

| Category | Items | Purpose | Retention |
|---|---|---|---|
| On your phone | Projects, design docs, notes, reference images, settings, developer profile | Running the app | On this phone only, until you delete them or the app |
| Credit account | Google account ID (numeric), a random per-install ID (pseudonymous), a hash of your account token | Creating, signing in to and recovering your credit account | Until you delete the account. Free-only accounts: 1 year after last use. Accounts with paid credits: 5 years from the last purchase |
| Credit usage | Model, token counts, credits charged, time | Charging and settling credits, disputes | 1 year |
| Purchases | Google Play order ID, product, quantity, credits granted, purchase and refund times | Granting credits, refunds and withdrawals | 5 years from purchase (Korean e-commerce law); unlinked from the account when it is deleted |
| Abuse prevention | IP address (first 64 bits for IPv6), device integrity verdict | Preventing excessive requests and free-credit abuse | IP: 2 days. The verdict is not stored |
| Free-credit duplicate check | An irreversible keyed hash (HMAC) of your Google account ID | Stopping people from deleting and recreating accounts to get free credits again | 3 years after account deletion |
| AI content reports | Reason, note, reported content | Reviewing reports, improving safety | 1 year |
| Support and crash reports | Your email address and message, crash report (app, device and Android version, error location) | Replies and bug fixes | 3 years |

We do not store request content (your answers, text, images or documents) on our servers. We do not use advertising IDs, cookies or analytics.

## 2. Processors and overseas transfer

| Recipient (contact) | Country | When and how | Items | Purpose | Retention |
|---|---|---|---|---|---|
| Anthropic, PBC (privacy@anthropic.com) | USA | Each AI request, over HTTPS | Answers, text, reference images, developer profile, ideas and docs, web search queries | Generating ideas and design docs | Under Anthropic's retention policy |
| Cloudflare, Inc. (privacyquestions@cloudflare.com) | USA and Cloudflare data-center countries (database: {{DB_REGION}}) | When you use Ember credits, over HTTPS | Credit, usage, purchase, abuse-prevention and report items in section 1; AI requests in credit mode (passed through, not stored) | Running the relay server and database | As in section 1 |
| Google LLC (see Google's privacy policy) | USA | At sign-in, registration and purchase, over HTTPS | Google ID token, device integrity token, purchase token | Sign-in, abuse prevention, purchase verification | Under Google's policy |

**How to refuse and what happens**: if you don't want your data transferred abroad, don't use AI generation (demo mode and on-device editing still work). Without Ember credits nothing goes to Cloudflare or Google. With your own API key, requests go straight from your phone to Anthropic.

With "Search real works" on, search queries may include keywords from your idea and are passed to Anthropic and the search service it uses.

## 3. Third parties

We do not provide your personal information to third parties, except when required by law.

## 4. Deletion

We delete information without delay when its retention period ends or its purpose is met, using methods that can't be undone. Records we must keep by law are kept separately and only for that period.

## 5. Your rights

You can ask to see, correct, delete or stop processing your information at any time.

- Delete your credit account: Workshop → Claude access → Delete credit account, or {{DELETE_URL}}
- Delete data on this phone: Workshop → Erase all data, or uninstall the app
- Anything else: email {{BIZ_EMAIL}}; we act within 10 days and tell you the result.

## 6. Security

HTTPS in transit, Android Keystore encryption for keys and tokens on the phone, hashed tokens on the server, key-restricted admin functions, least-privilege access.

## 7. App permissions

- Notifications (optional): tell you when work finishes. Everything else works without them.
- Photos: only photos you pick in the system photo picker (no permission needed).
- Voice: "Dictate" uses your phone's speech recognition service (e.g. Google). Audio is handled under that service's policy; we never receive it.

## 8. Children

Ember does not collect information from children under 14. If we learn that we have, we delete it immediately.

## 9. Privacy officer

- Privacy officer: {{PRIVACY_OFFICER}}
- Contact: {{BIZ_EMAIL}}, {{BIZ_PHONE}}

## 10. Changes

We announce changes in the app and on this page 7 days before they take effect, or 30 days before for important changes that are unfavorable to you.

---

{{BIZ_NAME}} · CEO {{BIZ_CEO}} · Business reg. no. {{BIZ_REG_NO}} · {{BIZ_ADDRESS}}

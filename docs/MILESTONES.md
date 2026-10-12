# SmartMoney Milestones

**Status as of:** 11 October 2026
**Branch:** `dev`, in sync with `origin/dev`, working tree clean. Pull request #30 (`dev` into `main`) is open and mergeable.
**Note:** `docs/ROADMAP.md` is out of date. It still says the current milestone is Authentication, which was finished long ago. This file replaces it as the source of truth for status.

## 1. Summary

| # | Milestone | Status |
|---|---|---|
| M1 | Core product: accounts, catalogue, tracking, cashback, wallet, admin | Done, working locally |
| M2 | Security hardening and consent | Done, committed 5 October |
| M3 | Privacy Policy and Terms of Service | Done in the repo, not yet published |
| M4 | Money-out (withdrawals) | **Blocked** by Cashfree's rejection |
| M5 | Infrastructure: Azure and live email | Not started |
| M6 | Launch readiness: stores, registrations, sign-offs | Not started |

## 2. Done

### M1 Core product
- [x] Clean-architecture backend with PostgreSQL, 20 entities and migrations
- [x] Registration, login, JWT with refresh tokens, email OTP verification, password reset
- [x] Profile and profile photo upload
- [x] Categories, stores, offers, banners and search
- [x] Affiliate click tracking and a Cuelinks-style conversion webhook
- [x] Cashback with a status flow, a wallet ledger, and rates set by network, store and category
- [x] Mobile app: home, browsing, cashback, wallet, profile
- [x] Admin app: users, stores, offers, categories, affiliate networks, cashback review and settings
- [x] Small fixes this session: profile chip removed, stray blank tab fixed, "Keep me signed in" fixed, admin list search

### M2 Security hardening and consent
- [x] Password and OTP policies, refresh-token reuse detection, rate limiting and CORS settings
- [x] Token refresh in the mobile and admin apps
- [x] SMTP email OTP sender (code is ready; it needs real credentials, see M5)
- [x] Signup consent: 18+ checkbox, terms checkbox, version, time and IP recorded
- [x] Self-service account deletion with anonymisation and a 90-day restricted archive
- [x] Google login removed
- [x] 223 backend tests passing on 5 October

### M3 Legal documents
- [x] Privacy Policy and Terms of Service as markdown, short HTML, detailed HTML and PDF
- [x] Copies bundled in the mobile app, with a consent version tag that matches the backend
- [x] Address details removed everywhere, including from git history
- [x] Merge conflict with `main` resolved
- [x] Lawyer and accountant questions drafted, then set aside by choice

## 3. Pending

### M4 Money-out (blocked)
- [ ] Choose a payout route after Cashfree's rejection: Razorpay X, another provider, or gift cards first
- [ ] Build the withdrawal flow: Rs 250 minimum, 50/50 fee split, UPI and bank capture, admin review queue
- [ ] Make the delete flow match the documents: it refuses any positive balance today, while the documents promise a one-time payout under Rs 250
- [ ] Update both legal documents once the provider is chosen, since they name Cashfree

### M5 Infrastructure
- [ ] Move backend, database and storage to Azure. The code still uses Supabase for photos and catalogue images, and the legal documents already say Azure
- [ ] Set real SMTP credentials so OTP emails reach users. This was the earlier blocker for testing with real users
- [ ] Deploy the API on the domain smart-money.in, then point the apps at it instead of localhost
- [ ] Verify the Cuelinks webhook against a live account. It has only been tested with the local simulator
- [ ] Check whether the commission figure includes GST, because cashback is calculated on it with no adjustment

### M6 Launch readiness
- [ ] Host the four legal HTML pages at public addresses, and open the in-app Terms and Privacy rows to them
- [ ] Get the app on the Play Store, with the Data Safety form and a deletion link matching the documents
- [ ] GST, Udyam and a current account in the trade name. Decide whether to incorporate before money moves
- [ ] Lawyer and accountant sign-off, set aside for now but still required before real money
- [ ] Reset the effective date to the real publication date and archive each version users accept
- [ ] Add device and fraud checks, or soften the fraud wording in the Terms

## 4. Decisions waiting on you

1. Which payout route to take after Cashfree.
2. Whether to merge pull request #30 into `main` now.
3. When to start the Azure move, and whether to keep Supabase until then.
4. Whether to launch with gift cards first while cash payouts are arranged.

## 5. Next five steps

1. Decide the payout route.
2. Publish the legal pages and get the app listed.
3. Set up SMTP and test OTP with real addresses.
4. Move to Azure and deploy the API.
5. Update the legal documents to match the final provider, hosting and dates.

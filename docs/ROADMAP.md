
---

# 5. `docs/ROADMAP.md`

```md
# SmartMoney Roadmap

## Current Status

| Item | Value |
|---|---|
| Active Branch | dev |
| Current Milestone | Authentication |
| Current Phase | PostgreSQL persistence setup |
| Next Task | Initial EF Core migration |
| Overall Status | In Development |

## Completed

- Repository setup
- Git collaboration workflow
- Clean Architecture solution
- Domain foundation
- User entity
- Role entity
- Wallet entity
- Cashback entity
- RefreshToken entity
- CQRS abstractions
- Registration contracts
- Registration command
- Registration handler skeleton
- EF Core DbContext
- PostgreSQL provider
- Entity configurations
- Repository interfaces
- Repository implementations
- Dependency injection

## Current Milestone: Authentication

Pending work:

- PostgreSQL connection verification
- Initial migration
- Database creation
- Default role seeding
- Transaction or unit-of-work abstraction
- Password hashing
- Registration handler logic
- Registration API
- Login
- JWT generation
- Refresh token rotation
- Logout
- OTP verification
- Profile endpoint

## MVP Milestones

| Milestone | Deliverables | Estimate |
|---|---|---:|
| 1 | Authentication, OTP, profile, dashboard | 2 weeks |
| 2 | Categories, stores, offers, search | 1.5 weeks |
| 3 | Click tracking and Admitad | 2 weeks |
| 4 | Cashback, wallet, ledger | 2 weeks |
| 5 | Withdrawals | 1.5 weeks |
| 6 | Admin portal | 2 weeks |
| 7 | Testing and deployment | 1 week |

## Approximate Total

12 weeks, assuming stable MVP scope and timely affiliate-provider access.

## Post-MVP Backlog

- Automated payouts
- Google login
- OTP-only login
- Push notifications
- Referral rewards
- Multiple affiliate providers
- iOS
- Multi-language
- Multi-currency
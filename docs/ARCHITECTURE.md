
---

# 3. `docs/ARCHITECTURE.md`

```md
# SmartMoney Architecture

## Technology Stack

| Area | Technology |
|---|---|
| Mobile | Flutter |
| Backend | ASP.NET Core .NET 10 |
| Database | PostgreSQL |
| ORM | Entity Framework Core |
| PostgreSQL Provider | Npgsql |
| State Management | Riverpod |
| Networking | Dio |
| Routing | go_router |
| Authentication | JWT and Refresh Token |
| Version Control | Git and GitHub |

## Backend Structure

```text
backend/
├── SmartMoney.slnx
├── src/
│   ├── SmartMoney.Api
│   ├── SmartMoney.Application
│   ├── SmartMoney.Domain
│   └── SmartMoney.Infrastructure
└── tests/
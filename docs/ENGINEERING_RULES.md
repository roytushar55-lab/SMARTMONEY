
---

# 4. `docs/ENGINEERING_RULES.md`

```md
# SmartMoney Engineering Rules

## Coding Rules

- Use file-scoped namespaces.
- One public type per file.
- File name must match type name.
- Interfaces begin with `I`.
- Async methods end with `Async`.
- Use `CancellationToken` in async operations.
- Use `decimal` for money.
- Use UTC for timestamps.
- Build before commit.

## Domain Rules

- Entities use private setters.
- State changes happen through methods.
- Domain methods validate their own rules.
- Domain does not reference EF Core or ASP.NET Core.
- Invalid financial states are not allowed.
- Balances must never become negative.

## Application Rules

- Commands change state.
- Queries read state.
- Handlers coordinate use cases.
- Application defines interfaces.
- Infrastructure implements interfaces.
- API contracts remain separate from commands.

## Infrastructure Rules

- EF Core configurations stay in Infrastructure.
- Controllers never use DbContext directly.
- Repositories do not contain business rules.
- Multi-record writes use one transaction.
- Database-provider code stays in Infrastructure.

## API Rules

- Controllers remain thin.
- Controllers map requests to commands.
- Controllers do not calculate cashback.
- API never returns password hashes or secrets.
- Errors use a consistent response format.

## Security Rules

- Never commit secrets.
- Never store plain passwords.
- JWT signing key comes from configuration.
- Refresh tokens must expire and be revocable.
- Admin endpoints require authorization.
- Login and OTP endpoints require rate limiting.
- Financial actions must be auditable.

## Git Workflow

### Branches

```text
upstream/main → stable shared branch
origin/dev    → active development branch
using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Application.Features.Withdrawals.ListAdminWithdrawals;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;
using SmartMoney.Infrastructure.Persistence.Context;

namespace SmartMoney.Infrastructure.Persistence.Repositories;

public sealed class WithdrawalRepository : IWithdrawalRepository
{
    private readonly SmartMoneyDbContext _context;

    public WithdrawalRepository(SmartMoneyDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(
        Withdrawal withdrawal,
        CancellationToken cancellationToken = default)
    {
        await _context.Withdrawals.AddAsync(withdrawal, cancellationToken);
    }

    public async Task<Withdrawal?> GetByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return await _context.Withdrawals
            .FirstOrDefaultAsync(
                withdrawal => withdrawal.Id == id,
                cancellationToken);
    }

    public async Task<Withdrawal?> GetByReferenceAsync(
        string reference,
        CancellationToken cancellationToken = default)
    {
        return await _context.Withdrawals
            .FirstOrDefaultAsync(
                withdrawal => withdrawal.Reference == reference,
                cancellationToken);
    }

    public async Task<Withdrawal?> GetByProviderReferenceAsync(
        string providerName,
        string providerReference,
        CancellationToken cancellationToken = default)
    {
        return await _context.Withdrawals
            .FirstOrDefaultAsync(
                withdrawal => withdrawal.ProviderName == providerName
                    && withdrawal.ProviderReference == providerReference,
                cancellationToken);
    }

    public async Task<Withdrawal?> GetWithUserByIdAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        return await _context.Withdrawals
            .AsNoTracking()
            .Include(withdrawal => withdrawal.User)
            .FirstOrDefaultAsync(
                withdrawal => withdrawal.Id == id,
                cancellationToken);
    }

    public async Task<int> CountOpenByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        return await _context.Withdrawals
            .CountAsync(
                withdrawal => withdrawal.UserId == userId
                    && (withdrawal.Status == WithdrawalStatus.Requested
                        || withdrawal.Status == WithdrawalStatus.Approved
                        || withdrawal.Status == WithdrawalStatus.Processing),
                cancellationToken);
    }

    public async Task<IReadOnlyList<Withdrawal>> ListByUserIdAsync(
        Guid userId,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        return await _context.Withdrawals
            .AsNoTracking()
            .Where(withdrawal => withdrawal.UserId == userId)
            .OrderByDescending(withdrawal => withdrawal.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> CountByUserIdAsync(
        Guid userId,
        CancellationToken cancellationToken = default)
    {
        return await _context.Withdrawals
            .CountAsync(
                withdrawal => withdrawal.UserId == userId,
                cancellationToken);
    }

    public async Task<IReadOnlyList<Withdrawal>> ListAsync(
        WithdrawalListFilter filter,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        return await Filtered(filter)
            .AsNoTracking()
            .Include(withdrawal => withdrawal.User)
            .OrderByDescending(withdrawal => withdrawal.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> CountAsync(
        WithdrawalListFilter filter,
        CancellationToken cancellationToken = default)
    {
        return await Filtered(filter).CountAsync(cancellationToken);
    }

    public async Task<int> CountMatchingAsync(
        Expression<Func<Withdrawal, bool>> predicate,
        CancellationToken cancellationToken = default)
    {
        return await _context.Withdrawals.CountAsync(predicate, cancellationToken);
    }

    public async Task<decimal> SumNetAmountAsync(
        Expression<Func<Withdrawal, bool>> predicate,
        CancellationToken cancellationToken = default)
    {
        // Nullable sum so an empty set gives zero instead of an error.
        return await _context.Withdrawals
            .Where(predicate)
            .SumAsync(withdrawal => (decimal?)withdrawal.NetAmount, cancellationToken) ?? 0m;
    }

    public async Task<IReadOnlyList<Guid>> ListIdsByStatusAsync(
        WithdrawalStatus status,
        DateTime? updatedBeforeUtc,
        int take,
        int? submissionAttemptsBelow = null,
        bool? needsAttention = null,
        CancellationToken cancellationToken = default)
    {
        IQueryable<Withdrawal> query = _context.Withdrawals
            .AsNoTracking()
            .Where(withdrawal => withdrawal.Status == status);

        if (submissionAttemptsBelow is int limit)
        {
            query = query.Where(withdrawal => withdrawal.SubmissionAttempts < limit);
        }

        if (needsAttention is bool flagged)
        {
            query = query.Where(withdrawal => withdrawal.NeedsAttention == flagged);
        }

        if (updatedBeforeUtc is DateTime cutoff)
        {
            // Rows never updated fall back to their creation time.
            query = query.Where(withdrawal =>
                (withdrawal.UpdatedAt ?? withdrawal.CreatedAt) < cutoff);
        }

        return await query
            .OrderBy(withdrawal => withdrawal.CreatedAt)
            .Take(take)
            .Select(withdrawal => withdrawal.Id)
            .ToListAsync(cancellationToken);
    }

    private IQueryable<Withdrawal> Filtered(WithdrawalListFilter filter)
    {
        IQueryable<Withdrawal> query = _context.Withdrawals;

        foreach (var predicate in filter.Predicates())
        {
            query = query.Where(predicate);
        }

        return query;
    }
}

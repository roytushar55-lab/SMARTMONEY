using SmartMoney.Application.Abstractions.CashbackRates;
using SmartMoney.Application.Abstractions.Persistence;
using SmartMoney.Domain.Entities;
using SmartMoney.Domain.Enums;

namespace SmartMoney.Application.Features.Affiliate.IngestAffiliateConversion;

/// <summary>
/// Translates a conversion's raw provider status into the user's cashback
/// lifecycle. This is the ONLY place network status strings are interpreted;
/// the domain stores them verbatim.
///
/// MVP safety rule: this is automated code, so it is NEVER allowed to
/// Confirm/Reject/Reverse a cashback on the network's word alone — only a
/// human (via the admin cashback endpoints) can do that. A decisive network
/// status only flags the cashback for admin review; the admin reads the
/// reason off AffiliateConversion.NetworkStatus via the FK.
///
/// The one wallet mutation automated code IS allowed: crediting the newly
/// created cashback amount to the wallet's PendingBalance (with a ledger
/// entry), so the user sees the reward as pending immediately. Moving money
/// out of pending remains admin-only.
///
/// The provider's "paid" status means the network was paid by the advertiser,
/// not that Smart Money paid the user — it never touches cashback status at
/// all, automated or otherwise.
/// </summary>
public sealed class ConversionCashbackProcessor
{
    private readonly ICashbackRepository _cashbackRepository;
    private readonly ICashbackRateResolver _rateResolver;
    private readonly IStoreRepository _storeRepository;
    private readonly IWalletRepository _walletRepository;
    private readonly IAffiliateClickRepository _clickRepository;
    private readonly IWalletTransactionRepository _walletTransactionRepository;

    public ConversionCashbackProcessor(
        ICashbackRepository cashbackRepository,
        ICashbackRateResolver rateResolver,
        IStoreRepository storeRepository,
        IWalletRepository walletRepository,
        IAffiliateClickRepository clickRepository,
        IWalletTransactionRepository walletTransactionRepository)
    {
        _cashbackRepository = cashbackRepository;
        _rateResolver = rateResolver;
        _storeRepository = storeRepository;
        _walletRepository = walletRepository;
        _clickRepository = clickRepository;
        _walletTransactionRepository = walletTransactionRepository;
    }

    /// <summary>
    /// Called after the conversion upsert, before SaveChanges, so cashback
    /// creation/transition (and the pending-balance credit that comes with
    /// creation) commits atomically with the conversion itself.
    /// </summary>
    public async Task ProcessAsync(
        AffiliateConversion conversion,
        CancellationToken cancellationToken)
    {
        // Unattributed conversions carry no user to reward. If attribution is
        // repaired later, the next status update re-enters this path.
        if (conversion.AffiliateClickId is not Guid clickId)
        {
            return;
        }

        var cashback = await _cashbackRepository.GetByConversionIdAsync(
            conversion.Id, cancellationToken);

        switch (Normalize(conversion.NetworkStatus))
        {
            case "pending":
                // No decision being reported yet — just make sure the reward
                // is visible to the user as Pending. No review needed.
                await EnsureCashbackExistsAsync(conversion, clickId, cashback, cancellationToken);
                break;

            case "validated":
            case "rejected":
            case "cancelled":
            case "reversed":
                // The network is reporting a decision, but automated code does
                // not get to act on it — only an admin can Confirm/Reject/
                // Reverse. Queue it for review from whichever state allows it;
                // any other current state (already under review, already
                // terminal) is left untouched.
                cashback ??= await EnsureCashbackExistsAsync(
                    conversion, clickId, cashback, cancellationToken);

                if (cashback is { Status: CashbackStatus.Pending or CashbackStatus.Confirmed })
                {
                    cashback.FlagForReview();
                }

                break;

            // "paid", "invoice_raised" and any unknown status: conversion row
            // is updated by the caller, cashback stays where it is. A "paid"
            // that arrives after a missed "validated" is reconciliation's job,
            // not grounds to skip admin review.
            default:
                break;
        }
    }

    private async Task<Cashback?> EnsureCashbackExistsAsync(
        AffiliateConversion conversion,
        Guid clickId,
        Cashback? existing,
        CancellationToken cancellationToken)
    {
        if (existing is not null)
        {
            return existing;
        }

        // The reward is a share of the commission; no commission, no cashback
        // yet. A later update carrying the amount re-enters here.
        if (conversion.CommissionAmount is not decimal commission || commission <= 0)
        {
            return null;
        }

        var click = await _clickRepository.GetByIdAsync(clickId, cancellationToken);

        if (click is null)
        {
            return null;
        }

        // A store can carry more than one category via StoreCategory, and the
        // conversion itself does not tell us which one was actually browsed.
        // We resolve against the store's "primary" category — the lowest
        // CategoryId among its mappings — rather than passing null, so a
        // category-specific override still applies to single-category
        // stores (the common case) without needing per-conversion category
        // tracking. A store with several categories and different override
        // rates per category will resolve to whichever one sorts first;
        // that's an accepted limitation until conversions carry their own
        // category.
        var categoryId = await _storeRepository.GetPrimaryCategoryIdAsync(click.StoreId, cancellationToken);

        var effectiveRate = await _rateResolver.ResolveEffectiveRateAsync(
            click.AffiliateNetworkId, click.StoreId, categoryId, cancellationToken);

        if (effectiveRate is not { UserSharePercent: > 0 } rate)
        {
            return null;
        }

        var amount = Math.Round(
            commission * rate.UserSharePercent / 100m,
            2,
            MidpointRounding.AwayFromZero);

        if (amount <= 0)
        {
            return null;
        }

        var wallet = await _walletRepository.GetByUserIdAsync(click.UserId, cancellationToken);

        if (wallet is null)
        {
            wallet = new Wallet(click.UserId);
            await _walletRepository.AddAsync(wallet, cancellationToken);
        }

        var cashback = new Cashback(
            click.UserId,
            wallet.Id,
            conversion.Id,
            amount,
            DateTime.UtcNow.AddDays(rate.ConfirmationWindowDays));

        await _cashbackRepository.AddAsync(cashback, cancellationToken);

        // Mutate the wallet first, then snapshot its balances on the ledger
        // row — every balance change writes exactly one ledger entry.
        wallet.AddPendingCashback(amount);

        await _walletTransactionRepository.AddAsync(
            new WalletTransaction(
                wallet.Id,
                click.UserId,
                WalletTransactionType.CashbackPending,
                amount,
                cashback.Id,
                "Cashback tracked (pending network confirmation).",
                wallet.AvailableBalance,
                wallet.PendingBalance),
            cancellationToken);

        return cashback;
    }

    private static string Normalize(string networkStatus)
    {
        return networkStatus.Trim().ToLowerInvariant();
    }
}

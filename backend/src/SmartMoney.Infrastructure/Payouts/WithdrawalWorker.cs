using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SmartMoney.Application.Abstractions.Payouts;
using SmartMoney.Application.Common;
using SmartMoney.Application.Features.Withdrawals;

namespace SmartMoney.Infrastructure.Payouts;

/// <summary>
/// Keeps automatic payouts moving: retries approved withdrawals that have not
/// been sent yet, and asks the provider about payouts whose result is overdue.
/// Does nothing with the manual provider (an admin pays those by hand).
/// </summary>
public sealed class WithdrawalWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IPayoutProvider _provider;
    private readonly PayoutPolicy _policy;
    private readonly ILogger<WithdrawalWorker> _logger;

    public WithdrawalWorker(
        IServiceScopeFactory scopeFactory,
        IPayoutProvider provider,
        PayoutPolicy policy,
        ILogger<WithdrawalWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _provider = provider;
        _policy = policy;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_provider.SupportsAutomaticPayout)
        {
            _logger.LogInformation(
                "Withdrawal worker idle: payout provider '{Provider}' is paid by hand.",
                _provider.Name);
            return;
        }

        _logger.LogInformation(
            "Withdrawal worker started for provider '{Provider}', every {Seconds}s.",
            _provider.Name, _policy.WorkerInterval.TotalSeconds);

        using var timer = new PeriodicTimer(_policy.WorkerInterval);

        try
        {
            do
            {
                try
                {
                    await RunOnceAsync(stoppingToken);
                }
                catch (Exception exception) when (exception is not OperationCanceledException)
                {
                    // A database blip must not stop the worker for good.
                    _logger.LogError(exception, "Withdrawal worker pass failed.");
                }
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }
        catch (OperationCanceledException)
        {
            // Shutting down.
        }
    }

    /// <summary>
    /// One pass. Every withdrawal gets its own scope (and so its own
    /// database context): if one fails to save, its half-applied changes
    /// are discarded with the scope instead of leaking into the next one.
    /// </summary>
    public async Task RunOnceAsync(CancellationToken cancellationToken)
    {
        WithdrawalWorkList work;

        using (IServiceScope scope = _scopeFactory.CreateScope())
        {
            work = await scope.ServiceProvider
                .GetRequiredService<IWithdrawalProcessor>()
                .ListPendingAsync(cancellationToken);
        }

        foreach (Guid id in work.ToSubmit)
        {
            await RunItemAsync(
                id, "submit", (p, ct) => p.SubmitAsync(id, ct), cancellationToken);
        }

        foreach (Guid id in work.ToReconcile)
        {
            await RunItemAsync(
                id, "reconcile", (p, ct) => p.ReconcileAsync(id, ct), cancellationToken);
        }
    }

    private async Task RunItemAsync(
        Guid withdrawalId,
        string action,
        Func<IWithdrawalProcessor, CancellationToken, Task> work,
        CancellationToken cancellationToken)
    {
        try
        {
            using IServiceScope scope = _scopeFactory.CreateScope();

            await work(
                scope.ServiceProvider.GetRequiredService<IWithdrawalProcessor>(),
                cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            // Includes losing a race with a webhook or an admin: their result
            // stands, and the next pass sees the new state.
            _logger.LogWarning(
                exception,
                "Withdrawal {WithdrawalId}: {Action} failed; will retry on a later pass.",
                withdrawalId, action);
        }
    }
}

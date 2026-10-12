using Microsoft.Extensions.DependencyInjection;
using SmartMoney.Application.Abstractions.CashbackRates;
using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Affiliate;
using SmartMoney.Application.Contracts.AffiliateNetworks;
using SmartMoney.Application.Contracts.Categories;
using SmartMoney.Application.Contracts.Cashbacks;
using SmartMoney.Application.Contracts.CashbackSettings;
using SmartMoney.Application.Contracts.Identity.AdminUsers;
using SmartMoney.Application.Contracts.Identity.ChangeUserRole;
using SmartMoney.Application.Contracts.Identity.DeleteAccount;
using SmartMoney.Application.Contracts.Identity.ForgotPassword;
using SmartMoney.Application.Contracts.Identity.Login;
using SmartMoney.Application.Contracts.Identity.RefreshToken;
using SmartMoney.Application.Contracts.Identity.Register;
using SmartMoney.Application.Contracts.Identity.ResendEmailOtp;
using SmartMoney.Application.Contracts.Identity.ResetPassword;
using SmartMoney.Application.Contracts.Identity.VerifyEmailOtp;
using SmartMoney.Application.Contracts.Offers;
using SmartMoney.Application.Contracts.Search;
using SmartMoney.Application.Contracts.StoreAffiliateMappings;
using SmartMoney.Application.Contracts.Stores;
using SmartMoney.Application.Contracts.Wallets;
using SmartMoney.Application.Features.Affiliate.CreateAffiliateClick;
using SmartMoney.Application.Features.Affiliate.IngestAffiliateConversion;
using SmartMoney.Application.Features.Affiliate.ResolveAffiliateRedirect;
using SmartMoney.Application.Features.AffiliateNetworks.CreateAffiliateNetwork;
using SmartMoney.Application.Features.AffiliateNetworks.ListAffiliateNetworksAdmin;
using SmartMoney.Application.Features.AffiliateNetworks.UpdateAffiliateNetwork;
using SmartMoney.Application.Features.Cashbacks;
using SmartMoney.Application.Features.Cashbacks.ApproveCashback;
using SmartMoney.Application.Features.Cashbacks.GetMyCashbacks;
using SmartMoney.Application.Features.Cashbacks.GetCashbackEvents;
using SmartMoney.Application.Features.Cashbacks.GetCashbackSummary;
using SmartMoney.Application.Features.Cashbacks.ListCashbacks;
using SmartMoney.Application.Features.Cashbacks.RejectCashback;
using SmartMoney.Application.Features.Cashbacks.ReverseCashback;
using SmartMoney.Application.Features.CashbackSettings.CreateCashbackOverride;
using SmartMoney.Application.Features.CashbackSettings.DeleteCashbackOverride;
using SmartMoney.Application.Features.CashbackSettings.GetCashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.GetNetworkCashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.ListNetworks;
using SmartMoney.Application.Features.CashbackSettings.UpdateCashbackOverride;
using SmartMoney.Application.Features.CashbackSettings.UpdateCashbackSettings;
using SmartMoney.Application.Features.CashbackSettings.UpdateNetworkCashbackSettings;
using SmartMoney.Application.Features.Categories.CreateCategory;
using SmartMoney.Application.Features.Categories.GetCategories;
using SmartMoney.Application.Features.Categories.ListCategoriesAdmin;
using SmartMoney.Application.Features.Categories.UpdateCategory;
using SmartMoney.Application.Features.Identity.ChangeUserRole;
using SmartMoney.Application.Features.Identity.DeleteAccount;
using SmartMoney.Application.Features.Identity.GetUserByEmail;
using SmartMoney.Application.Features.Identity.GetUserDetail;
using SmartMoney.Application.Features.Identity.GetUserStats;
using SmartMoney.Application.Features.Identity.ForgotPassword;
using SmartMoney.Application.Features.Identity.ListUsers;
using SmartMoney.Application.Features.Identity.Login;
using SmartMoney.Application.Features.Identity.RefreshToken;
using SmartMoney.Application.Features.Identity.Register;
using SmartMoney.Application.Features.Identity.ResendEmailOtp;
using SmartMoney.Application.Features.Identity.ResetPassword;
using SmartMoney.Application.Features.Identity.UpdateUserStatus;
using SmartMoney.Application.Features.Identity.VerifyEmailOtp;
using SmartMoney.Application.Features.Offers.CreateOffer;
using SmartMoney.Application.Features.Offers.GetOfferDetails;
using SmartMoney.Application.Features.Offers.GetOffers;
using SmartMoney.Application.Features.Offers.ListOffersAdmin;
using SmartMoney.Application.Features.Offers.UpdateOffer;
using SmartMoney.Application.Features.Search;
using SmartMoney.Application.Features.Stores.CreateStore;
using SmartMoney.Application.Features.Stores.GetStoreDetails;
using SmartMoney.Application.Features.Stores.GetStoreOffers;
using SmartMoney.Application.Features.Stores.GetStores;
using SmartMoney.Application.Features.Stores.GetStoresByCategory;
using SmartMoney.Application.Features.Stores.ListStoresAdmin;
using SmartMoney.Application.Features.Stores.UpdateStore;
using SmartMoney.Application.Features.StoreAffiliateMappings.CreateStoreAffiliateMapping;
using SmartMoney.Application.Features.StoreAffiliateMappings.ListStoreAffiliateMappingsAdmin;
using SmartMoney.Application.Features.StoreAffiliateMappings.UpdateStoreAffiliateMapping;
using SmartMoney.Application.Contracts.Withdrawals;
using SmartMoney.Application.Features.Withdrawals;
using SmartMoney.Application.Features.Withdrawals.AcknowledgeWithdrawal;
using SmartMoney.Application.Features.Withdrawals.ApproveWithdrawal;
using SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawal;
using SmartMoney.Application.Features.Withdrawals.GetAdminWithdrawalSummary;
using SmartMoney.Application.Features.Withdrawals.ListAdminWithdrawals;
using SmartMoney.Application.Features.Withdrawals.MarkWithdrawalFailed;
using SmartMoney.Application.Features.Withdrawals.MarkWithdrawalPaid;
using SmartMoney.Application.Features.Withdrawals.ProcessPayoutWebhook;
using SmartMoney.Application.Features.Withdrawals.RejectWithdrawal;
using SmartMoney.Application.Features.Withdrawals.CancelWithdrawal;
using SmartMoney.Application.Features.Withdrawals.GetMyWithdrawal;
using SmartMoney.Application.Features.Withdrawals.GetMyWithdrawals;
using SmartMoney.Application.Features.Withdrawals.PreviewWithdrawal;
using SmartMoney.Application.Features.Withdrawals.RequestWithdrawal;
using SmartMoney.Application.Features.Wallets.GetMyWallet;
using SmartMoney.Application.Features.Wallets.GetMyWalletTransactions;


namespace SmartMoney.Application.DependencyInjection;

public static class ApplicationDependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<RegisterUserValidator>();

        services.AddScoped<ICommandHandler<RegisterUserCommand, RegisterUserResponse>,RegisterUserCommandHandler>();

        services.AddScoped<LoginUserValidator>();

        services.AddScoped<ICommandHandler<LoginUserCommand, LoginUserResponse>,LoginUserCommandHandler>();

        services.AddScoped<VerifyEmailOtpValidator>();

        services.AddScoped<ICommandHandler<VerifyEmailOtpCommand, VerifyEmailOtpResponse>,VerifyEmailOtpCommandHandler>();

        services.AddScoped<ResendEmailOtpValidator>();

        services.AddScoped<ICommandHandler<ResendEmailOtpCommand, ResendEmailOtpResponse>,ResendEmailOtpCommandHandler>();

        services.AddScoped<RefreshTokenValidator>();

        services.AddScoped<ICommandHandler<RefreshTokenCommand, RefreshTokenResponse>,RefreshTokenCommandHandler>();

        services.AddScoped<ForgotPasswordValidator>();

        services.AddScoped<ICommandHandler<ForgotPasswordCommand, ForgotPasswordResponse>,ForgotPasswordCommandHandler>();

        services.AddScoped<ResetPasswordValidator>();

        services.AddScoped<ICommandHandler<ResetPasswordCommand, ResetPasswordResponse>,ResetPasswordCommandHandler>();

        services.AddScoped<IQueryHandler<GetCategoriesQuery,IReadOnlyList<CategoryListItemResponse>>,GetCategoriesQueryHandler>();

        services.AddScoped<IQueryHandler<GetStoresQuery,IReadOnlyList<StoreListItemResponse>>,GetStoresQueryHandler>();

        services.AddScoped<IQueryHandler<GetStoresByCategoryQuery,IReadOnlyList<StoreListItemResponse>>,GetStoresByCategoryQueryHandler>();

        services.AddScoped<IQueryHandler<GetStoreDetailsQuery,StoreDetailsResponse?>,GetStoreDetailsQueryHandler>();

        services.AddScoped<IQueryHandler<GetOffersQuery,IReadOnlyList<OfferListItemResponse>>,GetOffersQueryHandler>();

        services.AddScoped<IQueryHandler<GetOfferDetailsQuery,OfferDetailsResponse?>,GetOfferDetailsQueryHandler>();

        services.AddScoped<IQueryHandler<SearchQuery,SearchResultResponse>,SearchQueryHandler>();

        services.AddScoped<IQueryHandler<GetStoreOffersQuery,IReadOnlyList<OfferListItemResponse>>,GetStoreOffersQueryHandler>();

        services.AddScoped<ICommandHandler<CreateAffiliateClickCommand,CreateAffiliateClickResponse?>,CreateAffiliateClickCommandHandler>();

        services.AddScoped<ICommandHandler<ResolveAffiliateRedirectCommand,string?>,ResolveAffiliateRedirectCommandHandler>();

        services.AddScoped<IngestAffiliateConversionValidator>();

        services.AddScoped<ConversionCashbackProcessor>();

        services.AddScoped<ICommandHandler<IngestAffiliateConversionCommand,IngestAffiliateConversionResponse>,IngestAffiliateConversionCommandHandler>();

        services.AddScoped<IQueryHandler<ListCashbacksQuery,AdminCashbackListResponse>,ListCashbacksQueryHandler>();

        services.AddScoped<IQueryHandler<GetCashbackSummaryQuery,AdminCashbackSummaryResponse>,GetCashbackSummaryQueryHandler>();

        services.AddScoped<ICommandHandler<ApproveCashbackCommand,CashbackDecisionResponse?>,ApproveCashbackCommandHandler>();

        services.AddScoped<ICommandHandler<RejectCashbackCommand,CashbackDecisionResponse?>,RejectCashbackCommandHandler>();

        services.AddScoped<ICommandHandler<ReverseCashbackCommand,CashbackDecisionResponse?>,ReverseCashbackCommandHandler>();
        services.AddScoped<IQueryHandler<GetCashbackEventsQuery,IReadOnlyList<CashbackEventResponse>?>,GetCashbackEventsQueryHandler>();

        services.AddScoped<ChangeUserRoleValidator>();

        services.AddScoped<ICommandHandler<ChangeUserRoleCommand,ChangeUserRoleResponse?>,ChangeUserRoleCommandHandler>();

        services.AddScoped<ICommandHandler<DeleteAccountCommand,DeleteAccountResult>,DeleteAccountCommandHandler>();

        services.AddScoped<IQueryHandler<GetUserByEmailQuery,AdminUserLookupResponse?>,GetUserByEmailQueryHandler>();

        services.AddScoped<IQueryHandler<ListUsersQuery,AdminUserListResponse>,ListUsersQueryHandler>();

        services.AddScoped<IQueryHandler<GetUserDetailQuery,AdminUserDetailResponse?>,GetUserDetailQueryHandler>();

        services.AddScoped<ICommandHandler<UpdateUserStatusCommand,AdminUserStatusResponse?>,UpdateUserStatusCommandHandler>();

        services.AddScoped<IQueryHandler<GetUserStatsQuery,AdminUserStatsResponse>,GetUserStatsQueryHandler>();

        services.AddScoped<IQueryHandler<GetMyWalletQuery,MyWalletResponse>,GetMyWalletQueryHandler>();

        // Withdrawals
        services.AddScoped<WithdrawalSettlement>();
        services.AddScoped<ICommandHandler<RequestWithdrawalCommand, WithdrawalResponse>, RequestWithdrawalCommandHandler>();
        services.AddScoped<ICommandHandler<CancelWithdrawalCommand, WithdrawalDecisionResponse>, CancelWithdrawalCommandHandler>();
        services.AddScoped<IQueryHandler<GetMyWithdrawalsQuery, WithdrawalListResponse>, GetMyWithdrawalsQueryHandler>();
        services.AddScoped<IQueryHandler<GetMyWithdrawalQuery, WithdrawalResponse?>, GetMyWithdrawalQueryHandler>();
        services.AddScoped<IQueryHandler<PreviewWithdrawalQuery, WithdrawalPreviewResponse>, PreviewWithdrawalQueryHandler>();

        // Withdrawals: admin side
        services.AddScoped<IWithdrawalProcessor, WithdrawalProcessor>();
        services.AddScoped<IQueryHandler<ListAdminWithdrawalsQuery, AdminWithdrawalListResponse>, ListAdminWithdrawalsQueryHandler>();
        services.AddScoped<IQueryHandler<GetAdminWithdrawalQuery, AdminWithdrawalResponse?>, GetAdminWithdrawalQueryHandler>();
        services.AddScoped<IQueryHandler<GetAdminWithdrawalSummaryQuery, AdminWithdrawalSummaryResponse>, GetAdminWithdrawalSummaryQueryHandler>();
        services.AddScoped<ICommandHandler<ApproveWithdrawalCommand, WithdrawalDecisionResponse?>, ApproveWithdrawalCommandHandler>();
        services.AddScoped<ICommandHandler<RejectWithdrawalCommand, WithdrawalDecisionResponse?>, RejectWithdrawalCommandHandler>();
        services.AddScoped<ICommandHandler<MarkWithdrawalPaidCommand, WithdrawalDecisionResponse?>, MarkWithdrawalPaidCommandHandler>();
        services.AddScoped<ICommandHandler<MarkWithdrawalFailedCommand, WithdrawalDecisionResponse?>, MarkWithdrawalFailedCommandHandler>();
        services.AddScoped<ICommandHandler<AcknowledgeWithdrawalCommand, WithdrawalDecisionResponse?>, AcknowledgeWithdrawalCommandHandler>();
        services.AddScoped<ICommandHandler<ProcessPayoutWebhookCommand, PayoutWebhookResult>, ProcessPayoutWebhookCommandHandler>();

        services.AddScoped<IQueryHandler<GetMyWalletTransactionsQuery,WalletTransactionListResponse>,GetMyWalletTransactionsQueryHandler>();

        services.AddScoped<IQueryHandler<GetMyCashbacksQuery,MyCashbackListResponse>,GetMyCashbacksQueryHandler>();

        services.AddScoped<CreateCategoryValidator>();

        services.AddScoped<ICommandHandler<CreateCategoryCommand,CategoryAdminResponse>,CreateCategoryCommandHandler>();

        services.AddScoped<UpdateCategoryValidator>();

        services.AddScoped<ICommandHandler<UpdateCategoryCommand,CategoryAdminResponse?>,UpdateCategoryCommandHandler>();

        services.AddScoped<IQueryHandler<ListCategoriesAdminQuery,IReadOnlyList<CategoryAdminResponse>>,ListCategoriesAdminQueryHandler>();

        services.AddScoped<CreateStoreValidator>();

        services.AddScoped<ICommandHandler<CreateStoreCommand,StoreAdminResponse>,CreateStoreCommandHandler>();

        services.AddScoped<UpdateStoreValidator>();

        services.AddScoped<ICommandHandler<UpdateStoreCommand,StoreAdminResponse?>,UpdateStoreCommandHandler>();

        services.AddScoped<IQueryHandler<ListStoresAdminQuery,IReadOnlyList<StoreAdminResponse>>,ListStoresAdminQueryHandler>();

        services.AddScoped<CreateOfferValidator>();

        services.AddScoped<ICommandHandler<CreateOfferCommand,OfferAdminResponse?>,CreateOfferCommandHandler>();

        services.AddScoped<UpdateOfferValidator>();

        services.AddScoped<ICommandHandler<UpdateOfferCommand,OfferAdminResponse?>,UpdateOfferCommandHandler>();

        services.AddScoped<IQueryHandler<ListOffersAdminQuery,IReadOnlyList<OfferAdminResponse>>,ListOffersAdminQueryHandler>();

        services.AddScoped<IQueryHandler<GetCashbackSettingsQuery,CashbackSettingsResponse?>,GetCashbackSettingsQueryHandler>();

        services.AddScoped<UpdateCashbackSettingsValidator>();

        services.AddScoped<ICommandHandler<UpdateCashbackSettingsCommand,CashbackSettingsResponse?>,UpdateCashbackSettingsCommandHandler>();

        services.AddScoped<CreateAffiliateNetworkValidator>();

        services.AddScoped<ICommandHandler<CreateAffiliateNetworkCommand,AffiliateNetworkAdminResponse>,CreateAffiliateNetworkCommandHandler>();

        services.AddScoped<UpdateAffiliateNetworkValidator>();

        services.AddScoped<ICommandHandler<UpdateAffiliateNetworkCommand,AffiliateNetworkAdminResponse?>,UpdateAffiliateNetworkCommandHandler>();

        services.AddScoped<IQueryHandler<ListAffiliateNetworksAdminQuery,IReadOnlyList<AffiliateNetworkAdminResponse>>,ListAffiliateNetworksAdminQueryHandler>();

        services.AddScoped<CreateStoreAffiliateMappingValidator>();

        services.AddScoped<ICommandHandler<CreateStoreAffiliateMappingCommand,StoreAffiliateMappingAdminResponse?>,CreateStoreAffiliateMappingCommandHandler>();

        services.AddScoped<UpdateStoreAffiliateMappingValidator>();

        services.AddScoped<ICommandHandler<UpdateStoreAffiliateMappingCommand,StoreAffiliateMappingAdminResponse?>,UpdateStoreAffiliateMappingCommandHandler>();

        services.AddScoped<IQueryHandler<ListStoreAffiliateMappingsAdminQuery,IReadOnlyList<StoreAffiliateMappingAdminResponse>>,ListStoreAffiliateMappingsAdminQueryHandler>();

        services.AddScoped<ICashbackRateResolver, CashbackRateResolver>();

        services.AddScoped<IQueryHandler<ListNetworksQuery,IReadOnlyList<AffiliateNetworkAdminResponse>>,ListNetworksQueryHandler>();

        services.AddScoped<IQueryHandler<GetNetworkCashbackSettingsQuery,NetworkCashbackSettingsDetailResponse?>,GetNetworkCashbackSettingsQueryHandler>();

        services.AddScoped<UpdateNetworkCashbackSettingsValidator>();

        services.AddScoped<ICommandHandler<UpdateNetworkCashbackSettingsCommand,NetworkCashbackSettingsResponse?>,UpdateNetworkCashbackSettingsCommandHandler>();

        services.AddScoped<CreateCashbackOverrideValidator>();

        services.AddScoped<ICommandHandler<CreateCashbackOverrideCommand,CashbackRateOverrideResponse>,CreateCashbackOverrideCommandHandler>();

        services.AddScoped<UpdateCashbackOverrideValidator>();

        services.AddScoped<ICommandHandler<UpdateCashbackOverrideCommand,CashbackRateOverrideResponse?>,UpdateCashbackOverrideCommandHandler>();

        services.AddScoped<ICommandHandler<DeleteCashbackOverrideCommand,bool>,DeleteCashbackOverrideCommandHandler>();

        return services;
    }
}

using SmartMoney.Application.Abstractions.Messaging;
using SmartMoney.Application.Contracts.Stores;

namespace SmartMoney.Application.Features.Stores.ListStoresAdmin;

public sealed class ListStoresAdminQuery : IQuery<IReadOnlyList<StoreAdminResponse>>
{
}

namespace SmartMoney.Application.Abstractions.Authentication;

public interface IOtpGenerator
{
    string Generate(int length = 6);
}
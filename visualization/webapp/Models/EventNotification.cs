namespace WebApp.Models;

public record EventNotification(string Id, string Transaction, string Account, decimal Amount, DateTimeOffset ReceivedUtc);

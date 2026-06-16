using Azure.Identity;
using Azure.Messaging.ServiceBus;
using ContosoUniversity.Models;
using Microsoft.Extensions.Configuration;
using System.Text.Json;

namespace ContosoUniversity.Services
{
    public class NotificationService : IDisposable
    {
        private readonly ServiceBusClient _serviceBusClient;
        private readonly ServiceBusSender _sender;
        private readonly ServiceBusReceiver _receiver;
        private bool _disposed;

        public NotificationService(IConfiguration configuration)
        {
            var fullyQualifiedNamespace = configuration["ServiceBus:FullyQualifiedNamespace"]
                ?? throw new InvalidOperationException("ServiceBus:FullyQualifiedNamespace is not configured.");

            var queueName = configuration["ServiceBus:QueueName"]
                ?? throw new InvalidOperationException("ServiceBus:QueueName is not configured.");

            var credential = new DefaultAzureCredential();
            _serviceBusClient = new ServiceBusClient(fullyQualifiedNamespace, credential);
            _sender = _serviceBusClient.CreateSender(queueName);
            _receiver = _serviceBusClient.CreateReceiver(queueName);
        }

        public void SendNotification(string entityType, string entityId, EntityOperation operation, string? userName = null)
        {
            SendNotification(entityType, entityId, null, operation, userName);
        }

        public void SendNotification(string entityType, string entityId, string? entityDisplayName, EntityOperation operation, string? userName = null)
        {
            try
            {
                var notification = new Notification
                {
                    EntityType = entityType,
                    EntityId = entityId,
                    Operation = operation.ToString(),
                    Message = GenerateMessage(entityType, entityId, entityDisplayName, operation),
                    CreatedAt = DateTime.UtcNow,
                    CreatedBy = userName ?? "System",
                    IsRead = false
                };

                var messageBody = JsonSerializer.Serialize(notification);
                var message = new ServiceBusMessage(messageBody)
                {
                    ContentType = "application/json",
                    Subject = $"{entityType}.{operation}"
                };

                _sender.SendMessageAsync(message).GetAwaiter().GetResult();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to send notification: {ex.Message}");
            }
        }

        public Notification? ReceiveNotification()
        {
            try
            {
                var message = _receiver.ReceiveMessageAsync(maxWaitTime: TimeSpan.FromMilliseconds(500))
                    .GetAwaiter().GetResult();

                if (message == null)
                    return null;

                var notification = JsonSerializer.Deserialize<Notification>(message.Body.ToString());
                _receiver.CompleteMessageAsync(message).GetAwaiter().GetResult();
                return notification;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to receive notification: {ex.Message}");
                return null;
            }
        }

        public void MarkAsRead(int notificationId)
        {
            // Message completion (settlement) is handled during ReceiveNotification via CompleteMessageAsync.
            // Tracking read status per notification ID would require a separate data store.
        }

        private static string GenerateMessage(string entityType, string entityId, string? entityDisplayName, EntityOperation operation)
        {
            var displayText = !string.IsNullOrWhiteSpace(entityDisplayName)
                ? $"{entityType} '{entityDisplayName}'"
                : $"{entityType} (ID: {entityId})";

            return operation switch
            {
                EntityOperation.CREATE => $"New {displayText} has been created",
                EntityOperation.UPDATE => $"{displayText} has been updated",
                EntityOperation.DELETE => $"{displayText} has been deleted",
                _ => $"{displayText} operation: {operation}"
            };
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                _sender.DisposeAsync().AsTask().GetAwaiter().GetResult();
                _receiver.DisposeAsync().AsTask().GetAwaiter().GetResult();
                _serviceBusClient.DisposeAsync().AsTask().GetAwaiter().GetResult();
                _disposed = true;
            }
            GC.SuppressFinalize(this);
        }
    }
}

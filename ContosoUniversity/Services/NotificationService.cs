using System.Collections.Concurrent;
using ContosoUniversity.Models;
using Microsoft.Extensions.Configuration;

namespace ContosoUniversity.Services
{
    public class NotificationService : IDisposable
    {
        private readonly string _queuePath;
        private readonly ConcurrentQueue<Notification> _queue = new();

        public NotificationService(IConfiguration configuration)
        {
            _queuePath = configuration["AppSettings:NotificationQueuePath"]
                ?? @".\Private$\ContosoUniversityNotifications";
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
                    CreatedAt = DateTime.Now,
                    CreatedBy = userName ?? "System",
                    IsRead = false
                };

                _queue.Enqueue(notification);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to send notification: {ex.Message}");
            }
        }

        public Notification? ReceiveNotification()
        {
            _queue.TryDequeue(out var notification);
            return notification;
        }

        public void MarkAsRead(int notificationId)
        {
            // In a real implementation, notifications would be stored in a database
            // for persistence and tracking read status
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
            // Nothing to dispose for in-memory queue
            GC.SuppressFinalize(this);
        }
    }
}

# Setup and Testing Guide for Notification System

## Prerequisites

1. **Azure Service Bus Namespace**:
   - Create an Azure Service Bus namespace (Standard or Premium tier) in the Azure portal
   - Create a queue named `contoso-university-notifications`
   - Assign the `Azure Service Bus Data Owner` role to your identity (user or managed identity) on the namespace

2. **Configure the Application**:
   - Update `appsettings.json` with your Service Bus namespace FQDN and queue name:
     ```json
     "ServiceBus": {
       "FullyQualifiedNamespace": "<your-namespace>.servicebus.windows.net",
       "QueueName": "contoso-university-notifications"
     }
     ```
   - When running locally, authenticate via Azure CLI (`az login`) or set up environment credentials for `DefaultAzureCredential`

## Building the Project

1. Open the solution in Visual Studio
2. Restore NuGet packages if prompted
3. Build the solution (Ctrl+Shift+B)

## Testing the Notification System

### Step 1: Run the Application
1. Press F5 to start debugging
2. The application will launch in your default browser

### Step 2: Sign In with Microsoft Entra ID
1. The application uses Azure App Service built-in authentication (Easy Auth) with Microsoft Entra ID
2. Click "Sign in" in the top navigation and authenticate with your Microsoft Entra ID account
3. You should see your account name in the navigation bar after signing in

### Step 3: Access Notification Dashboard
1. Click "Notifications" in the main navigation menu
2. This page explains the notification system and provides test links

### Step 4: Test Notifications
1. **Create a Student**:
   - Click "Students" → "Create New"
   - Fill in the form and submit
   - Watch for a green notification in the top-right corner

2. **Edit a Student**:
   - Go to Students list, click "Edit" on any student
   - Make changes and save
   - Watch for a blue notification

3. **Delete a Student**:
   - Go to Students list, click "Delete" on any student
   - Confirm deletion
   - Watch for an orange notification

4. **Test Other Entities**:
   - Repeat the same process for Courses, Instructors, and Departments
   - Each operation should trigger appropriate notifications

### Step 5: Verify Azure Service Bus Queue
1. Open the Azure portal and navigate to your Service Bus namespace
2. Click on the `contoso-university-notifications` queue
3. Review the **Active Message Count** to verify messages are being sent and consumed

## Troubleshooting

### No Notifications Appearing
1. **Check Browser Console**: Press F12 and look for JavaScript errors
2. **Check Network Tab**: Verify calls to `/Notifications/GetNotifications` are happening
3. **Check Azure Service Bus**: Verify the queue exists and the application identity has the `Azure Service Bus Data Owner` role

### Azure Service Bus Errors
1. **Authentication Failure**:
   - Ensure your identity (local: logged-in Azure CLI user; deployed: managed identity) has the `Azure Service Bus Data Owner` role on the namespace
   - Run `az login` locally to refresh credentials

2. **Queue Not Found**:
   - Verify the queue name in `appsettings.json` matches the queue created in Azure portal
   - Check the `FullyQualifiedNamespace` value ends with `.servicebus.windows.net`

3. **Connection Issues**:
   - Verify network connectivity to the Azure Service Bus namespace
   - Check that firewall rules allow outbound traffic on port 443 (AMQP over WebSockets) or 5671 (AMQP)

### JavaScript Not Loading
1. **Admin Role Check**: Ensure you're logged in as administrator
2. **File Paths**: Verify `notifications.js` and `notifications.css` files exist
3. **Browser Cache**: Clear cache and refresh

## Configuration Notes

- **Namespace**: Configured in `appsettings.json` as `ServiceBus:FullyQualifiedNamespace`
- **Queue Name**: Configured in `appsettings.json` as `ServiceBus:QueueName`
- **Authentication**: Uses `DefaultAzureCredential` (Managed Identity in production, Azure CLI locally)
- **Polling Interval**: JavaScript checks for new notifications every 5 seconds
- **Auto-dismiss**: Notifications automatically disappear after 1 minute (60 seconds)
- **Max Notifications**: Maximum of 5 notifications shown simultaneously

## Production Considerations

For production deployment:

1. **Azure Service Bus**: Provision a Standard or Premium tier namespace with the notification queue
2. **Managed Identity**: Assign the `Azure Service Bus Data Owner` role to the app's managed identity
3. **Monitoring**: Monitor queue length and dead-letter queue in Azure Monitor
4. **Geo-Redundancy**: Use Premium tier with geo-disaster recovery for high availability
5. **Load Balancing**: Azure Service Bus natively supports multiple consumers across scaled-out instances

## Development Tips

- Notifications are designed to be non-blocking - Azure Service Bus failures won't break main operations
- Debug output shows notification send/receive operations
- Use notification dashboard to understand system behavior
- Test with multiple admin users to verify isolation

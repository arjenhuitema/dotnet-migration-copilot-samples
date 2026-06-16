# Modernization Plan: ContosoUniversity Azure Migration

**Project**: ContosoUniversity

---

## Technical Framework

- **Language**: C# (.NET Framework 4.8)
- **Framework**: ASP.NET MVC 5 with Razor Views
- **Build Tool**: MSBuild / NuGet (packages.config)
- **Database**: SQL Server (LocalDB)
- **Key Dependencies**: Entity Framework Core, MSMQ, Local File System for uploads

---

## Overview

> This migration modernizes the ContosoUniversity application to leverage Azure cloud services.
> The application currently uses local SQL Server, local file storage for teaching materials,
> MSMQ for notification queuing, and plaintext connection strings in Web.config.
> The new architecture will:
>
> - Replace local SQL Server with Azure SQL Database using Managed Identity authentication
> - Migrate local file storage to Azure Blob Storage for scalable, durable content hosting
> - Move from MSMQ to Azure Service Bus for reliable cloud-native messaging
> - Secure all credentials using Azure Key Vault with Managed Identity
> - Modernize file system I/O operations for cloud compatibility
>
> The migration follows a task-by-task approach, each independently testable and deployable.

---

## Migration Impact Summary

| Application        | Original Service         | New Azure Service       | Authentication   | Comments                                    |
|--------------------|--------------------------|-------------------------|------------------|---------------------------------------------|
| ContosoUniversity  | SQL Server (LocalDB)     | Azure SQL Database      | Managed Identity | Migrate connection and EF configuration     |
| ContosoUniversity  | Local File System        | Azure Blob Storage      | Managed Identity | Teaching material uploads                   |
| ContosoUniversity  | MSMQ                     | Azure Service Bus       | Managed Identity | Notification queue processing               |
| ContosoUniversity  | Plaintext credentials    | Azure Key Vault         | Managed Identity | Secure connection strings and secrets       |
| ContosoUniversity  | Local/network file I/O   | Cloud-compatible I/O    | N/A              | Modernize file system management operations |

---

## Tasks

| #   | Task ID                                              | Type      | Description                                                                                       |
|-----|------------------------------------------------------|-----------|---------------------------------------------------------------------------------------------------|
| 1   | 001-transform-local-sql-to-azure-sql                 | transform | Migrate from SQL Server to Managed Identity Based Azure SQL                                       |
| 2   | 002-transform-local-file-to-azure-blob               | transform | Migrate from local file system to Azure Blob Storage                                              |
| 3   | 003-transform-msmq-to-azure-servicebus               | transform | Migrate from MSMQ to Azure Service Bus                                                            |
| 4   | 004-transform-plaintext-cred-to-azure-keyvault       | transform | Migrate from Plaintext Credentials to Secured Credentials with Managed Identity and Azure KeyVault|
| 5   | 005-transform-file-system-management                 | transform | File System Management Migration                                                                  |

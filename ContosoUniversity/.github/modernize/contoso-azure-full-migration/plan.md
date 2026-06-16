# Modernization Plan: ContosoUniversity Azure Migration

**Project:** ContosoUniversity  
**Source Framework:** .NET Framework 4.8 (ASP.NET MVC 5)  
**Target:** Azure App Service with .NET 8.0  
**Assessment Report:** `report-20260616184259`  
**Created:** 2026-06-16  
**Total Tasks:** 7  
**Total Assessment Issues:** 6 categories, 25 incidents  

---

## Summary

This plan covers a full migration of the ContosoUniversity application from .NET Framework 4.8 to .NET 8.0 on Azure App Service. It addresses all 6 categories identified in the assessment plus a .NET version upgrade.

| # | Task | Type | Category | Severity | kbId |
|---|------|------|----------|----------|------|
| 1 | Upgrade .NET Framework 4.8 to .NET 8.0 | upgrade | Framework | — | — |
| 2 | Migrate MSMQ to Azure Service Bus | transform | Queue | mandatory | `msmq-to-azure-servicebus` |
| 3 | Migrate Windows Auth to Easy Auth | transform | Identity | mandatory | — |
| 4 | Migrate local file I/O to Azure Blob Storage | transform | Local | potential | `local-file-to-azure-blob-storage` |
| 5 | Migrate credentials to Azure KeyVault | transform | Security | optional | `plaintext-credential-to-azure-keyvault` |
| 6 | Migrate SQL Server to Azure SQL | transform | Database | potential | `local-sql-server-to-azure-sql-db` |
| 7 | Migrate static content to Azure Blob Storage | transform | Scale | optional | `local-file-to-azure-blob-storage` |

---

## Task Details

### Task 001: Upgrade .NET Framework 4.8 to .NET 8.0

- **Type:** upgrade
- **Priority:** High (prerequisite for other tasks)
- **Description:** Upgrade the application from .NET Framework 4.8 to .NET 8.0 LTS
- **Scope:**
  - Migrate from ASP.NET MVC 5 to ASP.NET Core MVC
  - Convert legacy `.csproj` to SDK-style project format
  - Replace `packages.config` with `PackageReference`
  - Migrate `Global.asax` startup to `Program.cs` / `Startup.cs`
  - Migrate `Web.config` settings to `appsettings.json`
  - Update all NuGet dependencies to .NET 8.0 compatible versions
- **Success Criteria:** Build passes, unit tests pass

---

### Task 002: Migrate from MSMQ to Azure Service Bus

- **Type:** transform
- **Category:** Queue (12 incidents, mandatory severity)
- **kbId:** `msmq-to-azure-servicebus`
- **Description:** Replace MSMQ (`System.Messaging`) with Azure Service Bus SDK
- **Affected Files:**
  - `Services/NotificationService.cs` — 12 incidents (MessageQueue, XmlMessageFormatter, MessageQueueAccessRights)
- **Scope:**
  - Replace `System.Messaging.MessageQueue` with `Azure.Messaging.ServiceBus.ServiceBusClient`
  - Migrate message sending from MSMQ to Service Bus queue/topic
  - Replace `XmlMessageFormatter` with Service Bus message serialization
  - Configure managed identity authentication
- **Success Criteria:** Build passes, unit tests pass

---

### Task 003: Migrate from Windows Authentication to Easy Auth

- **Type:** transform
- **Category:** Identity (1 incident, mandatory severity)
- **Description:** Migrate from Windows Authentication to Azure App Service built-in auth (Easy Auth)
- **Affected Files:**
  - `Web.config` — Windows Authentication configuration
- **Scope:**
  - Remove Windows Authentication configuration
  - Configure Azure App Service Easy Auth with Microsoft Entra ID
  - Update authorization middleware
  - Remove Windows-specific authentication settings
- **Success Criteria:** Build passes, unit tests pass

---

### Task 004: Migrate from Local File System to Azure Blob Storage

- **Type:** transform
- **Category:** Local (8 incidents, potential severity)
- **kbId:** `local-file-to-azure-blob-storage`
- **Description:** Replace local file system operations with Azure Blob Storage
- **Affected Files:**
  - `Controllers/CoursesController.cs` — 8 incidents at lines 76, 78, 159, 161, 172, 174, 229, 233
    - `System.IO.Directory` operations (4 incidents)
    - `System.IO.File` operations (4 incidents)
- **Scope:**
  - Replace `System.IO.File` / `System.IO.Directory` with `Azure.Storage.Blobs.BlobClient`
  - Create blob container for teaching materials uploads
  - Migrate file upload, read, and delete operations
  - Configure managed identity authentication
- **Success Criteria:** Build passes, unit tests pass

---

### Task 005: Migrate Plaintext Credentials to Azure KeyVault

- **Type:** transform
- **Category:** Security (2 incidents, optional severity)
- **kbId:** `plaintext-credential-to-azure-keyvault`
- **Description:** Secure credentials with Managed Identity and Azure KeyVault
- **Affected Files:**
  - `Web.config` — `<appSettings>` section (1 incident)
  - `Web.config` — `<connectionStrings>` section (1 incident)
- **Scope:**
  - Move secrets from configuration files to Azure KeyVault
  - Configure Managed Identity for KeyVault access
  - Replace hardcoded credentials with KeyVault references
  - Update application configuration to use Azure Key Vault provider
- **Success Criteria:** Build passes, unit tests pass

---

### Task 006: Migrate from SQL Server to Azure SQL

- **Type:** transform
- **Category:** Database (1 incident, potential severity)
- **kbId:** `local-sql-server-to-azure-sql-db`
- **Description:** Migrate database to Managed Identity-based Azure SQL
- **Affected Files:**
  - `Web.config` — `DefaultConnection` connection string (1 incident)
  - `Data/SchoolContext.cs` — DbContext configuration
- **Scope:**
  - Update connection string for Azure SQL Database
  - Configure managed identity authentication (replace SQL credentials)
  - Update Entity Framework DbContext connection configuration
  - Ensure compatibility with Azure SQL Database
- **Success Criteria:** Build passes, unit tests pass

---

### Task 007: Migrate Static Content to Azure Blob Storage

- **Type:** transform
- **Category:** Scale (1 incident, optional severity)
- **kbId:** `local-file-to-azure-blob-storage`
- **Description:** Move static files to Azure Blob Storage for scalable serving
- **Affected Files:**
  - 16 static files detected: CSS (3), JavaScript (12), images (1)
  - `Views/Shared/_Layout.cshtml` — static file references
- **Scope:**
  - Upload static content (Content/, Scripts/, Uploads/) to Azure Blob Storage
  - Configure Azure CDN or Blob Storage static website hosting
  - Update view file references to point to Blob Storage URLs
  - Configure appropriate caching headers
- **Success Criteria:** Build passes, unit tests pass

---

## Execution Order

Tasks should be executed in the order listed. Task 001 (upgrade) is a prerequisite — the .NET version upgrade must be completed before the Azure-specific migration tasks.

1. **001** — .NET Framework 4.8 → .NET 8.0 (foundation for all other changes)
2. **002** — MSMQ → Azure Service Bus (mandatory, highest incident count)
3. **003** — Windows Auth → Easy Auth (mandatory)
4. **004** — Local I/O → Azure Blob Storage (potential)
5. **005** — Credentials → KeyVault (optional, security improvement)
6. **006** — SQL Server → Azure SQL (potential)
7. **007** — Static Content → Azure Blob Storage (optional, scalability improvement)

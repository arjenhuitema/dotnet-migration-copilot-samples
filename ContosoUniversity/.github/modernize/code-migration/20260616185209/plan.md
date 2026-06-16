# Migration Plan

## Session Information
- **Session ID**: a1f2cfc5-b84c-49c6-a063-c0217cf6e39c
- **Date**: 2026-06-16 18:52:09
- **Language**: dotnet (confirmed: .csproj + .cs files present)
- **Target Branch**: modernize/dotnet-20260616185109
- **Uncommitted Changes Policy**: Always Stash

## Knowledge Base
- Using KB `dotnet-dependency-management` (trust: 1401.15) — exact match: SDK-style project migration, PackageReference, legacy .NET Framework to .NET 8 dependency management

## Source Technology Verification
- Found `ContosoUniversity.csproj` with `TargetFrameworkVersion v4.8` ✅
- Found `packages.config` with MVC 5 and .NET Framework packages ✅
- Found `Global.asax.cs` with `MvcApplication : HttpApplication` ✅
- Found `Web.config` with `system.web` and `system.webServer` settings ✅

## Migration Overview

### 1. Project File (ContosoUniversity.csproj)
Convert from legacy format to SDK-style targeting net8.0. Replace all `<Reference>` and `<HintPath>` items with `<PackageReference>`.

**Packages (net8.0 compatible):**
- `Microsoft.AspNetCore.App` (included implicitly via `net8.0-web` target)
- `Microsoft.EntityFrameworkCore.SqlServer` 8.0.x
- `Microsoft.EntityFrameworkCore.Tools` 8.0.x
- `Newtonsoft.Json` 13.0.3 (unchanged)

### 2. Remove packages.config
Remove `packages.config` — packages are now in SDK .csproj.

### 3. Create Program.cs
Replace `Global.asax.cs` with ASP.NET Core `Program.cs` using `WebApplication.CreateBuilder`.
- Configure EF Core DbContext with `IConfiguration`
- Configure DI for `NotificationService`
- Map MVC controller routes

### 4. Create appsettings.json
Replace `Web.config` `<connectionStrings>` and `<appSettings>` with `appsettings.json`.

### 5. Update SchoolContextFactory.cs
Replace `System.Configuration.ConfigurationManager` with `IConfiguration` via DI.

### 6. Update NotificationService.cs
`System.Messaging` (MSMQ) does not exist in .NET 8. Replace with `ConcurrentQueue<Notification>` in-memory implementation preserving the same public interface.

### 7. Update Controllers
- Replace `using System.Web.Mvc` with `using Microsoft.AspNetCore.Mvc`
- Replace `HttpStatusCodeResult(HttpStatusCode.BadRequest)` with `BadRequest()`
- Replace `HttpNotFound()` with `NotFound()`
- Replace `JsonRequestBehavior.AllowGet` with `[HttpGet]` attribute
- Remove `[Bind(Include = ...)]` — use explicit model binding
- BaseController: inject `SchoolContext` via DI constructor

### 8. Update Views
- Replace `@Styles.Render(...)` with `<link>` tags
- Replace `@Scripts.Render(...)` with `<script>` tags
- Remove bundle-specific helpers
- Update error view

### 9. Delete Legacy Files
- `Global.asax` / `Global.asax.cs`
- `App_Start/BundleConfig.cs`
- `App_Start/FilterConfig.cs`
- `App_Start/RouteConfig.cs`
- `Views/Web.config` (MVC5-specific Razor config)
- `Web.config` (replaced by appsettings.json)

## Validation Steps
1. Build verification (dotnet build)
2. CVE check
3. Consistency validation
4. Unit test verification
5. Completeness validation
6. Final build

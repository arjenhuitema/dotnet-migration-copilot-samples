# Migration Plan: Windows Authentication → Azure App Service Easy Auth (Microsoft Entra ID)

- **Migration Session ID**: 12844953-fb7e-4f56-87ef-affcb4021e04
- **Created**: 2026-06-16 19:16:51
- **Language**: .NET (dotnet) — .NET 8.0 ASP.NET Core MVC
- **Target Branch**: modernize/dotnet-20260616185109
- **Uncommitted Changes Policy**: Always Stash
- **Knowledge Base**: dotnet-microsoft-entra-id (trust: 367.34) — exact match: Windows authentication migration

## Scenario

Replace Windows Authentication with Azure App Service built-in authentication (Easy Auth) backed by Microsoft Entra ID. Update authentication/authorization middleware and remove Windows-specific settings.

## Files to be Changed

| File | Change |
|------|--------|
| `ContosoUniversity.csproj` | Add `Microsoft.Identity.Web` and `Microsoft.Identity.Web.UI` NuGet packages |
| `appsettings.json` | Add `AzureAd` configuration section; remove Windows-specific `Integrated Security` reference |
| `Program.cs` | Add `AddMicrosoftIdentityWebAppAuthentication`, `AddMicrosoftIdentityUI`, `app.UseAuthentication()` |
| `Controllers/StudentsController.cs` | Add `[Authorize]` attribute |
| `Controllers/CoursesController.cs` | Add `[Authorize]` attribute |
| `Controllers/DepartmentsController.cs` | Add `[Authorize]` attribute |
| `Controllers/InstructorsController.cs` | Add `[Authorize]` attribute |
| `Controllers/NotificationsController.cs` | Add `[Authorize]` attribute |
| `Views/Shared/_Layout.cshtml` | Add login/logout partial and display authenticated user name |

## Migration Steps

### Phase 1: Dependencies
- Add Microsoft.Identity.Web 3.7.1
- Add Microsoft.Identity.Web.UI 3.7.1

### Phase 2: Configuration
- Add AzureAd section to appsettings.json

### Phase 3: Code Changes
- Update Program.cs with authentication services and middleware
- Add [Authorize] to controllers
- Update _Layout.cshtml with user identity UI

## Validation & Fix Steps

### Stage 1: Build and Fix Loop (Up to 10 rounds)
### Stage 2: CVE Vulnerability Check
### Stage 3: Consistency Validation
### Stage 4: Unit Test Verification
### Stage 5: Completeness Validation
### Stage 6: Final Build Verification

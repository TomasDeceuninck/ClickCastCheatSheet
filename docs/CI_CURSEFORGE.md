CurseForge CI / Automatic Packaging
=================================

This repository contains a GitHub Actions workflow that triggers CurseForge's automatic packaging using the repository webhook-style packaging endpoint.

What the workflow does
- Runs on pushes to `main` and on tag pushes.
- Posts a packaging request to the CurseForge packaging endpoint:
  `https://www.curseforge.com/api/projects/{projectID}/package?token={token}`

Required repository secrets
- `CURSEFORGE_API_TOKEN` — your CurseForge API token (from https://www.curseforge.com/account/api-tokens)
- `CURSEFORGE_PROJECT_ID` — numeric project id from your CurseForge project's Overview page

How release type is determined
- This workflow uses CurseForge's automatic release type detection. If you push a tag that contains `alpha` or `beta` the file will be marked accordingly. Otherwise it will be a release.

Testing locally (dry-run)
1. Ensure you have `curl` installed.
2. From your repo root run (PowerShell example):

```powershell
$env:CF_PROJECT_ID = "<your_project_id>"
$env:CF_TOKEN = "<your_token>"
$payload = '{"ref":"refs/heads/main","after":"0000000000000000000000000000000000000000"}'
Invoke-RestMethod -Method Post -Uri "https://www.curseforge.com/api/projects/$($env:CF_PROJECT_ID)/package?token=$($env:CF_TOKEN)" -Body $payload -ContentType "application/json"
```

If successful, CurseForge will queue packaging of your repository. Packaging may take a minute or two depending on repo size and queue.

Notes
- Keep your API token secret. Treat it like any other secret; use GitHub repository secrets for CI.
- If you need more control over what is packaged, create a `pkgmeta.yaml` in the repository root. See CurseForge docs for options (file names `pkgmeta.yaml` or `.pkgmeta`).

Troubleshooting
- 401/403 responses mean the token is invalid or not authorized for that project.
- 404 indicates the project id is incorrect.
- If packaging seems to do nothing, check the CurseForge project's Activity/Files page for packaging jobs and errors.

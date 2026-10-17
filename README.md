# Power Platform / Dataverse Solution Scanner

Backs up every unmanaged solution in one or more Dataverse environments, in a form you can commit and diff, then runs a basic scan over the backup.

## Before you start

- [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) 2 or later (`pac install latest` updates it), signed in with `pac auth create` as someone who can reach every environment you list.
- PowerShell 7.
- Copy `config/environments.template.json` to `config/environments.json` and give each environment a `name` (its folder under `solutions/`) and its `guid` (the environment ID, without braces). The script checks the file against `config/environments.schema.json` before it starts; VS Code checks it as you type.

## Running a backup

```powershell
.\backup-solutions.ps1                 # back up everything
.\backup-solutions.ps1 -SkipExisting   # only fetch solutions you don't have yet
.\backup-solutions.ps1 -Publish        # publish all customisations first
```

For each environment it writes, under `solutions/<name>/`:

- `solutions.json`: every solution in the environment, from `pac solution list --json`.
- `_backups/<solution>.zip`: each unmanaged solution, ready for `pac solution import`.
- `<solution>/`: the same solution unpacked with `pac solution unpack`, a file per component.
- `<solution>/CanvasApps/<app>_src/Src/*.pa.yaml`: each canvas app's Power Fx source, the part of a `.msapp` that belongs in source control.

Managed solutions and Default are skipped. A solution that fails to export is reported and the run carries on.

Exports only include published components. `-Publish` fixes that, but it publishes everyone's work in progress, so use it only when that's fine.

## What it doesn't cover

- Components that only exist in Default.
- Data: solutions carry customisations, not records.
- Secret scrubbing: exports can hold keys and connection details.

## Scanning the backup

Run `.\security-scan.ps1` for a basic report. Rules are in `config/security-scan.json`; outputs go to `output/<name>/security-scan*` as JSON and CSV.

## Testing

`pwsh tests/smoke.ps1` runs the backup end to end against a stand-in `pac`, so changes can be checked without an environment.

## Disclaimer

Backups **must be manually checked** for sensitive information before being sent to any AI tool, as they *will* contain potential keys/secrets.

This software is provided AS IS, with no implied or explicit warranties of any kind.

The scan is provided for sample and demo purposes only. You are expected to write your own security scan logic, or use third party tools (such as [trufflehog](https://github.com/trufflesecurity/trufflehog), [kingfisher](https://github.com/mongodb/kingfisher), etc.) for secret scanning.

Do not rely on the output of this for any security evaluation.

Run at your own risk. Do not run code without understanding it first.

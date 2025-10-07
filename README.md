# Power Platform / Dataverse Solution Scanner

> **Prerequisites:**  
> Ensure you have the [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) installed and have authenticated (`pac auth create`) before running the provided import script.

## Creating the environments config file

Copy the `config/environments.template.json` to a file called `config/environments.json`.

Using an IDE like VS Code will help you ensure your changes are valid against the configuration requirements.

## Running a backup

Run `backup-dataverse-environment-solutions.ps1` to refresh them.

Backups are stored under `solutions/`.

## Scanning the backup

This repo includes an automated security scan for exported Dataverse solutions.

Run `.\security-review.ps1` to generate a basic report.

Outputs are written to `output/security-scan*` as JSON and CSV log.

## Disclaimer

These **must be manually checked** for sensitive information before being sent to any AI tool, as they *will* contain potential keys/secrets.

This software is provided AS IS, with no implied or explicit warranties of any kind.

These scans are provided for sample and demo purposes only.

You are expected to write your own security scan logic, or implement your own using third party tools (such as [trufflehog](https://github.com/trufflesecurity/trufflehog), [kingfisher](https://github.com/mongodb/kingfisher), etc.) for secret scanning.

Do not rely on the output of this for any security evaluation.

Run at your own risk. Do not run code without understanding it first.

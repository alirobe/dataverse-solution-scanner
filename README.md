# Power Platform / Dataverse Solution Scanner

> **Prerequisites:**  
> Ensure you have the [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) installed and have authenticated (`pac auth create`) before running the provided import script.


## Running a backup 

Run `backup-dataverse-environment-solutions.ps1` to refresh them.

Backups are stored under `solutions/`.

## Scanning the backup

This repo includes an automated security scan for exported Dataverse solutions.

Run `.\security-review.ps1` to generate a basic report, which **must be manually checked** for sensitive information before being sent to any AI tool.

Outputs are written to `output/security-scan*` as JSON and CSV log.

# ZabbixAgent-update
Interactive manager for Windows Zabbix Agent installation
---

03.08.2021 Roman Ermakov <r.ermakov@emg.fm>


[![Zabbix Agent][batbadge]][zabbixagent]

Interactive manager for [Zabbix Agent](https://www.zabbix.com/download_agents) installation, update and removal on remote or local Windows host.

## Requirements:

* You need to have PowerShell enabled on local machine;
* You need to have admin credentials on machine where you plan to manage Agent. If you manage Agent on local PC please use "Run as Admin" feature;
* You need to configure zabbix_agentd.conf with at least server IP address. Defaults are:
    * store warning-level file log at `C:\ProgramData\Zabbix`;
    * enable and log remote commands;
    * `hostname` = `system.hostname`
* You'll get zabbix_agentd.conf stored at `C:\ProgramData\Zabbix` by default. Otherwise change set `configFile ` variable in the code.
* [**Update latest Agent version and release numbers**](https://www.zabbix.com/download_agents) in `ZabbixAgentVersion` variable in the code.

## Usage:

`update-agent \\COMPUTERNAME`

Run interactive script for \\COMPUTERNAME

`update-agent \\COMPUTERNAME --default`

Run non-interactive script for \\COMPUTERNAME

`update-agent \\localhost`

Run interactive script for local machine. Please use elevation (Run as Admin).

`update-agent \\localhost --default`

Run non-interactive script for local machine. Please use elevation (Run as Admin).

## What this script do:

* Disconnects admin share (c$) for remote host.
* Detects OS architecture (32/64-bit)
* Downloads Zabbix Agent .ZIP-file.
* Extracts Zabbix Agent. Example location: `.\5.4.3\64-bit\bin`
* Search for Zabbix Agent service on remote machine.
* If found:
    * query existing service for `zabbix_agentd.exe` and `zabbix_agentd.conf` locations;
    * stops service;
    * ask for backup `zabbix_agentd.conf` to `zabbix_agentd.conf.bak`;
    * ask for remove Zabbix Agent service;
    * ask for `zabbix_agentd.conf` location - new by default to `C:\ProgramData\Zabbix`, or old as provided by old service;
    * ask for remove service folder with old files.
* Asks to copy new version of Zabbix Agent and configuration file.
* Creates Zabbix Agent service.
* Ask to start Zabbix Agent service.

### Non-interactive mode using --default switch:

* Disconnects admin share (c$) for remote host.
* Detects OS architecture (32/64-bit)
* Downloads Zabbix Agent .ZIP-file.
* Extracts Zabbix Agent. Example location: `.\5.4.3\64-bit\bin`
* Search for Zabbix Agent service on remote machine.
* If found:
    * stops service;
    * removes Zabbix Agent service;
    * sets configuration file location to `C:\ProgramData\Zabbix\abbix_agentd.conf`;
    * removes service folder with old files.
* Copies new version of Zabbix Agent and configuration file.
* Creates Zabbix Agent service.
* Starts Zabbix Agent service.

[![BuyMeCoffee][buymecoffeebadge]][buymecoffee]

## History
* 2021-08-03: 2.0 Second release on Windows Batch

[zabbixagent]: https://www.zabbix.com/download
[batbadge]: https://img.shields.io/badge/Windows%20Batch-PowerShell-blue
[buymecoffee]: https://www.buymeacoffee.com/twelve
[buymecoffeebadge]: https://img.shields.io/badge/buy%20me%20a%20coffee-donate-blue.svg?style=for-the-badge

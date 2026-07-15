# morelogin-skills

Open-source MoreLogin skills for AI agents.

This repository contains MoreLogin setup and industry workflow skills for AI agents.

MoreLogin skills are organized into two layers:

- Setup skill: teaches agents how to install, configure, and verify MoreLogin Client and `ml-cli`.
- Industry skills: teach agents how to complete real business workflows on top of MoreLogin browser environments and cloud phones.

The `ml-cli` implementation can remain closed source. This repository only describes agent-facing workflows, safety rules, command contracts, and output formats.

## Repository Layout

```text
skills/
  morelogin-setup/
    SKILL.md                     Concise setup and routing contract
    install.md                   Stable public setup entry point
    agents/openai.yaml           Codex UI and invocation metadata
    references/                  Task-specific detailed guidance
      release-security.md       URL, artifact, signer, and reuse rules
      windows-installation.md   Windows Client and UAC workflow
      macos-linux-installation.md
      operations.md             Selection, timing, and mutation rules
    scripts/                     Deterministic bootstrap installers
  amazon-keyword-search/         Amazon.com keyword result research
  amazon-product-detail/         Amazon.com product detail inspection
  tiktok-product-search/         TikTok Shop product search
  <workflow>/
    SKILL.md                     Workflow instructions
    examples.md                  Example user requests
    output-schema.json           Structured report shape
```

## Website Copy

The official website should provide a short copy-to-agent prompt that points to the setup guide:

```text
Please follow this guide to install, configure, and verify MoreLogin with ml-cli:
https://github.com/MoreLoginBrowser/morelogin-skills/blob/main/skills/morelogin-setup/install.md

If I do not have a MoreLogin account, open https://www.morelogin.com/register and ask me to register and sign in manually. Do not submit registration forms or handle verification codes without my confirmation.
```

## Example Natural Language Tasks

- Check how many browser environments are on the first MoreLogin page.
- Open the browser environment named `P-1`.
- Find browser environments whose name, group, tag, or remark contains `TikTok`.
- Open cloud phone `CP-204` and display the window.
- Search `amazon.com` for `wireless earbuds` and return the first 10 organic results.
- Read the visible details for an Amazon product by ASIN.
- Search TikTok Shop US for products matching `portable blender`.

## Skills Catalog

Skills are organized by one concrete user intent. There is no broad `KOL`, `e-commerce`, or platform-wide category skill; new workflows should be added as separate directories with focused names and explicit read/write boundaries.

| Skill | Purpose |
|---|---|
| `amazon-keyword-search` | Amazon.com keyword search and first 10 organic results |
| `amazon-product-detail` | One Amazon product detail inspection |
| `tiktok-product-search` | TikTok Shop product listing search |

## Setup Dependency

Industry skills must not reimplement MoreLogin local API calls. They should depend on:

```text
skills/morelogin-setup
```

The setup skill is responsible for:

- installing and verifying `ml-cli`
- discovering MoreLogin Desktop local API connectivity
- selecting browser environments or cloud phones
- opening environments
- handling localhost sandbox permission errors
- enforcing confirmation gates

Industry skills are responsible for:

- business workflow steps
- user input requirements
- platform-specific checks
- structured output formats
- evidence and reporting requirements

## Release Checklist

Before publishing the install commands on the website:

- Use the published `https://releases.morelogin.com/client/prod/install_1.0.sh` for macOS/Linux.
- Use the published `https://releases.morelogin.com/client/prod/install_1.1.ps1` for Windows.
- Verify `curl -fsSL https://releases.morelogin.com/client/prod/install_1.0.sh | bash` on macOS and Ubuntu.
- Verify `irm https://releases.morelogin.com/client/prod/install_1.1.ps1 | iex` on Windows PowerShell.
- Verify the published scripts from their release URLs before each script release.
- When `skills/morelogin-setup/scripts/install.ps1` changes, publish it under a new versioned URL before updating the Windows command above and in `install.md`; repository changes alone do not update the hosted bootstrap script.
- Keep MoreLogin Client updates inside the Client. The bootstrap scripts install or update `ml-cli`, skip an already installed Client, and download the Client installer only when the Client is missing. Use `MORELOGIN_SKIP_CLIENT=1` only for CLI-only installation or testing.

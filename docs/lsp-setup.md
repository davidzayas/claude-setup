# LSP setup — language servers and Claude Code plugins (macOS)

This is the runbook for the kit in `lsp/`. It is **separate from `install.sh`**:
the repo installer never runs it, and `uninstall.sh` does not undo it. What
it installs (Homebrew formulae, the .NET SDK, `csharp-ls`, a wrapper script,
one `~/.zprofile` line, Claude Code plugins) stays until you remove it by
hand (see Uninstalling). How sessions *use* these servers is set by
`CLAUDE.md` → "Code intelligence" (built-in `LSP` tool first; Serena only
on request).

This kit sets up Claude Code's official **code intelligence (LSP) plugins** for nine languages: C/C++, C#, Go, Java, Kotlin, Python, Rust, Swift, and TypeScript.

With these plugins, Claude Code talks to real language servers, the same technology behind VS Code's IntelliSense. That gives Claude two new abilities. First, after every edit it sees type errors, missing imports, and syntax problems, and fixes them in the same turn. Second, it can jump to definitions, find references, and trace call hierarchies directly instead of grepping.

Each plugin only tells Claude Code how to talk to a language server. It does **not** install the server itself. That is why there are two scripts:

| Script | What it does |
|---|---|
| `install-lsp-binaries.sh` | Installs the nine language server binaries on your Mac |
| `install-claude-lsp-plugins.sh` | Installs the matching Claude Code plugins from Anthropic's official marketplace |

---

## Requirements

- **macOS**, either Apple Silicon or Intel.
- **Claude Code**, already installed and signed in. Running `claude --version` in Terminal should work.
- **An admin password.** The .NET SDK installer asks for it.
- **About 3–5 GB of free disk space** for the JDK, .NET, LLVM (if needed), and the language servers.
- **Xcode from the App Store** if you work in Swift. The Command Line Tools alone are enough for everything else. The script installs them if they're missing.
- **Homebrew.** If it isn't installed, the binaries script **downloads and runs
  Homebrew's official installer** (`curl … | bash` from github.com/Homebrew).
  Install Homebrew yourself first if you'd rather not.

---

## Quick start

From the root of this repo:

```bash
# 1. Install the language servers (takes 5–15 minutes)
lsp/install-lsp-binaries.sh

# 2. Reload your shell profile so PATH changes take effect
source ~/.zprofile

# 3. Install the Claude Code plugins
lsp/install-claude-lsp-plugins.sh
```

Then **start a new Claude Code session**, or run `/reload-plugins` in one that's already open.

Both scripts are safe to re-run. Anything already installed is skipped, except
`csharp-ls`: the binaries script updates it to its latest release on every run.

The binaries script exits nonzero when a server is missing or a step failed. For
example, without Xcode `sourcekit-lsp` is missing. That's expected if you don't
use that language: the plugins script still installs the plugins for the servers
you do have.

---

## What gets installed

| Language | Binary | Installed from | Claude Code plugin |
|---|---|---|---|
| C/C++ | `clangd` | Apple toolchain (falls back to Homebrew `llvm`) | `clangd-lsp` |
| C# | `csharp-ls` | `dotnet tool`, using the .NET 10 SDK | `csharp-lsp` |
| Go | `gopls` | Homebrew (`go`, `gopls`) | `gopls-lsp` |
| Java | `jdtls` | Homebrew (includes OpenJDK) | `jdtls-lsp` |
| Kotlin | `kotlin-language-server` | Homebrew | `kotlin-lsp` |
| Python | `pyright-langserver` | Homebrew (`pyright`) | `pyright-lsp` |
| Rust | `rust-analyzer` | `rustup` if present, otherwise Homebrew | `rust-analyzer-lsp` |
| Swift | `sourcekit-lsp` | Apple toolchain (Xcode) | `swift-lsp` |
| TypeScript | `typescript-language-server` | Homebrew (with `typescript`) | `typescript-lsp` |

**Changes the binaries script makes outside Homebrew:**

- **PATH:** It adds `export PATH="$PATH:$HOME/.dotnet/tools"` to `~/.zprofile`, only once.
- **.NET 10 SDK:** It installs the current .NET SDK to `/usr/local/share/dotnet`, next to any .NET you already have. It does **not** remove or replace other .NET versions.
- **C# wrapper:** It writes a small wrapper at `$(brew --prefix)/bin/csharp-ls` that launches `csharp-ls` on the .NET 10 runtime. It does **not** change your global `DOTNET_ROOT`. The C# troubleshooting section below explains why.
- **Symlinks:** It may symlink `clangd` or `sourcekit-lsp` into `$(brew --prefix)/bin` if they exist in the Apple toolchain but aren't on your PATH.

---

## Installation scope

The plugins script installs to **user scope** by default, meaning for you in every project. You can pass a different scope:

```bash
lsp/install-claude-lsp-plugins.sh user      # default – you, all projects
~/playground/claude-setup/lsp/install-claude-lsp-plugins.sh project   # run from the TARGET repo's root
~/playground/claude-setup/lsp/install-claude-lsp-plugins.sh local     # likewise
```

`project` and `local` write into the **current directory's** `.claude/`, so run
them from the project you mean, by absolute path. `project` scope writes the
plugins into that repo's `.claude/settings.json`, so teammates get them when they pull. Each person still needs the binaries installed on their own machine (step 1).

---

## Verify it works

0. **Read the binaries script's summary.** A `(found, with PATH warning)` line
   for `typescript-language-server` means an nvm copy shadows Homebrew's; see
   "TypeScript plugin stops working after switching Node versions" below.
1. **Check the plugins:** `claude plugin list` shows each plugin's scope and
   whether it is enabled. That proves *installed*, not *working*. Then start
   Claude Code in any project and run `/plugin`. The **Installed** tab should list a plugin for each language server the binaries script found (the plugins script skips the rest), and the **Errors** tab should be empty.
2. **Test navigation:** Ask Claude something only a language server can answer precisely, such as *"Find every reference to `<some function>` in this codebase."*
3. **Expect a delay the first time:** The first request in a large Java, Kotlin, or Rust project can take a minute or two while the server indexes. After that it's fast.
4. **Watch for diagnostics:** When Claude Code shows something like *"Found 3 new diagnostic issues in 2 files,"* press **Ctrl+O** to read them.

---

## Troubleshooting

### Binaries script

#### "Xcode Command Line Tools not found"
The script opens Apple's installer and exits. Finish that install, then re-run the script.

#### `sourcekit-lsp` NOT FOUND
Swift's language server comes with Xcode. Install Xcode from the App Store, open it once to accept the license, then re-run the script. You can also install a Swift toolchain from swift.org. If you don't use Swift, ignore this. The plugins script skips `swift-lsp` automatically.

#### rust-analyzer installed but warns about rustup
`rust-analyzer` needs a Rust toolchain to analyze real projects. Install one:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### C# (`csharp-ls`)

C# is the language most likely to need attention. Current `csharp-ls` releases require **.NET 10**, and many machines already have an older .NET, often Homebrew's `dotnet@8`. The binaries script handles this for you. If you're fixing things by hand, or the script reports a problem, these are the errors you may see.

#### Error: `Settings file 'DotnetToolSettings.xml' was not found in the package`
```
The settings file in the tool's NuGet package is invalid: Settings file 'DotnetToolSettings.xml' was not found in the package.
Tool 'csharp-ls' failed to install.
```
**Cause:** You ran `dotnet tool install` with an older SDK such as .NET 8. New `csharp-ls` packages use a packaging format that older SDKs can't read. The package itself isn't broken.

**Fix:** Install the current SDK next to your existing one, then install the tool with **that** `dotnet`:
```bash
which dotnet && dotnet --list-sdks                       # probably shows 8.x
brew install --cask dotnet-sdk                           # installs to /usr/local/share/dotnet
/usr/local/share/dotnet/dotnet --list-sdks               # should show 10.x
/usr/local/share/dotnet/dotnet tool install --global csharp-ls
```
Your plain `dotnet` command keeps resolving to your existing version, so your projects are unaffected.

#### Warning: `Tools directory '~/.dotnet/tools' is not currently on the PATH`
If the binaries script already ran, the PATH line is already in `~/.zprofile`. Your current terminal just hasn't loaded it yet:
```bash
source ~/.zprofile
```
**Don't** run the `cat << EOF >> ~/.zprofile` command that .NET suggests, because it would add a duplicate line.

#### Error: `csharp-ls` won't start ("You must install or update .NET to run this application")
```
Framework: 'Microsoft.NETCore.App', version '10.0.0' (arm64)
.NET location: /opt/homebrew/Cellar/dotnet@8/.../libexec
The following frameworks were found:
  8.0.x at [...]
```
**Cause:** Your shell sets `DOTNET_ROOT` to an older .NET install. Check it with `echo $DOTNET_ROOT`. When `DOTNET_ROOT` is set, `csharp-ls` looks for its runtime there and finds only .NET 8.

**Fix (recommended):** Use a wrapper that sets `DOTNET_ROOT` for `csharp-ls` only. The binaries script creates this automatically. To create it by hand:
```bash
cat > "$(brew --prefix)/bin/csharp-ls" << 'EOF'
#!/bin/sh
export DOTNET_ROOT=/usr/local/share/dotnet
exec "$HOME/.dotnet/tools/csharp-ls" "$@"
EOF
chmod +x "$(brew --prefix)/bin/csharp-ls"
hash -r

which csharp-ls        # → /opt/homebrew/bin/csharp-ls (or /usr/local/bin on Intel)
csharp-ls --version    # → csharp-ls, 0.28.0 ...
```
The wrapper works because Homebrew's `bin` comes before `~/.dotnet/tools` on your PATH, so both your shell and Claude Code find the wrapper first. If your PATH has them the other way round, the binaries script reports `csharp-ls … (found, with PATH warning)`. The script also refuses to overwrite a `csharp-ls` file in Homebrew's `bin` that it didn't create. It replaces a symlink there rather than writing through it into the real tool.

**Alternative:** Change `DOTNET_ROOT` globally. Find where it's set with `grep -n DOTNET_ROOT ~/.zprofile ~/.zshrc` and change that line to `export DOTNET_ROOT=/usr/local/share/dotnet`. This can break *other* .NET 8 global tools you have installed, which is why the wrapper is preferred.

#### .NET first-run messages (telemetry, HTTPS dev certificate, "issue verifying workloads")
These are normal the first time the new SDK runs, and `csharp-ls` doesn't need them. You can ignore them.

### Plugins script and Claude Code

#### `Marketplace "claude-plugins-official" not found`, or the marketplace can't be added
Claude Code normally adds the official marketplace automatically, but corporate proxies and network filtering can block the download. Add it by hand:
```bash
claude plugin marketplace add anthropics/claude-plugins-official
```
If that fails too, check your proxy or VPN, or ask whoever manages your Claude Code settings whether a managed policy restricts marketplaces.

#### A plugin was "skipped — binary not on PATH"
The plugins script only installs a plugin when its binary is available. Fix the binary using the sections above, then install just that plugin:
```bash
claude plugin install csharp-lsp@claude-plugins-official --scope user
```

#### `Executable not found in $PATH` in the `/plugin` Errors tab
The plugin installed, but Claude Code can't see the binary.
1. **Check your terminal:** Run `which <binary>` in the same terminal you launch Claude Code from.
2. **Reload your profile:** If the binary isn't found, run `source ~/.zprofile` or open a new terminal, then restart Claude Code.
3. **Check where you launched from:** If you launch Claude Code from an IDE or the desktop app rather than a terminal, it may not load your shell profile the same way. Re-sourcing `~/.zprofile` in a terminal does **not** change a session the desktop app already started. Fix the PATH that launcher sees, fully quit and restart it, and check `/plugin` → Errors again *in that session*. Launching `claude` from a terminal is a quick way to confirm this is the cause.
4. **Don't reinstall the plugin** as a first step. The plugin is fine; the session can't see the binary.

#### TypeScript plugin stops working after switching Node versions
This happens if `typescript-language-server` was installed with `npm install -g` under nvm, fnm, or asdf. It's then only on PATH while that exact Node version is active. The current binaries script installs it with Homebrew to avoid this. If you installed it through nvm earlier, run:
```bash
brew install typescript-language-server typescript
```
If the nvm copy still comes first on PATH (`which typescript-language-server`
shows `~/.nvm/...`; the binaries script reports `found, with PATH warning`),
Claude Code keeps using it. Remove it from each Node version that has it
(`npm uninstall -g typescript-language-server typescript` with that version
active), or put `$(brew --prefix)/bin` ahead of nvm on PATH. Neither script
does this for you.

#### `/plugin` command not recognized
Your Claude Code is too old. Update it with `brew upgrade claude-code`, `npm install -g @anthropic-ai/claude-code@latest`, or by re-running the native installer. Then restart.

#### High memory use
`jdtls`, `rust-analyzer`, and `pyright` can use a lot of memory on large repos. Disable just that plugin:
```bash
/plugin disable rust-analyzer-lsp@claude-plugins-official
```

#### Unresolved-import errors in monorepos
Language servers may flag internal packages as unresolved if the workspace isn't configured the way the server expects. These false positives don't stop Claude from editing code.

#### No LSP in Claude Code on the web (cloud sessions)
This is expected. Claude Code doesn't start plugin language servers in cloud sessions. The plugins work in local terminal sessions.

---

## Managing plugins later

```bash
/plugin                                                    # interactive manager
/plugin disable <plugin>@claude-plugins-official           # turn one off
/plugin enable  <plugin>@claude-plugins-official           # turn it back on
/plugin uninstall <plugin>@claude-plugins-official         # remove it
```

The official marketplace auto-updates by default, so the plugins stay current. To update the language servers themselves, run `brew upgrade`. For C#, run `/usr/local/share/dotnet/dotnet tool update --global csharp-ls`.

## Uninstalling

The binaries script doesn't record what it installed versus what it found
already there. Anything already installed was skipped, not taken over, so
uninstall only what you didn't have before and don't otherwise use. Nothing
below is a single paste-and-run block, on purpose.

**1. Plugins.** Safe to remove; they only point Claude Code at the servers.

```bash
# User scope. For project/local installs, run again from that repo with
# --scope project (or --scope local).
for p in clangd-lsp csharp-lsp gopls-lsp jdtls-lsp kotlin-lsp pyright-lsp rust-analyzer-lsp swift-lsp typescript-lsp; do
  claude plugin uninstall "$p@claude-plugins-official" --scope user
done
```

**2. Homebrew formulae, one at a time.** Check each one first. `brew uses
--installed <formula>` lists what else depends on it; if you used it before
running the kit, keep it.

```bash
brew uses --installed gopls                # then, only if nothing needs it:
brew uninstall gopls
# likewise: go, jdtls, kotlin-language-server, pyright, rust-analyzer,
# typescript-language-server, typescript, and llvm (only if the script
# installed it for clangd)
```

**3. C#.** Remove the wrapper only if it is the script's own. The SDK cask
installs next to any other .NET, so remove it only if nothing else needs
.NET 10.

```bash
/usr/local/share/dotnet/dotnet tool uninstall --global csharp-ls
w="$(brew --prefix)/bin/csharp-ls"
grep -q "Wrapper created by install-lsp-binaries.sh" "$w" && rm "$w"
brew uninstall --cask dotnet-sdk           # only if nothing else uses .NET 10
```

**4. Symlinks the script added** to Homebrew's `bin` for `clangd` or
`sourcekit-lsp`. Remove one only if it points into Apple's toolchain or
Homebrew's `llvm`:

```bash
for b in clangd sourcekit-lsp; do
  l="$(brew --prefix)/bin/$b"
  [ -L "$l" ] && echo "$l -> $(readlink "$l")"
done
# then: rm "$(brew --prefix)/bin/<name>" for the ones that match
```

**5. `~/.zprofile`.** Delete this line by hand:

```bash
export PATH="$PATH:$HOME/.dotnet/tools"
```

If the binaries script installed Homebrew itself, remove it with Homebrew's
own uninstaller (see brew.sh); nothing here does that.

---

## Reference

- Discover and install plugins: https://code.claude.com/docs/en/discover-plugins
- Code intelligence plugin list and required binaries: see the "Code intelligence" section on that page

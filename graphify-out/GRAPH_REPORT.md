# Graph Report - D:\PROJECTS\OpenClaw-On-Android  (2026-05-28)

## Corpus Check
- 77 files · ~60,823 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 389 nodes · 519 edges · 46 communities (32 shown, 14 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 27 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]

## God Nodes (most connected - your core abstractions)
1. `lib.sh (Shared Function Library)` - 17 edges
2. `Introduction Doc — What is OCA?` - 11 edges
3. `Installation Guide` - 10 edges
4. `OpenClaw Platform` - 9 edges
5. `RTX3: Master Arsenal (AI CLIs, Playwright, Homebrew)` - 9 edges
6. `install-nodejs.sh (RTX2 glibc Node.js Installer)` - 8 edges
7. `GLIBC_LDSO ld-linux-aarch64.so.1 path` - 8 edges
8. `Quickstart Doc — 5-Minute Setup Guide` - 8 edges
9. `AI CLI Tools (Claude Code, Gemini, Codex, Qwen)` - 7 edges
10. `install-glibc.sh (RTX2 glibc Runtime Installer)` - 7 edges

## Surprising Connections (you probably didn't know these)
- `setup-termux-api.sh — Termux:API Installer & Verifier` --conceptually_related_to--> `RTX1: Infrastructure Layer (Termux $PREFIX)`  [INFERRED]
  scripts/setup-termux-api.sh → docs/architecture.mdx
- `setup-boot.sh — Termux:Boot Script Generator` --conceptually_related_to--> `Termux:Boot Doc — Auto-Start Configuration`  [INFERRED]
  scripts/setup-boot.sh → docs/termux-boot.mdx
- `oca-boot.sh Auto-Start Script` --calls--> `OpenClaw Gateway Service`  [EXTRACTED]
  scripts/setup-boot.sh → docs/quickstart.mdx
- `setup-env.sh — .bashrc Environment Configurator` --implements--> `OCA Environment Variables (OCA_DIR, OCA_GLIBC, TMPDIR, NODE_OPTIONS)`  [EXTRACTED]
  scripts/setup-env.sh → docs/configuration.mdx
- `setup-tmux.sh — tmux Session Setup Info` --references--> `OpenClaw Gateway Service`  [EXTRACTED]
  scripts/setup-tmux.sh → docs/quickstart.mdx

## Hyperedges (group relationships)
- **Full Installation Pipeline** — bootstrap_sh, install_sh, platforms_openclaw_install_sh, post_setup_sh [EXTRACTED 1.00]
- **Android Compatibility Patch Set** — patches_argon2_stub_js, patches_glibc_compat_js, patches_spawn_h, patches_systemctl [EXTRACTED 1.00]
- **Update Pipeline** — update_sh, update_core_sh, platforms_openclaw_install_sh [EXTRACTED 1.00]
- **Full Uninstall Pipeline** — uninstall_sh, platforms_openclaw_uninstall_sh [EXTRACTED 1.00]
- **oca CLI Command Set** — func_oca_cmd_update, func_oca_cmd_install, func_oca_cmd_uninstall, func_oca_cmd_status, func_oca_cmd_shell, func_oca_cmd_start, func_oca_cmd_clean, func_oca_show_version [EXTRACTED 1.00]
- **OpenClaw Platform Script Bundle** — platforms_openclaw_install_sh, platforms_openclaw_status_sh, platforms_openclaw_uninstall_sh, platforms_openclaw_env_sh [EXTRACTED 1.00]
- **Installed AI CLI Tools Group** — concept_ai_cli_tools, concept_code_server, concept_opencode, concept_clawdhub [INFERRED 0.85]
- **glibc Compatibility Layer** — concept_glibc, patches_glibc_compat_js, concept_node_wrapper, concept_bionic_to_glibc, var_glibc_ldso [EXTRACTED 1.00]
- **RTX1 Tier: Infrastructure & Env Check Scripts** — install_infra_deps_sh, check_env_sh, rtx1_tier [EXTRACTED 1.00]
- **RTX2 Tier: glibc Runtime, Node.js, Build Tools** — install_glibc_sh, install_nodejs_sh, install_build_tools_sh, rtx2_tier [EXTRACTED 1.00]
- **RTX3 Tier: Optional Tools (Go, Homebrew, Chromium, Playwright, OpenCode, code-server)** — install_go_sh, install_homebrew_sh, install_chromium_sh, install_playwright_sh, install_opencode_sh, install_code_server_sh, rtx3_tier [EXTRACTED 1.00]
- **glibc --library-path ld.so wrapper pattern (used by node, go, opencode)** — glibc_library_path_pattern, glibc_ldso_aarch64, install_nodejs_node_wrapper, install_go_go_wrapper, install_opencode_ldso_concat [EXTRACTED 1.00]
- **Dual-Engine Wrapper Pattern (chroot/proot for Homebrew, code-server, Playwright)** — install_homebrew_dual_engine, install_code_server_dual_engine, install_playwright_dual_engine, debian_proot_rootfs [EXTRACTED 1.00]
- **OpenClaw Platform Lifecycle (update, verify, uninstall)** — update_sh, verify_sh, uninstall_sh, openclaw_npm_pkg, openclaw_dir_data [EXTRACTED 1.00]
- **OpenClaw Patch Pipeline (apply → path-patch → sharp-build)** — apply_patches_sh, patch_paths_sh, build_sharp_patch_sh, patch_log_file [EXTRACTED 1.00]
- **Sharp Build Strategy (WASM fallback → native rebuild)** — build_sharp_sh, build_sharp_patch_sh, sharp_wasm32_pkg, termux_compat_h [EXTRACTED 1.00]
- **lib.sh shared functions used by platform scripts** — lib_sh, update_sh, verify_sh, uninstall_sh, backup_sh, check_env_sh [EXTRACTED 1.00]
- **glibc install-chain: glibc → nodejs → (go, opencode require glibc marker)** — install_glibc_sh, install_nodejs_sh, install_go_sh, install_opencode_sh, install_glibc_glibc_arch_marker [EXTRACTED 1.00]
- **RTX Tier Architecture (RTX1/RTX2/RTX3 Layers)** — arch_rtx1_infra, arch_rtx2_engine, arch_rtx3_arsenal, doc_architecture, doc_introduction, doc_quickstart, verify_rtx1_check, verify_rtx3_check [EXTRACTED 1.00]
- **glibc Compatibility Subsystem** — arch_glibc_runner, arch_glibc_compat_js, arch_dns_fix, arch_bionic_libc, glibc_node_v24, node_grun_wrapper, trouble_dns_eai_again, trouble_glibc_linker [EXTRACTED 1.00]
- **lib.sh Exported Functions** — lib_sh, lib_detect_platform, lib_validate_platform_name, lib_ask_yn, lib_load_platform_config, lib_resolve_repo_base, lib_bashrc_markers, lib_project_dir, lib_oca_version [EXTRACTED 1.00]
- **Setup Scripts (all source lib.sh or share patterns)** — setup_boot_sh, setup_env_sh, setup_paths_sh, setup_root_sh, setup_termux_api_sh, setup_tmux_sh, lib_sh [EXTRACTED 1.00]
- **AI CLI Tools (npm global installs)** — ai_cli_qwen_code, ai_cli_claude_code, ai_cli_gemini, ai_cli_codex, doc_ai_cli_tools, arch_rtx3_arsenal [EXTRACTED 1.00]
- **Auto-Start Boot Chain** — setup_boot_sh, setup_boot_oca_boot, termux_boot_script, doc_termux_boot, openclaw_gateway, ssh_openssh_port_8022 [EXTRACTED 1.00]
- **OCA CLI User Surface** — ref_oca_cli, ref_oca_status, ref_oca_update, ref_oca_install, ref_openclaw_commands, ref_ocaupdate [EXTRACTED 1.00]
- **Local LLM Inference Options** — doc_local_llm, local_llm_node_llama_cpp, local_llm_ollama, local_llm_ollama_cloud [EXTRACTED 1.00]
- **Root Security Subsystem** — setup_root_sh, setup_root_oca_root_wrapper, setup_root_allowlist, rooted_marker_file, doc_root_support [EXTRACTED 1.00]
- **Environment Configuration System** — setup_env_sh, lib_bashrc_markers, config_env_vars, doc_configuration, config_openclaw_json [EXTRACTED 1.00]
- **Phantom Process Killer Fix Ecosystem (ADB, Wireless ADB, Shizuku)** — concept_phantom_process_killer, concept_adb_wireless, concept_shizuku, disable_ppk_doc, phantom_ppk_doc [EXTRACTED 1.00]
- **RTX Protocol 3-Tier Architecture** — concept_rtx1_infra, concept_rtx2_platform, concept_rtx3_arsenal, concept_rtx_protocol_arch, release_010426 [EXTRACTED 1.00]
- **Android-to-Linux Bridge Stack (Bionic → glibc → Node.js → OpenClaw)** — concept_glibc_runner, concept_nodejs_v24, concept_openclaw_gateway, arch_image, concept_arch_diagram_components [EXTRACTED 1.00]
- **Project Code Quality Standards (ShellCheck, EditorConfig, Markdownlint)** — shellcheckrc, editorconfig, markdownlint_config, concept_shellcheck, github_pr_template [EXTRACTED 0.95]
- **GitHub Contribution Workflow (Issues + PRs)** — github_bug_report, github_feature_request, github_pr_template [EXTRACTED 1.00]
- **Local LLM on Android Stack (node-llama-cpp / Ollama / glibc-runner)** — concept_local_llm, concept_glibc_runner, concept_nodejs_v24, release_100326 [EXTRACTED 1.00]
- **OCA Installer Pipeline (bootstrap → install → verify)** — concept_bootstrap_sh, concept_install_sh, concept_rtx1_infra, concept_rtx2_platform, concept_rtx3_arsenal, installation_doc [EXTRACTED 1.00]

## Communities (46 total, 14 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (39): AI CLI Tools (Claude Code, Gemini, Codex, Qwen), argon2 stub (replaces native module for Termux), Bionic to glibc migration, clawdhub (skill manager), code-server (VS Code in browser), DNS fix (EAI_AGAIN workaround for glibc Node), glibc runtime (aarch64), glibc Node.js wrapper script (+31 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (53): Claude Code CLI (@anthropic-ai/claude-code), Codex CLI (@openai/codex), Gemini CLI (@google/gemini-cli), Qwen Code CLI (Best for Android), Android Bionic libc Constraint, DNS Fix — resolv.conf for Android 12+, glibc-compat.js — Android os.cpus/networkInterfaces Polyfill, glibc-runner (grun) — Glibc Linker Injector (+45 more)

### Community 2 - "Community 2"
Cohesion: 0.08
Nodes (28): BACKUP_SCHEMA_VERSION=1 constant, backup.sh (Backup & Restore Implementation), check-env.sh (RTX1 Environment Checker), clawdhub npm package (skill manager), oca: cmd_uninstall(), install-infra-deps.sh (RTX1 Infrastructure Deps), ask_yn() Prompt Function, BASHRC_MARKER_START / BASHRC_MARKER_END Constants (+20 more)

### Community 3 - "Community 3"
Cohesion: 0.11
Nodes (27): openclaw-apply-patches.sh (Patch Orchestrator), openclaw-build-sharp.sh (Platform Sharp Builder), build-sharp.sh (Sharp WASM/Native Builder), Bun runtime (for opencode-ai install), GitHub mirror fallback (ghfast, ghproxy), glibc-compat.js Android kernel quirk fix, GLIBC_LDSO ld-linux-aarch64.so.1 path, glibc --library-path $PREFIX/glibc/lib execution pattern (+19 more)

### Community 4 - "Community 4"
Cohesion: 0.13
Nodes (28): Architecture Diagram - Android/Termux/OpenClaw Stack, OpenClaw 24/7 Pocket Server Banner, Architecture Diagram: Android Device → Termux → glibc-runner → Node.js → OpenClaw, bootstrap.sh - Entry Point Installer, glibc-runner (ld-linux-aarch64 Wrapper), Homebrew (Linuxbrew) on Android, install.sh - 8-Step Modular Orchestrator, Local LLM Support (node-llama-cpp / Ollama) (+20 more)

### Community 5 - "Community 5"
Cohesion: 0.1
Nodes (27): aarch64 (ARM64) CPU Architecture Requirement, ADB Wireless Debugging (No USB), F-Droid Termux (vs Google Play Termux), Mintlify Documentation Platform, Mintlify documentation site, Phantom Process Killer (Android 12+ Feature), Qwen Code AI CLI (Android-Friendly), Shizuku ADB-level Access Tool (+19 more)

### Community 6 - "Community 6"
Cohesion: 0.11
Nodes (7): Dual-Engine FHS Container (Debian proot), proot-distro (Debian rootfs), oca: cmd_shell(), oca: cmd_start(), cmd_status(), detect_platform(), OCA_VERSION variable

### Community 7 - "Community 7"
Cohesion: 0.12
Nodes (13): CURL_CA_BUNDLE, get_deb_filename(), GIT_CONFIG_NOSYSTEM, GIT_EXEC_PATH, GIT_SSL_CAINFO, GIT_TEMPLATE_DIR, install_deb(), install_with_deps() (+5 more)

### Community 8 - "Community 8"
Cohesion: 0.15
Nodes (12): files, code, document, image, paper, video, graphifyignore_patterns, needs_graph (+4 more)

### Community 9 - "Community 9"
Cohesion: 0.36
Nodes (10): Debian proot-distro rootfs ($PREFIX/var/lib/proot-distro/installed-rootfs/debian), install-chromium.sh (RTX3 Chromium Installer), Dual-Engine code-server wrapper (chroot/proot), install-code-server.sh (RTX3 Code-Server Installer), Dual-Engine brew wrapper (chroot/proot), install-homebrew.sh (RTX3 Homebrew/Proot Installer), Dual-Engine playwright-node wrapper (chroot/proot), install-playwright.sh (RTX3 Playwright Suite Installer) (+2 more)

### Community 10 - "Community 10"
Cohesion: 0.22
Nodes (9): from, to, dark, colors, anchors, background, dark, light (+1 more)

### Community 11 - "Community 11"
Cohesion: 0.43
Nodes (7): _backup_archive_root(), _backup_timestamp(), cmd_backup(), cmd_restore(), _collect_assets(), _detect_backup_platform(), _restore_root_for_platform()

### Community 12 - "Community 12"
Cohesion: 0.33
Nodes (5): CONTAINER, CPATH, TEMP, TMP, TMPDIR

### Community 13 - "Community 13"
Cohesion: 0.33
Nodes (5): CONTAINER, CPATH, TEMP, TMP, TMPDIR

## Knowledge Gaps
- **123 isolated node(s):** `code`, `document`, `paper`, `image`, `video` (+118 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `lib.sh (Shared Function Library)` connect `Community 2` to `Community 1`, `Community 3`?**
  _High betweenness centrality (0.215) - this node is a cross-community bridge._
- **Why does `OpenClaw Platform` connect `Community 0` to `Community 5`, `Community 7`?**
  _High betweenness centrality (0.191) - this node is a cross-community bridge._
- **Why does `verify-install.sh — Installation Verification Test Suite` connect `Community 1` to `Community 2`?**
  _High betweenness centrality (0.113) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Introduction Doc — What is OCA?` (e.g. with `Android Bionic libc Constraint` and `SSH Guide Doc — Remote Access Setup`) actually correct?**
  _`Introduction Doc — What is OCA?` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `code`, `document`, `paper` to the rest of the system?**
  _123 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
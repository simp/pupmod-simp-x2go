# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-x2go` is a SIMP Puppet module that installs and configures the
[X2Go](https://wiki.x2go.org/) remote-desktop / terminal-server software on
Enterprise Linux. X2Go provides NX-based remote graphical sessions; this module
manages the **client** package, the **server** package, the two server
configuration files, and the session-cleanup service.

The module is a small, layered set of four classes:

- **`x2go` (`manifests/init.pp:19-34`)** — public entry class. Consumers
  `include 'x2go'`. It always `include`s `x2go::install`, and when
  `$server == true` it also `include`s `x2go::server`, ordering install before
  server config (`init.pp:29-33`).
- **`x2go::install` (`manifests/install.pp:5-17`)** — private; installs the
  `x2goclient` and/or `x2goserver` packages depending on the `$client` /
  `$server` toggles.
- **`x2go::server` (`manifests/server.pp:95-142`)** — private; writes the two
  server config files from EPP templates and `contain`s the cleanup class.
- **`x2go::server::clean_sessions`
  (`manifests/server/clean_sessions.pp:5-18`)** — manages the
  `x2gocleansessions` service.

All four are **classes** — there are no defined types, and no `types/` or `lib/`
directory (this module ships no custom Puppet types, providers, functions, or
facts).

### Business logic

- **`x2go` (`init.pp:19-34`)** — parameters (`init.pp:20-23`):
  - `$client` (`Boolean`, default `true`) — install the X2Go client.
  - `$server` (`Boolean`, default `false`) — install/configure the X2Go server.
  - `$package_ensure` (`Simplib::PackageEnsure`) — defaults to
    `simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' })`
    (`init.pp:22`). This is the **only** `simp_options` seam in the module.

  It calls `simplib::assert_metadata($module_name)` (`init.pp:25`), then
  `include 'x2go::install'`; the `x2go::server` include and its
  `Class['x2go::install'] ~> Class['x2go::server']` ordering are gated on
  `$server` (`init.pp:29-33`).

- **`x2go::install` (`install.pp:5-17`)** — `assert_private()` at `install.pp:6`.
  - If `$x2go::client` → `package { 'x2goclient': ensure => $x2go::package_ensure }`
    (`install.pp:8-12`).
  - If `$x2go::server` →
    `ensure_packages('x2goserver', { 'ensure' => $x2go::package_ensure })`
    (`install.pp:14-16`). Note the **asymmetry**: the client uses a plain
    `package` resource, the server uses `ensure_packages` (stdlib) so the
    resource can be safely co-declared elsewhere.

- **`x2go::server` (`server.pp:95-142`)** — `assert_private()` at
  `server.pp:102` guards the **entire class at top level** (it is the first
  statement in the class body); the class is only reachable via
  `x2go` with `$server = true`. Parameters (`server.pp:95-101`):
  - `$config` (`Hash[String[1], Hash[String[1], NotUndef]]`, **no default** —
    supplied from module data). A two-level INI structure: outer key = section
    header, inner hash = key/value pairs. Written verbatim into
    `x2goserver.conf`.
  - `$agent_options` (`Hash[String[1], Optional[Scalar]]`, **no default** —
    from module data). Key/value pairs passed to the nxagent; a `~`/undef value
    means a bare flag with no argument.
  - `$config_file` (`Stdlib::AbsolutePath`, default
    `/etc/x2go/x2goserver.conf`).
  - `$agent_config_file` (`Stdlib::AbsolutePath`, default
    `/etc/x2go/x2goagent.options`).
  - `$session_service` (`Boolean`, default `true`) — whether the
    `x2gocleansessions` service should run.

  Logic:
  - **Partial validation** (`server.pp:104-123`): only *known* config keys are
    type-checked; unknown keys pass through untouched. `limit users` /
    `limit groups` must be `Hash[String[1], Integer[0]]`; `security.umask` must
    match `Pattern['^"[0-7]{3,4}"$']` (i.e. a quoted octal string); `log.loglevel`
    must be a `Simplib::PuppetLogLevel`.
  - `file { $config_file }` (`server.pp:125-131`) — `mode 0644`, content from
    `epp("${module_name}/etc/x2go/x2goserver.conf.epp", { config => $config })`.
  - `file { $agent_config_file }` (`server.pp:133-139`) — content from
    `epp(".../x2goagent.options.epp", { options => $agent_options })`.
  - `contain 'x2go::server::clean_sessions'` (`server.pp:141`).

- **`x2go::server::clean_sessions` (`clean_sessions.pp:5-18`)** — toggles the
  `x2gocleansessions` service on `$x2go::server::session_service`: `running` +
  `enable => true` when true, `stopped` + `enable => false` when false. This is
  a **service**, not a cron — the X2Go package ships `x2gocleansessions` as a
  daemon that reaps stale sessions.

## Gotchas / non-obvious details

- **Server config is templated, not merged into an existing file.** The two EPP
  templates (`templates/etc/x2go/x2goserver.conf.epp`,
  `templates/etc/x2go/x2goagent.options.epp`) render the **entire** file from
  the `$config` / `$agent_options` hashes. The docstring warns:
  **"UNMANAGED ENTRIES IN THE CONFIG FILE WILL BE PURGED"** (`server.pp:9`) —
  anything not in Hiera is not preserved.
- **`$config` / `$agent_options` have no manifest defaults** — they are required
  parameters satisfied entirely from module data (`data/common.yaml`). The
  Hiera keys (`x2go::server::config`, `x2go::server::agent_options`) use a
  **deep merge with `knockout_prefix: --`** (`hiera.yaml`/`data/common.yaml:2-10`),
  so a downstream layer can remove a shipped default by prefixing its key with
  `--`. Removing/renaming those data entries breaks server compilation.
- **Shipped agent defaults are security-relevant** (`data/common.yaml:12-20`):
  `-clipboard server` (do not expose the client clipboard to the server),
  `-nolisten tcp`, `-extension XFIXES` (a libxfixes bug workaround), and
  `-audit 4`. The comments say do **not** disable these unless you know what
  you are doing.
- **Validation is intentionally partial** (`server.pp:104-123`): only the four
  known sub-keys are type-checked; everything else is written verbatim. The
  `umask` pattern requires the value to be a *quoted* octal string, e.g.
  `'"0117"'` in Hiera (`server.pp:115`, and the docstring example at
  `server.pp:52-55`).
- **Client vs server declare packages differently** — `package` for the client,
  `ensure_packages` for the server (`install.pp:8-16`). Keep this if you touch
  it: `ensure_packages` avoids duplicate-resource errors when `x2goserver` is
  co-managed elsewhere.
- **This module is client-by-default, server-opt-in** (`init.pp:20-21`):
  `$client` defaults to `true`, `$server` to `false`. Including `x2go` with no
  data installs only the client.
- **X2Go does not work well with compositing window managers** — the init
  docstring recommends the `simp-gnome` module with MATE support
  (`init.pp:3-6`). `simp-gnome` is **not** a `metadata.json` dependency (it
  appears only as a test fixture in `.fixtures.yml`).
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet
  `init.pp:22` consumes `simp_options::package_ensure` via `simplib::lookup`
  (the function is provided by `simp/simplib`). This is the standard SIMP
  pattern; `simp_options` is only a fixture.
- **Acceptance tests exist on disk but are NOT wired into CI** — see the CI
  subsection below.

## Dependencies

Module dependencies (from `metadata.json:13-22`):

- `simp/simplib` `>= 4.9.0 < 5.0.0` — provides `simplib::lookup`,
  `simplib::assert_metadata`, and the `Simplib::PackageEnsure` /
  `Simplib::PuppetLogLevel` data types.
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` — provides `ensure_packages()` and
  `Stdlib::AbsolutePath`.

There are **no optional dependencies** (`metadata.json` has no
`simp.optional_dependencies` block) and the manifests call no
`simplib::assert_optional_dependency`.

Runtime requirement (from `metadata.json:63-68`): `puppet >= 7.0.0 < 9.0.0`.
This is an **older baseline** — the module has **not** yet migrated to OpenVox,
and the CI still uses the older `env: PUPPET_VERSION: '~> 7'` style. When
`metadata.json` switches the `requirements` name to `openvox`, update this line
to match.

Supported OS matrix (from `metadata.json:23-62`) — **note this is an older,
narrower matrix than newer SIMP modules**: CentOS 7/8/9; RedHat 7/8/9;
OracleLinux 7/8/9; Rocky 8/9; AlmaLinux 8/9. (No EL10, and still lists EL7.)

Fixture-only dependencies (from `.fixtures.yml`, present for test compilation
only, not runtime deps): `auditd`, `augeas_core`, `augeasproviders_core`,
`augeasproviders_grub`, `concat`, `dconf`, `gnome`, `inifile`, `logrotate`,
`mate`, `pki`, `polkit`, `rsyslog`, plus the runtime deps `simplib` and
`stdlib`. The module itself is mounted via a `symlinks: x2go` self-reference.

## Repository layout

- `manifests/init.pp` — public `x2go` class (client/server toggles + package
  ensure).
- `manifests/install.pp` — private `x2go::install`; installs
  `x2goclient` / `x2goserver`.
- `manifests/server.pp` — private `x2go::server`; validates config, writes the
  two config files from EPP, contains the cleanup class.
- `manifests/server/clean_sessions.pp` — private `x2go::server::clean_sessions`;
  the `x2gocleansessions` service.
- `templates/etc/x2go/x2goserver.conf.epp` — renders the full INI-style
  `x2goserver.conf` from `$config`.
- `templates/etc/x2go/x2goagent.options.epp` — renders
  `X2GO_NXAGENT_DEFAULT_OPTIONS="..."` by joining `$agent_options`.
- `data/common.yaml` — the default `x2go::server::config` and
  `x2go::server::agent_options`, plus the deep-merge `lookup_options`.
- `hiera.yaml` — module data hierarchy (v5): OS family → common.
- `metadata.json` — deps, OS matrix, Puppet requirement.
- `spec/classes/` — rspec-puppet unit tests.
- `spec/acceptance/suites/default/` — beaker acceptance suites
  (`00_default_spec.rb`, `10_fully_functional_spec.rb`) — **see CI note below**.
- `REFERENCE.md` — generated Puppet Strings reference (driven by the `@param` /
  `@option` docstrings, which are extensive in `server.pp`).

### CI

`.github/workflows/pr_tests.yml` (a **puppetsync**-managed baseline file) runs
only the **six standard non-acceptance jobs** on pull requests:
`puppet-syntax`, `puppet-style` (lint + metadata_lint), `ruby-style` (rubocop,
`continue-on-error`), `file-checks`, `releng-checks` (version/changelog + a
`pdk build`), and `spec-tests` (rspec-puppet on Puppet 7.x/Ruby 2.7 and Puppet
8.x/Ruby 3.2). It uses the older global `env: PUPPET_VERSION: '~> 7'`
(`pr_tests.yml:29-30`).

- **There is NO acceptance job.** The beaker suites
  (`spec/acceptance/suites/default/00_default_spec.rb` and
  `10_fully_functional_spec.rb`) and the **3** nodesets under
  `spec/acceptance/nodesets/` (`centos-combined-x64.yml`, `default.yml`,
  `oel-combined-x64.yml`) exist on disk but are **not** referenced anywhere in
  `pr_tests.yml`. If you change server behavior, the acceptance suites will not
  run in CI — run them locally (see commands below).

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Puppet lint + metadata lint (matches the puppet-style CI job)
bundle exec rake lint
bundle exec rake metadata_lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md

# Run a beaker acceptance suite locally (NOT run in CI)
bundle exec rake beaker:suites[default]
```

Relevant gem pins (from `Gemfile`): `rubocop ~> 1.88.0` (`Gemfile:16`),
`puppetlabs_spec_helper ~> 8.0.0` (`Gemfile:30`), `simp-rake-helpers ~> 5.24.0`
(`Gemfile:36`), `simp-beaker-helpers ~> 2.0.0` (`Gemfile:52`). The puppet gem is
pulled in **only** via `gem 'puppet', puppet_version` (`Gemfile:29`), where
`puppet_version` defaults to `['>= 7', '< 9']` (`Gemfile:23`).
`spec/spec_helper.rb:11` is the standard
`require 'puppetlabs_spec_helper/module_spec_helper'`.

## Conventions

- Preserve the `@summary` / `@param` / `@option` puppet-strings docstrings —
  `server.pp` in particular carries detailed `@option config` and
  `@param agent_options` docs with Hiera examples that drive `REFERENCE.md`.
  Regenerate `REFERENCE.md` after changing docs or parameters.
- Keep the server defaults (`x2go::server::config`,
  `x2go::server::agent_options`) in `data/common.yaml`, not hard-coded in the
  manifest — and preserve the deep-merge `knockout_prefix: --` `lookup_options`.
- Keep server config validation **partial and permissive**: type-check only the
  documented sub-keys, let unknown keys through (`server.pp:104-123`).
- Route SIMP package-state through
  `simplib::lookup('simp_options::package_ensure', { 'default_value' => ... })`
  rather than assuming `simp_options` is included.
- Keep private classes `assert_private()`'d (`install.pp:6`, `server.pp:102`);
  only `x2go` is the public entry point.
- `Gemfile`, `spec/spec_helper.rb`, and `.github/workflows/pr_tests.yml` carry a
  **puppetsync** notice — they are baseline-managed and the next sync overwrites
  local edits. Push changes to those files upstream to the baseline, not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used in the manifests.

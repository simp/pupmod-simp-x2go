# Install and configure the x2go server
#
# @param config
#   A Hash of INI settings targeted at the x2goserver.conf file
#
#   Options not defined here will simply be added to the configuration file
#   without validation.
#
#   **UNMANAGED ENTRIES IN THE CONFIG FILE WILL BE PURGED**
#
#   Options take the following form:
#
#   ```
#   Hash[
#     Hash[
#       String[1], # This is the INI header
#       Hash[
#         String[1], # This is an item key
#         String[1], # This is an item value
#       ]
#     ]
#   ]
#   ```
#   @see x2goserver.conf(5)
#   @see data/common.yml
#
# @option config [Hash] limit users
#   A Hash of users specifying the maximum number of simultaneous sessions
#   allowed in an X2Go server farm
#
#   * To avoid resource explosion, it is highly recommended that you restrict
#     by group if possible
#
#   @example Specify user limits in Hiera
#     x2go::server::config:
#       limit users:
#         'user1': 2
#         'user2': 4
#
# @option config [Hash] limit groups
#   A Hash of groups specifying the maximum number of simultaneous sessions
#   allowed in an X2Go server farm
#
#   @example Specify group limits in Hiera
#     x2go::server::config:
#       limit_groups:
#         'group1': 20
#
# @option config [Hash] security
#   A key/value set of strings that manage security settings
#
#   @example Specify the SSHFS umask in Hiera
#     x2go::server::config:
#       security:
#         umask: '"0117"'
#
# @option config [Hash] log
#   A key/value set of strings that manage log settings
#
#   @example Specify the log level in Hiera
#     x2go::server::config:
#       log:
#         loglevel: 'debug'
#
# @param agent_options
#   The options to add to the x2goagent.options file
#
#   * Options are provided in a key/value pair hash
#   * You **MUST** provide the flag for the option if one is present
#   * No validation is done on provided options
#   * Options that do not take an argument should have their value set to Undef
#     or `~` in Hiera
#
#   @example Setting options in Hiera
#     x2go::agent_options:
#       "+bs": ~
#       "-lf": 1024
#       "nologo": ~
#
#   @see nxagent -h
#   @see data/common.yaml
#
# @param config_file
#   The location of the main server configuration file
#
# @param agent_config_file
#   The location of the agent configuration file
#
# @param session_service
#   Enable the x2gocleansessions service to enable full accounting and resuming
#   of sessions
#
# @author https://github.com/simp/pupmod-simp-x2go/graphs/contributors
#
class x2go::server (
  Hash[String[1], Hash[String[1], NotUndef]] $config,
  Hash[String[1], Optional[Scalar]]          $agent_options,
  Stdlib::AbsolutePath                       $config_file       = '/etc/x2go/x2goserver.conf',
  Stdlib::AbsolutePath                       $agent_config_file = '/etc/x2go/x2goagent.options',
  Boolean                                    $session_service   = true
) {
  assert_private()

  # Validate known parameters and let unknown ones through
  if $config['limit users'] {
    assert_type(Hash[String[1], Integer[0]], $config['limit users'])
  }

  if $config['limit groups'] {
    assert_type(Hash[String[1], Integer[0]], $config['limit groups'])
  }

  if $config['security'] {
    if $config['security']['umask'] {
      assert_type(Pattern['^"[0-7]{3,4}"$'], $config['security']['umask'])
    }
  }

  if $config['log'] {
    if $config['log']['loglevel'] {
      assert_type(Simplib::PuppetLogLevel, $config['log']['loglevel'])
    }
  }

  file { $config_file:
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp("${module_name}/etc/x2go/x2goserver.conf.epp", { config => $config })
  }

  file { $agent_config_file:
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp("${module_name}/etc/x2go/x2goagent.options.epp", { options => $agent_options})
  }

  contain 'x2go::server::clean_sessions'
}

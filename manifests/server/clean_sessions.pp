# Manage the x2gocleansessions service
#
# @author https://github.com/simp/pupmod-simp-x2go/graphs/contributors
#
class x2go::server::clean_sessions {
  if $x2go::server::session_service {
    service { 'x2gocleansessions':
      ensure => 'running',
      enable => true
    }
  }
  else {
    service { 'x2gocleansessions':
      ensure => 'stopped',
      enable => false
    }
  }
}

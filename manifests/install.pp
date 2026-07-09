# == Class x2go::install
#
# This class is called from x2go for install.
#
class x2go::install {
  assert_private()

  if $x2go::client {
    package { 'x2goclient':
      ensure => $x2go::package_ensure
    }
  }

  if $x2go::server {
    ensure_packages('x2goserver', { 'ensure' => $x2go::package_ensure })
  }
}

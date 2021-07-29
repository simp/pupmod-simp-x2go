# Install and configure the x2go client and server components
#
# x2go does not work well with compositing window managers.
#
# It is suggested that you use the `simp-gnome` module and enable MATE support
# for use with x2go.
#
# @param client
#   Whether or not the system is a x2go client
#
# @param server
#   Whether or not the system is a x2go server
#
# @param package_ensure
#   The state that packages managed by this module should be in
#
# @author https://github.com/simp/pupmod-simp-x2go/graphs/contributors
#
class x2go (
  Boolean                $client         = true,
  Boolean                $server         = false,
  Simplib::PackageEnsure $package_ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' })
) {

  simplib::assert_metadata($module_name)

  include 'x2go::install'

  if $server {
    include 'x2go::server'

    Class['x2go::install'] ~> Class['x2go::server']
  }
}

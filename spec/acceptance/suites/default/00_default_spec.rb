require 'spec_helper_acceptance'

test_name 'x2go class'

describe 'x2go class' do
  let(:manifest) do
    <<-EOS
      class { 'x2go': }
    EOS
  end

  let(:server_manifest) do
    <<-EOS
      class { 'x2go': server => true }
    EOS
  end

  hosts.each do |host|
    # Exercise noop from a clean (uninstalled) state: on a fresh node the Sicura
    # console previews the module with `puppet apply --noop`, which must not error
    # even though nothing x2go manages exists yet. Real idempotence is covered
    # by the applies below. A post-convergence noop check is deliberately omitted:
    # `puppet apply --noop --detailed-exitcodes` always exits 0, so it could never
    # fail and would test nothing.
    context 'in noop mode from a clean state' do
      # Setup, not an assertion: as before(:context) a failure errors this context
      # rather than aborting the whole suite under .rspec's --fail-fast. `puppet
      # resource` exits 0 whether it removes the package or finds it already absent
      # (no --detailed-exitcodes), so no acceptable_exit_codes override is needed.
      before(:context) do
        on(host, 'puppet resource package x2goclient ensure=absent')
      end

      it 'applies without errors in noop mode' do
        apply_manifest_on(host, manifest, catch_failures: true, noop: true)
      end
    end

    context "on #{host}" do
      it 'enables additional OS repos as needed' do
        # The x2go packages live in EPEL, and several of their
        # dependencies (e.g. perl(File::BaseDir) for x2goserver) live in the
        # CodeReady Builder / PowerTools repo.  Full distro images enable CRB
        # by default, but minimal container images do not, so enable both
        # explicitly here.
        enable_epel_on(host)

        os_info = fact_on(host, 'os')
        os_maj_rel = os_info['release']['major']

        case os_info['name']
        when 'RedHat', 'CentOS', 'AlmaLinux', 'Rocky'
          host.install_package('dnf-plugins-core')
          # repo name varies across majors (powertools on EL8, crb on EL9+)
          on(host, 'dnf config-manager --set-enabled crb ' \
                   '|| dnf config-manager --set-enabled powertools ' \
                   '|| dnf config-manager --set-enabled PowerTools',
             accept_all_exit_codes: true)
        when 'OracleLinux'
          host.install_package('dnf-plugins-core')
          on(host, "dnf config-manager --set-enabled ol#{os_maj_rel}_codeready_builder " \
                   "|| dnf config-manager --set-enabled ol#{os_maj_rel}_distro_builder " \
                   "|| dnf config-manager --set-enabled ol#{os_maj_rel}_addons",
             accept_all_exit_codes: true)
        end
      end

      it 'works with no errors' do
        on(host, 'rpm -qa > /tmp/rpms')
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it 'has the client installed' do
        expect(host.check_for_package('x2goclient')).to be true
      end
    end

    context 'as a server' do
      it 'works with no errors' do
        apply_manifest_on(host, server_manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, server_manifest, catch_changes: true)
      end

      it 'has the client installed' do
        expect(host.check_for_package('x2goserver')).to be true
      end
    end
  end
end

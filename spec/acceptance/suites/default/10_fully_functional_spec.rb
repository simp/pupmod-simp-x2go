require 'spec_helper_acceptance'

test_name 'x2go with MATE and GNOME'

describe 'x2go with MATE and GNOME' do
  hosts.each do |host|
    let(:manifest) do
      updated_manifest = <<-EOS
        include 'gnome'
        class { 'x2go': server => true }
      EOS

      if host.host_hash[:roles].include?('mate_enabled')
        updated_manifest << "\ninclude 'mate'"
      end

      updated_manifest
    end

    context "on #{host}" do
      # x2goserver is not packaged in EPEL 10 yet (upstream packaging gap,
      # not a container limitation), so skip there.
      let(:x2go_in_epel) { fact_on(host, 'os.release.major').to_i < 10 }

      it 'works with no errors' do
        skip('x2go is not packaged in EPEL 10') unless x2go_in_epel
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        skip('x2go is not packaged in EPEL 10') unless x2go_in_epel
        apply_manifest_on(host, manifest, catch_changes: true)
        on(host, 'rpm -qa > /tmp/newrpms')
      end
    end
  end
end

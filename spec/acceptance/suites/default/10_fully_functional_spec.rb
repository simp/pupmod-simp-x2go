require 'spec_helper_acceptance'

test_name 'x2go with MATE and GNOME'

describe 'x2go with MATE and GNOME' do
  hosts.each do |host|
    let(:manifest) do
      _manifest = <<-EOS
        include 'gnome'
        class { 'x2go': server => true }
      EOS

      if host.host_hash[:roles].include?('mate_enabled')
        _manifest << "\ninclude 'mate'"
      end

      _manifest
    end

    context "on #{host}" do
      it 'works with no errors' do
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
        on(host, 'rpm -qa > /tmp/newrpms')
      end
    end
  end
end

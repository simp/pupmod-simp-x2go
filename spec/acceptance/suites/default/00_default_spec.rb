require 'spec_helper_acceptance'

test_name 'x2go class'

describe 'x2go class' do
  let(:manifest) {
    <<-EOS
      class { 'x2go': }
    EOS
  }

  let(:server_manifest) {
    <<-EOS
      class { 'x2go': server => true }
    EOS
  }

  hosts.each do |host|
    context "on #{host}" do
      it 'should enable additional OS repos as needed' do
        result = on(hosts[0], 'cat /etc/oracle-release', :accept_all_exit_codes => true)
        if result.exit_code == 0  and host.name == 'el7'
          # problem with OEL 7 repos...need another repo enabled in order
          # for all the x2go dependencies to resolve
          host.install_package('yum-utils')
          on(hosts, 'yum-config-manager --enable ol7_optional_latest')
          on(hosts, 'yum-config-manager --enable ol7_developer_EPEL')
        end
      end

      it 'should work with no errors' do
        on(host, 'rpm -qa > /tmp/rpms')
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, :catch_changes => true)
      end

      it 'should have the client installed' do
        expect(host.check_for_package('x2goclient')).to be true
      end
    end

    context 'as a server' do
      it 'should work with no errors' do
        apply_manifest_on(host, server_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, server_manifest, :catch_changes => true)
      end

      it 'should have the client installed' do
        expect(host.check_for_package('x2goserver')).to be true
      end
    end
  end
end

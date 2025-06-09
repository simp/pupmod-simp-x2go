require 'spec_helper'

describe 'x2go' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('x2go') }
    it { is_expected.to contain_class('x2go::install') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts
        end

        it_behaves_like 'a structured module'

        it { is_expected.to contain_package('x2goclient') }

        context 'when acting as a server' do
          let(:params) { { server: true } }

          it_behaves_like 'a structured module'

          it { is_expected.to contain_package('x2goserver') }
          it { is_expected.to contain_class('x2go::install').that_notifies('Class[x2go::server]') }
          it { is_expected.to contain_file('/etc/x2go/x2goserver.conf').with_content(%r{\[log\]\nloglevel=notice}) }
          it { is_expected.to contain_file('/etc/x2go/x2goagent.options').that_requires('Class[x2go::install]') }

          it { is_expected.to contain_service('x2gocleansessions') }

          it {
            is_expected.to contain_file('/etc/x2go/x2goagent.options').with_content(
              %r{^X2GO_NXAGENT_DEFAULT_OPTIONS="-extension XFIXES -nolisten tcp -clipboard server -audit 4"$},
            )
          }
        end
      end
    end
  end
end

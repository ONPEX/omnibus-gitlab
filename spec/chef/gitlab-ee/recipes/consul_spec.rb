require 'chef_helper'

describe 'consul' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab-ee::default') }
  let(:consul_conf) { '/var/opt/gitlab/consul/config.json' }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'disabled by default' do
    it 'includes the disable recipe' do
      expect(chef_run).to include_recipe('consul::disable')
    end
  end

  describe 'consul::disable' do
    it_behaves_like 'disabled runit service', 'consul'
  end

  context 'when enabled' do
    before do
      stub_gitlab_rb(
        consul: {
          enable: true,
          config_dir: '/fake/config.d',
          data_dir: '/fake/data',
          services: %w(postgresql)
        }
      )
    end

    it 'includes the enable recipe' do
      expect(chef_run).to include_recipe('consul::enable')
    end

    describe 'consul::enable' do
      it_behaves_like 'enabled runit service', 'consul', 'gitlab-consul', 'gitlab-consul'

      it 'includes the postgresql_service recipe' do
        expect(chef_run).to include_recipe('consul::service_postgresql')
      end

      it 'only enables the agent by default' do
        expect(chef_run).to render_file(consul_conf).with_content { |content|
          expect(content).to match(%r{"server":false})
        }
      end

      it 'does not include nil values in its configuration' do
        expect(chef_run).to render_file(consul_conf).with_content { |content|
          expect(content).not_to match(%r{"encryption":})
        }
      end

      it 'does not include server default values in its configuration' do
        expect(chef_run).to render_file(consul_conf).with_content { |content|
          expect(content).not_to match(%r{"bootstrap_expect":3})
        }
      end

      it 'creates the necessary directories' do
        expect(chef_run).to create_directory('/fake/config.d')
        expect(chef_run).to create_directory('/fake/data')
        expect(chef_run).to create_directory('/var/log/gitlab/consul')
      end
    end

    context 'server enabled' do
      before do
        stub_gitlab_rb(
          consul: {
            enable: true,
            configuration: {
              server: true
            }
          }
        )
      end

      it 'enables the server functionality' do
        expect(chef_run.node['consul']['configuration']['server']).to eq true
        expect(chef_run).to render_file(consul_conf).with_content { |content|
          expect(content).to match(%r{"server":true})
          expect(content).to match(%r{"bootstrap_expect":3})
        }
      end

      it 'sets client_addr when it has not been set' do
        expect(chef_run).to render_file(consul_conf).with_content(%r{"client_addr":"10.0.0.2"})
      end
    end
  end

  describe 'consul::service_postgresql' do
    let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab-ee::default') }

    before do
      allow(Gitlab).to receive(:[]).and_call_original
      stub_gitlab_rb(
        consul: {
          enable: true,
          services: %w(postgresql)
        }
      )
    end

    it 'creates the consul system user' do
      expect(chef_run).to create_user 'gitlab-consul'
    end
  end

  describe 'consul::watchers' do
    let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab-ee::default') }
    let(:watcher_conf) { '/var/opt/gitlab/consul/config.d/watcher_postgresql.json' }
    let(:watcher_check) { '/var/opt/gitlab/consul/scripts/failover_pgbouncer' }

    before do
      allow(Gitlab).to receive(:[]).and_call_original
      stub_gitlab_rb(
        consul: {
          enable: true,
          watchers: %w(
            postgresql
          )
        }
      )
    end

    it 'includes the watcher recipe' do
      expect(chef_run).to include_recipe('consul::watchers')
    end

    it 'creates the watcher config file' do
      rendered = {
        'watches' => [
          {
            'type' => 'service',
            'service' => 'postgresql',
            'handler' => watcher_check
          }
        ]
      }

      expect(chef_run).to render_file(watcher_conf).with_content { |content|
        expect(JSON.parse(content)).to eq(rendered)
      }
    end

    it 'creates the watcher handler file' do
      expect(chef_run).to render_file(watcher_check)
    end
  end
end

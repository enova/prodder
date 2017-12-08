require 'spec_helper'

RSpec.describe Prodder::Config, 'linting' do
  let(:valid_config) { YAML.load Prodder::Config.example_contents }

  def config_without(path)
    keys = path.split('/')
    hash = valid_config
    hash = hash[keys.shift] until keys.size == 1
    hash.delete keys.first
    valid_config
  end

  def errors_for(hash)
    Prodder::Config.new(hash).lint
  end

  specify 'the example contents pass lint checks' do
    hash = YAML.load(Prodder::Config.example_contents)
    expect { Prodder::Config.new(hash).lint! }.not_to raise_error
  end

  context 'missing required key:' do
    %w[structure_file
       seed_file

       db
       db/name
       db/host
       db/user

       git
       git/origin
       git/author
    ].each do |path|
      specify path do
        expect(errors_for(config_without "blog/#{path}")).to eq ["Missing required configuration key: blog/#{path}"]
      end
    end
  end

  context 'optional keys:' do
    specify 'db/password' do
      expect(errors_for(config_without 'blog/db/password')).to be_empty
    end
  end

  context '#lint!' do
    it 'raises a LintError with the list of errors' do
      config = Prodder::Config.new(config_without 'blog/db/name')
      expect {
        config.lint!
      }.to raise_error(Prodder::Config::LintError) { |ex|
        expect(ex.errors).to eq ['Missing required configuration key: blog/db/name']
      }
    end

    it 'returns an empty collection if there are no errors' do
      expect(Prodder::Config.new(valid_config).lint!).to eq []
    end
  end
end

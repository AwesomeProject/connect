require 'spec_helper'
require 'suse/connect/cli'

describe SUSE::Connect::Cli do

  subject { SUSE::Connect::Cli }

  let(:default_logger) { SUSE::Connect::GlobalLogger.instance.log }
  let(:string_logger) { ::Logger.new(StringIO.new) }
  let(:cli) { subject.new({}) }
  let(:config_file) { File.expand_path File.join(File.dirname(__FILE__), '../fixtures/SUSEConnect') }

  before do
    Zypper.stub(:base_product => {})
    allow_any_instance_of(subject).to receive(:exit)
    subject.any_instance.stub(:puts => true)
    SUSE::Connect::GlobalLogger.instance.log = string_logger
  end

  after do
    SUSE::Connect::GlobalLogger.instance.log = default_logger
  end

  describe '#execute!' do

    context 'server errors' do

      let(:cli) { subject.new(%w{-r 123}) }

      it 'should produce log output if ApiError encountered' do
        expect(string_logger).to receive(:fatal).with("Error: SCC returned 'test' (222)")
        response = Net::HTTPResponse.new('1.1', 222, 'Test')
        expect(response).to receive(:body).and_return('localized_error' => 'test')
        allow_any_instance_of(Client).to receive(:register!).and_raise ApiError.new(response)
        cli.execute!
      end

      context 'system has proper credentials file' do
        it 'should suggest re-registration if ApiError 401 encountered' do
          response = Net::HTTPResponse.new('1.1', 401, 'Test')
          allow(System).to receive(:credentials?).and_return true
          expect_any_instance_of(Client).to receive(:register!).and_raise ApiError.new(response)
          expect(string_logger).to receive(:fatal).with(match(/Error: Not authorised./))
          cli.execute!
        end
      end

      context 'system has no proper credentials file' do
        it 'should suggest re-registration if ApiError 401 encountered' do
          response = Net::HTTPResponse.new('1.1', 401, 'Test')
          allow(System).to receive(:credentials?).and_return false
          expect_any_instance_of(Client).to receive(:register!).and_raise ApiError.new(response)
          expect(string_logger).to receive(:fatal).with('Provided registration code is not recognized by registration server.')
          cli.execute!
        end
      end

      it 'should produce log output if connection refused' do
        expect(string_logger).to receive(:fatal).with('Error: Connection refused by server https://scc.suse.com')
        allow_any_instance_of(Client).to receive(:register!).and_raise Errno::ECONNREFUSED
        cli.execute!
      end

      it 'should produce log output if json parse error encountered' do
        expect(string_logger).to receive(:fatal).with('Error: Cannot parse response from server')
        allow_any_instance_of(Client).to receive(:register!).and_raise JSON::ParserError
        cli.execute!
      end

      it 'should produce log output if EACCES encountered' do
        expect(string_logger).to receive(:fatal).with('Error: Access error - Permission denied')
        allow_any_instance_of(Client).to receive(:register!).and_raise Errno::EACCES
        cli.execute!
      end

      it 'should produce log output if FileError encountered' do
        expect(string_logger).to receive(:fatal).with('FileError: \'test\'')
        allow_any_instance_of(Client).to receive(:register!).and_raise(FileError, 'test')
        cli.execute!
      end

    end

    context 'zypper error' do

      let(:cli) { subject.new(%w{-r 456}) }

      it 'should produce log output if zypper errors' do
        expect(string_logger).to receive(:fatal).with('Error: zypper returned (666) with \'<stream><error>zypper down</error></stream>\'')
        allow_any_instance_of(Client).to receive(:register!).and_raise ZypperError.new(666, '<stream><error>zypper down</error></stream>')
        cli.execute!
      end

    end

    context 'parameter dependencies' do

      it 'requires no other parameters on --status' do
        cli = subject.new(%w{--status})
        expect_any_instance_of(Status).to receive(:print_product_statuses)
        cli.execute!
      end

      it 'requires either --token or --url (regcode-less SMT registration)' do
        expect(string_logger).to receive(:error)
          .with('Please set the regcode parameter to register against SCC, or the url parameter to register against SMT')
        cli.execute!
      end

      it 'requires either --token or --url (regcode-less SMT registration) but respects config attributes' do
        config = SUSE::Connect::Config.new(config_file)
        config.url = 'https://smt.server'
        allow(SUSE::Connect::Config).to receive(:new).and_return(config)

        allow_any_instance_of(Client).to receive(:register!).and_return true

        expect(string_logger).not_to receive(:error)
          .with('Please set the regcode parameter to register against SCC, or the url parameter to register against SMT')
        cli.execute!
      end

      it '--instance-data requires --url' do
        cli = subject.new(%w{--instance-data /tmp/test})
        expect(string_logger).to receive(:error)
          .with('Please use --instance-data only in combination with --url pointing to your SMT server')
        cli.execute!
      end

      it '--instance-data is mutually exclusive with --token' do
        cli = subject.new(%w{-r 123 --instance-data /tmp/test --url test})
        expect(string_logger).to receive(:error)
          .with('Please use either --token or --instance-data')
        cli.execute!
      end

      it '--url implies --write-config' do
        cli = subject.new(%w{-r 123 --url http://foo.test.com})
        expect(cli.config.write_config).to eq true
        allow_any_instance_of(SUSE::Connect::Client).to receive(:register!)
        expect_any_instance_of(SUSE::Connect::Config).to receive(:write!)
        cli.execute!
      end

    end

    context 'status subcommand' do

      it '--status calls json_product_status' do
        cli = subject.new(%w{--status})
        expect_any_instance_of(Client).to_not receive(:register!)
        expect_any_instance_of(Status).to receive(:json_product_status)
        cli.execute!
      end

      it '--status-text calls text_product_status' do
        cli = subject.new(%w{--status-text})
        expect_any_instance_of(Client).to_not receive(:register!)
        expect_any_instance_of(Status).to receive(:text_product_status)
        cli.execute!
      end

    end

    describe 'config write' do

      it 'writes config if appropriate cli param been passed' do
        cli = subject.new(%w{--write-config --status})
        expect_any_instance_of(SUSE::Connect::Config).to receive(:write!)
        allow_any_instance_of(Status).to receive(:print_product_statuses)
        cli.execute!
      end

    end

  end

  describe '?extract_options' do

    it 'sets token options' do
      argv = %w{-r matoken}
      cli = subject.new(argv)
      expect(cli.options[:token]).to eq 'matoken'
    end

    it 'sets product options' do
      argv = %w{--product sles/12/i386}
      cli = subject.new(argv)
      expect(cli.options[:product]).to eq Remote::Product.new(:identifier => 'sles', :version => '12', :arch => 'i386')
    end

    it 'sets token options' do
      argv = %w{--regcode matoken}
      cli = subject.new(argv)
      expect(cli.options[:token]).to eq 'matoken'
    end

    it 'sets email options' do
      argv = %w{--email me@hotmail.com}
      cli = subject.new(argv)
      expect(cli.options[:email]).to eq 'me@hotmail.com'
    end

    it 'sets url options' do
      argv = %w{--url test}
      cli = subject.new(argv)
      expect(cli.options[:url]).to eq 'test'
    end

    it 'puts version on version flag' do
      argv = %w{--version}
      expect_any_instance_of(subject).to receive(:puts).with(VERSION)
      subject.new(argv)
    end

    it 'output help on help flag' do
      argv = %w{--help}
      expect_any_instance_of(subject).to receive(:puts)
      subject.new(argv)
    end

    it 'sets verbose options' do
      argv = %w{--debug}
      cli = subject.new(argv)
      expect(cli.options[:debug]).to be true
    end

    it 'sets root option' do
      argv = %w{--root /path/to/root}
      subject.new(argv)
      expect(SUSE::Connect::System.filesystem_root).to eq '/path/to/root'
      SUSE::Connect::System.filesystem_root = nil
    end

    it 'requests status sub-command' do
      argv = %w{--status}
      expect(subject.new(argv).options[:status]).to be true
    end

    it 'sets write_config option' do
      argv = %w{--write-config}
      cli = subject.new(argv)
      expect(cli.options[:write_config]).to be true
    end

  end

  describe 'errors on invalid options format' do

    it 'error on invalid product options format' do
      expect(string_logger).to receive(:error).with(/Please provide the product identifier in this format/)
      argv = %w{--product sles}
      subject.new(argv)
    end

  end

  describe '?check_if_param' do
    it 'will exit with message if opt is nil' do
      expect_any_instance_of(subject).to receive(:exit)
      expect(string_logger).to receive(:error).with('Kaboom')
      subject.new({}).send(:check_if_param, nil, 'Kaboom')
    end
  end

  describe 'reads environment variables' do
    it 'sets language header based on LANG' do
      # is ENV global?
      ENV['LANG'] = 'de'
      cli = subject.new([])
      expect(cli.options[:language]).to eq 'de'
    end

  end

end

# frozen_string_literal: true

describe RuboCop::Options, :isolated_environment do
  include FileHelper

  subject(:options) { described_class.new }

  before do
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  after do
    $stdout = STDOUT
    $stderr = STDERR
  end

  def abs(path)
    File.expand_path(path)
  end

  describe 'option' do
    describe '-h/--help' do
      it 'exits cleanly' do
        expect { options.parse ['-h'] }.to exit_with_code(0)
        expect { options.parse ['--help'] }.to exit_with_code(0)
      end

      it 'shows help text' do
        begin
          options.parse(['--help'])
        rescue SystemExit # rubocop:disable Lint/HandleExceptions
        end

        expected_help = <<-OUTPUT.strip_indent
          Usage: rubocop [options] [file1, file2, ...]
              -L, --list-target-files          List all files RuboCop will inspect.
                  --except [COP1,COP2,...]     Disable the given cop(s).
                  --only [COP1,COP2,...]       Run only the given cop(s).
                  --only-guide-cops            Run only cops for rules that link to a
                                               style guide.
              -c, --config FILE                Specify configuration file.
                  --auto-gen-config            Generate a configuration file acting as a
                                               TODO list.
                  --exclude-limit COUNT        Used together with --auto-gen-config to
                                               set the limit for how many Exclude
                                               properties to generate. Default is 15.
                  --force-exclusion            Force excluding files specified in the
                                               configuration `Exclude` even if they are
                                               explicitly passed as arguments.
                  --ignore-parent-exclusion    Prevent from inheriting AllCops/Exclude from
                                               parent folders.
                  --force-default-config       Use default configuration even if configuration
                                               files are present in the directory tree.
                  --no-offense-counts          Do not include offense counts in configuration
                                               file generated by --auto-gen-config.
              -f, --format FORMATTER           Choose an output formatter. This option
                                               can be specified multiple times to enable
                                               multiple formatters at the same time.
                                                 [p]rogress (default)
                                                 [s]imple
                                                 [c]lang
                                                 [d]isabled cops via inline comments
                                                 [fu]ubar
                                                 [e]macs
                                                 [j]son
                                                 [h]tml
                                                 [fi]les
                                                 [o]ffenses
                                                 [w]orst
                                                 [t]ap
                                                 custom formatter class name
              -o, --out FILE                   Write output to a file instead of STDOUT.
                                               This option applies to the previously
                                               specified --format, or the default format
                                               if no format is specified.
              -r, --require FILE               Require Ruby file.
                  --fail-level SEVERITY        Minimum severity (A/R/C/W/E/F) for exit
                                               with error code.
                  --show-cops [COP1,COP2,...]  Shows the given cops, or all cops by
                                               default, and their configurations for the
                                               current directory.
              -F, --fail-fast                  Inspect files in order of modification
                                               time and stop after the first file
                                               containing offenses.
              -C, --cache FLAG                 Use result caching (FLAG=true) or don't
                                               (FLAG=false), default determined by
                                               configuration parameter AllCops: UseCache.
              -d, --debug                      Display debug info.
              -D, --display-cop-names          Display cop names in offense messages.
              -E, --extra-details              Display extra details in offense messages.
              -S, --display-style-guide        Display style guide URLs in offense messages.
              -R, --rails                      Run extra Rails cops.
              -l, --lint                       Run only lint cops.
              -a, --auto-correct               Auto-correct offenses.
                  --[no-]color                 Force color output on or off.
              -v, --version                    Display version.
              -V, --verbose-version            Display verbose version.
              -P, --parallel                   Use available CPUs to execute inspection in
                                               parallel.
              -s, --stdin FILE                 Pipe source from STDIN, using FILE in offense
                                               reports. This is useful for editor integration.
        OUTPUT

        expect($stdout.string).to eq(expected_help)
      end

      it 'lists all builtin formatters' do
        begin
          options.parse(['--help'])
        rescue SystemExit # rubocop:disable Lint/HandleExceptions
        end

        option_sections = $stdout.string.lines.slice_before(/^\s*-/)

        format_section = option_sections.find do |lines|
          lines.first =~ /^\s*-f/
        end

        formatter_keys = format_section.reduce([]) do |keys, line|
          match = line.match(/^[ ]{39}(\[[a-z\]]+)/)
          next keys unless match
          keys << match.captures.first.gsub(/\[|\]/, '')
        end.sort

        expected_formatter_keys =
          RuboCop::Formatter::FormatterSet::BUILTIN_FORMATTERS_FOR_KEYS
          .keys.sort

        expect(formatter_keys).to eq(expected_formatter_keys)
      end
    end

    describe 'incompatible cli options' do
      it 'rejects using -v with -V' do
        msg = 'Incompatible cli options: [:version, :verbose_version]'
        expect { options.parse %w[-vV] }
          .to raise_error(ArgumentError, msg)
      end

      it 'rejects using -v with --show-cops' do
        msg = 'Incompatible cli options: [:version, :show_cops]'
        expect { options.parse %w[-v --show-cops] }
          .to raise_error(ArgumentError, msg)
      end

      it 'rejects using -V with --show-cops' do
        msg = 'Incompatible cli options: [:verbose_version, :show_cops]'
        expect { options.parse %w[-V --show-cops] }
          .to raise_error(ArgumentError, msg)
      end

      it 'mentions all incompatible options when more than two are used' do
        msg = 'Incompatible cli options: [:version, :verbose_version,' \
              ' :show_cops]'
        expect { options.parse %w[-vV --show-cops] }
          .to raise_error(ArgumentError, msg)
      end
    end

    describe '--parallel' do
      context 'combined with --cache false' do
        it 'fails with an error message' do
          msg = ['-P/--parallel uses caching to speed up execution, so ',
                 'combining with --cache false is not allowed.'].join
          expect { options.parse %w[--parallel --cache false] }
            .to raise_error(ArgumentError, msg)
        end
      end

      context 'combined with --auto-correct' do
        it 'fails with an error message' do
          msg = '-P/--parallel can not be combined with --auto-correct.'
          expect { options.parse %w[--parallel --auto-correct] }
            .to raise_error(ArgumentError, msg)
        end
      end

      context 'combined with --auto-gen-config' do
        it 'fails with an error message' do
          msg = '-P/--parallel uses caching to speed up execution, while ' \
                '--auto-gen-config needs a non-cached run, so they cannot be ' \
                'combined.'
          expect { options.parse %w[--parallel --auto-gen-config] }
            .to raise_error(ArgumentError, msg)
        end
      end

      context 'combined with --fail-fast' do
        it 'fails with an error message' do
          msg = '-P/--parallel can not be combined with -F/--fail-fast.'
          expect { options.parse %w[--parallel --fail-fast] }
            .to raise_error(ArgumentError, msg)
        end
      end
    end

    describe '--fail-level' do
      it 'accepts full severity names' do
        %w[refactor convention warning error fatal].each do |severity|
          expect { options.parse(['--fail-level', severity]) }
            .not_to raise_error
        end
      end

      it 'accepts severity initial letters' do
        %w[R C W E F].each do |severity|
          expect { options.parse(['--fail-level', severity]) }
            .not_to raise_error
        end
      end

      it 'accepts the "fake" severities A/autocorrect' do
        %w[autocorrect A].each do |severity|
          expect { options.parse(['--fail-level', severity]) }
            .not_to raise_error
        end
      end
    end

    describe '--require' do
      let(:required_file_path) { './path/to/required_file.rb' }

      before do
        create_file('example.rb', '# encoding: utf-8')

        create_file(required_file_path, "puts 'Hello from required file!'")
      end

      it 'requires the passed path' do
        options.parse(['--require', required_file_path, 'example.rb'])
        expect($stdout.string).to start_with('Hello from required file!')
      end
    end

    describe '--cache' do
      it 'fails if no argument is given' do
        expect { options.parse %w[--cache] }
          .to raise_error(OptionParser::MissingArgument)
      end

      it 'fails if unrecognized argument is given' do
        expect { options.parse %w[--cache maybe] }.to raise_error(ArgumentError)
      end

      it 'accepts true as argument' do
        expect { options.parse %w[--cache true] }.not_to raise_error
      end

      it 'accepts false as argument' do
        expect { options.parse %w[--cache false] }.not_to raise_error
      end
    end

    describe '--exclude-limit' do
      it 'fails if given last without argument' do
        expect { options.parse %w[--auto-gen-config --exclude-limit] }
          .to raise_error(OptionParser::MissingArgument)
      end

      it 'fails if given alone without argument' do
        expect { options.parse %w[--exclude-limit] }
          .to raise_error(OptionParser::MissingArgument)
      end

      it 'fails if given first without argument' do
        expect { options.parse %w[--exclude-limit --auto-gen-config] }
          .to raise_error(OptionParser::MissingArgument)
      end

      it 'fails if given without --auto-gen-config' do
        expect { options.parse %w[--exclude-limit 10] }
          .to raise_error(ArgumentError)
      end
    end

    describe '--auto-gen-config' do
      it 'accepts other options' do
        expect { options.parse %w[--auto-gen-config --rails] }
          .not_to raise_error
      end
    end

    describe '-s/--stdin' do
      before do
        $stdin = StringIO.new
        $stdin.puts("{ foo: 'bar' }")
        $stdin.rewind
      end

      it 'fails if no paths are given' do
        expect { options.parse %w[-s] }
          .to raise_error(OptionParser::MissingArgument)
      end

      it 'succeeds with exactly one path' do
        expect { options.parse %w[--stdin foo] }.not_to raise_error
      end

      it 'fails if more than one path is given' do
        expect { options.parse %w[--stdin foo bar] }
          .to raise_error(ArgumentError)
      end
    end
  end

  describe 'options precedence' do
    def with_env_options(options)
      ENV['RUBOCOP_OPTS'] = options
      yield
    ensure
      ENV.delete('RUBOCOP_OPTS')
    end
    subject { options.parse(command_line_options).first }

    let(:command_line_options) { %w[--no-color] }

    context '.rubocop file' do
      before do
        create_file('.rubocop', %w[--color --fail-level C])
      end

      it 'has lower precedence then command line options' do
        is_expected.to eq(color: false, fail_level: :convention)
      end

      it 'has lower precedence then options from RUBOCOP_OPTS env variable' do
        with_env_options '--fail-level W' do
          is_expected.to eq(color: false, fail_level: :warning)
        end
      end
    end

    context '.rubocop directory' do
      before do
        FileUtils.mkdir '.rubocop'
      end

      it 'is ignored and command line options are used' do
        is_expected.to eq(color: false)
      end
    end

    context 'RUBOCOP_OPTS environment variable' do
      it 'has lower precedence then command line options' do
        with_env_options '--color' do
          is_expected.to eq(color: false)
        end
      end

      it 'has higher precedence then options from .rubocop file' do
        create_file('.rubocop', %w[--color --fail-level C])

        with_env_options '--fail-level W' do
          is_expected.to eq(color: false, fail_level: :warning)
        end
      end
    end
  end
end

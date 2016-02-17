require 'prodder/project'
require 'yaml'

module Prodder
  class Config
    PathError = Class.new(StandardError)

    LintError = Class.new(StandardError) do
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super errors.join "\n"
      end
    end

    attr_accessor :workspace

    def initialize(project_definitions)
      @config = project_definitions
    end

    def assert_in_path(*cmds)
      path = ENV['PATH'].split(File::PATH_SEPARATOR)
      cmds.each do |cmd|
        raise PathError.new(cmd) unless path.find { |dir| File.exist? File.join(dir, cmd) }
      end
    end

    def lint
      assert_in_path 'pg_dump'
      assert_in_path 'git'

      required = {
        'structure_file'     => [],
        'seed_file'          => [],
        'db'                 => %w[name host user tables],
        'git'                => %w[origin author]
      }

      @config.each_with_object([]) do |(project, defn), errors|
        required.each do |top, inner|
          if !defn.key?(top)
            errors << "Missing required configuration key: #{project}/#{top}"
          else
            errors.concat inner.reject { |key| defn[top].key?(key) }.map { |key|
              "Missing required configuration key: #{project}/#{top}/#{key}"
            }
          end
        end
      end
    end

    def lint!
      lint.tap { |errors| raise LintError.new(errors) if errors.any? }
    end

    def projects
      @projects ||= @config.map { |name, defn| Project.new(name, File.join(workspace, name), defn) }
    end

    def select_projects(names)
      return projects if names.empty?

      matches = projects.select { |project| names.include?(project.name) }

      if matches.size != names.size
        unmatched = names - matches.map(&:name)
        yield unmatched if block_given?
      end

      matches
    end

    def self.example_contents
      <<-EOF.gsub(/^      /, '')
      blog:
        structure_file: db/structure.sql
        seed_file: db/seeds.sql
        quality_check_file: db/quality_checks.sql
        git:
          origin: git@github.com:your/repo.git
          author: prodder <prodder@example.com>
        db:
          name: database_name
          host: database.server.example.com
          user: username
          password: password
          tables:
            - posts
            - authors
      EOF
    end
  end
end

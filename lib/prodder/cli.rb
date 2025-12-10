require 'prodder'
require 'thor'
require 'yaml'

class Prodder::CLI < Thor
  include Thor::Actions

  method_option :config,     type: :string,  aliases: '-c'
  method_option :workspace,  type: :string,  aliases: '-w', default: File.join(Dir.pwd, 'prodder-workspace')

  def initialize(*args)
    super

    # Help isn't printed when we don't provide --config, which is friggin absurd.
    if options[:config].nil?
      help
      raise Thor::RequiredArgumentMissingError, "No value provided for required option '--config'"
    end
  end

  desc "init [*PROJECTS]", "Initialize the named projects"
  def init(*projects)
    select_projects(projects).each { |project| project.init }

  rescue Prodder::Git::GitError => ex
    puts "Failed to run '#{ex.command}':"
    puts ex.error
    exit 1
  end

  desc "dump [*PROJECTS]", "Dump production data into the named projects"
  def dump(*projects)
    select_projects(projects).each do |project|
      project.dump
      if project.git.dirty?
        puts "#{project.name}: updates introduced."
      end
    end

  rescue Prodder::Project::SeedConfigFileMissing => ex
    puts "No such file: #{ex.filename}"
    exit 1

  rescue Prodder::PG::PGDumpError => ex
    puts ex.message
    exit 1
  end

  desc "commit [*PROJECTS]", "Commit prodder data changes to the named projects"
  def commit(*projects)
    select_projects(projects).each do |project|
      if project.git.dirty?
        puts "#{project.name}: committing changes."
        project.commit
      else
        puts "#{project.name}: no changes to commit."
      end
    end

  rescue Prodder::Git::GitError => ex
    puts "Failed to run '#{ex.command}':"
    puts ex.error
    exit 1
  end

  desc "push [*PROJECTS]", "Push new commits to the remote repositories of the named projects"
  def push(*projects)
    select_projects(projects).each do |project|
      if project.nothing_to_push?
        puts "#{project.name}: nothing to push."
      else
        puts "#{project.name}: pushing new commit."
        project.push
      end
    end

  rescue Prodder::Git::NotFastForward => ex
    puts "Refusing to push to remote #{ex.remote}: origin/master is not a fast forward from master."
    exit 1

  rescue Prodder::Git::GitError => ex
    puts "Failed to run '#{ex.command}':"
    puts ex.error
    exit 1
  end

  desc "ls", "List all known projects"
  def ls(*projects)
    config.projects.each { |project| puts project.name }
  end

  private

  def select_projects(projects)
    config.select_projects(projects) do |undefined|
      puts "Project not defined: #{undefined.join(', ')}"
      exit 1
    end
  end

  def config
    return @config if @config

    contents = File.read options[:config]
    projects = YAML.load contents

    @config = Prodder::Config.new(projects).tap do |config|
      config.workspace = options[:workspace]
      config.lint!
    end

  rescue Errno::ENOENT
    puts "Config file not found: #{options[:config]}"
    exit 1
  rescue Psych::SyntaxError
    puts "Invalid YAML in config file #{options[:config]}. Current file contents:\n\n#{contents}"
    exit 1

  rescue Prodder::Config::PathError => ex
    puts "`#{ex.message}` could not be found on your $PATH."
    puts
    puts "Current PATH:\n#{ENV['PATH']}"
    exit 1

  rescue Prodder::Config::LintError => ex
    puts ex.errors.join("\n")
    puts
    puts "Example configuration:"
    puts Prodder::Config.example_contents
    exit 1
  end

end

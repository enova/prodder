require 'deject'
require 'fileutils'
require 'prodder/pg'
require 'prodder/git'

module Prodder
  class Project
    SeedConfigFileMissing = Class.new(StandardError) do
      attr_reader :filename
      def initialize(filename); @filename = filename; end
    end

    Deject self
    dependency(:pg)  { |project| Prodder::PG.new(project.db_credentials) }
    dependency(:git) { |project| Prodder::Git.new(project.local_git_path, project.git_origin) }

    attr_reader :name, :workspace

    def initialize(name, workspace, definition)
      @name = name
      @workspace = workspace
      @defn = definition
    end

    def init
      git.clone_or_remote_update
    end

    def dump
      FileUtils.mkdir_p File.dirname(structure_file_name)
      pg.dump_structure db_credentials['name'], structure_file_name,
                        exclude_tables: excluded_tables, exclude_schemas: excluded_schemas

      FileUtils.mkdir_p File.dirname(seed_file_name)
      pg.dump_tables db_credentials['name'], seed_tables, seed_file_name

      # must split the structure file to allow data to be loaded after tables
      # being created but before triggers and foreign keys are created. this
      # facilitates validation during loading, yet avoids extra overhead and
      # false errors
      if separate_quality_checks?
        contents = File.readlines(structure_file_name)
        rgx = /^\-\- .* Type: INDEX; |^\-\- .* Type: TRIGGER; |^\-\- .* Type: FK CONSTRAINT; /
        structure, *quality = contents.slice_before(rgx).to_a
        quality_checks = structure.grep(/SET search_path/).last + quality.join

        File.open(quality_check_file_name, 'w') { |f| f.write(quality_checks) }
        File.open(structure_file_name, 'w') { |f| f.write(structure.join) }
      end

      if dump_permissions?
        FileUtils.mkdir_p File.dirname(permissions_file_name)
        pg.dump_permissions db_credentials['name'], permissions_file_name, included_users: included_users, 
                            exclude_tables: excluded_tables, exclude_schemas: excluded_schemas

      end
    end

    def commit
      return unless git.dirty?
      git.add structure_file_name
      git.add seed_file_name
      git.add quality_check_file_name if separate_quality_checks?
      git.commit "Auto-commit by prodder", @defn['git']['author']
    end

    def push
      if git.fast_forward?
        git.push
      else
        raise Prodder::Git::NotFastForward.new(git_origin)
      end
    end

    def nothing_to_push?
      git.remote_update
      git.no_new_commits?
    end

    def db_credentials
      @defn['db']
    end

    def permissions
      @defn['permissions']
    end

    def local_git_path
      workspace
    end

    def git_origin
      @defn['git']['origin']
    end

    def structure_file_name
      File.join workspace, @defn['structure_file']
    end

    def seed_file_name
      File.join workspace, @defn['seed_file']
    end

    def quality_check_file_name
      File.join workspace, @defn['quality_check_file']
    end

    def permissions_file_name
      File.join workspace, permissions['file']
    end

    def separate_quality_checks?
      @defn.key? 'quality_check_file'
    end

    def dump_permissions?
      @defn.key?('permissions') && permissions.key?('file') 
    end

    def excluded_schemas
      db_credentials['exclude_schemas'] || []
    end

    def excluded_tables
      db_credentials['exclude_tables'] || []
    end

    def included_users
      permissions['included_users'] || []
    end

    def seed_tables
      value = db_credentials['tables']
      return value unless value.is_a?(String)

      path = File.join(workspace, value)
      raise SeedConfigFileMissing.new(File.join(name, value)) unless File.exist?(path)
      YAML.load IO.read(path)
    end
  end
end

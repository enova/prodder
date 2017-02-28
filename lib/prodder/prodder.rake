module Prodder
  # The list of default rake tasks which prodder will be removing or replacing.
  # @see databases.rake (currently at lib/active_record/railties/databases.rake)
  def self.obsoleted_rake_tasks
    [/^db:_dump$/,
     /^db:migrate:reset$/,
     /^db:drop$/,
     /^db:create$/,
     /^db:drop:all$/,
     /^db:create:all$/,
     /^db:migrate$/,
     /^db:migrate:up$/,
     /^db:migrate:down$/,
     /^db:rollback$/,
     /^db:forward$/,
     /^db:version$/,
     /^db:fixtures:.*$/,
     /^db:abort_if_pending_migrations$/,
     /^db:purge$/,
     /^db:purge:all$/,
     /^db:charset$/,
     /^db:collation$/,
     /^db:reset$/,
     /^db:schema:.*$/,
     /^db:seed$/,
     /^db:setup$/,
     /^db:structure:.*$/,
     /^db:test:.*$/,
     /^test:prepare$/
    ]
  end
end

tasks = Rake.application.instance_variable_get :@tasks
tasks.keys.select { |name|
  Prodder.obsoleted_rake_tasks.any? { |obsoleted| obsoleted.match(name) }
}.each { |name| tasks.delete name }

namespace :db do
  desc "Drop, recreate, reseed, remigrate the database"
  task :reset => ['db:drop', 'db:setup']

  desc "Create the database, load db/structure.sql, db/seeds.sql, db/quality_checks.sql"
  task :setup => ['db:create', 'db:structure:load', 'db:seed', 'db:quality_check', 'db:permission', 'db:settings']

  dependencies = [:load_config]
  if Rake::Task.task_defined?('rails_env')
    dependencies << :rails_env
  end

  namespace :migrate do
    task :up => [:environment].concat(dependencies) do
      version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
      raise 'VERSION is required' unless version
      as("migration_user", in: ENV['RAILS_ENV'] || Rails.env) do
        ActiveRecord::Base.establish_connection((ENV['RAILS_ENV'] || Rails.env).intern)
        ActiveRecord::Migrator.run(:up, ActiveRecord::Migrator.migrations_paths, version)
      end
    end

    task :down => [:environment].concat(dependencies) do
      version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
      raise 'VERSION is required - To go down one migration, run db:rollback' unless version
      as("migration_user", in: ENV['RAILS_ENV'] || Rails.env) do
        ActiveRecord::Base.establish_connection((ENV['RAILS_ENV'] || Rails.env).intern)
        ActiveRecord::Migrator.run(:down, ActiveRecord::Migrator.migrations_paths, version)
      end
    end
  end

  namespace :purge do
    task :all => dependencies do
      as("superuser") do
        ActiveRecord::Tasks::DatabaseTasks.purge_all
      end
    end
  end

  desc "Empty the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:drop:all to drop all databases in the config). Without RAILS_ENV it defaults to purging the development and test databases."
  task :purge => dependencies do
    as("superuser", in: ENV['RAILS_ENV'] || [Rails.env, "test"]) do
      ActiveRecord::Tasks::DatabaseTasks.purge_current
    end
  end

  desc "Retrieves the charset for the current environment's database"
  task :charset => [:environment].concat(dependencies) do
    as("migration_user", in: ENV['RAILS_ENV'] || Rails.env) do
      puts ActiveRecord::Tasks::DatabaseTasks.charset_current
    end
  end

  desc "Retrieves the collation for the current environment's database"
  task :collation => [:environment].concat(dependencies) do
    as("migration_user", in: ENV['RAILS_ENV'] || Rails.env) do
      begin
        puts ActiveRecord::Tasks::DatabaseTasks.collation_current
      rescue NoMethodError
        $stderr.puts 'Sorry, your database adapter is not supported yet. Feel free to submit a patch.'
      end
    end
  end

  desc 'Rolls the schema back to the previous version (specify steps w/ STEP=n).'
  task :rollback => [:environment].concat(dependencies) do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    as("migration_user", in: ENV['RAILS_ENV'] || Rails.env) do
      ActiveRecord::Base.establish_connection((ENV['RAILS_ENV'] || Rails.env).intern)
      ActiveRecord::Migrator.rollback(ActiveRecord::Migrator.migrations_paths, step)
    end
  end

  desc 'Pushes the schema to the next version (specify steps w/ STEP=n).'
  task :forward => [:environment].concat(dependencies) do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    as("migration_user", in: ENV['RAILS_ENV'] || Rails.env) do
      ActiveRecord::Base.establish_connection((ENV['RAILS_ENV'] || Rails.env).intern)
      ActiveRecord::Migrator.forward(ActiveRecord::Migrator.migrations_paths, step)
    end
  end

  desc 'Retrieves the current schema version number'
  task :version => [:environment].concat(dependencies) do
    as("migration_user", in: ENV['RAILS_ENV'] || Rails.env) do
      ActiveRecord::Base.establish_connection((ENV['RAILS_ENV'] || Rails.env).intern)
      puts "Current version: #{ActiveRecord::Migrator.current_version}"
    end
  end

  task :abort_if_pending_migrations => [:environment].concat(dependencies) do
    as("migration_user", in: ENV['RAILS_ENV'] || Rails.env) do
      ActiveRecord::Base.establish_connection((ENV['RAILS_ENV'] || Rails.env).intern)
      pending_migrations = ActiveRecord::Migrator.open(ActiveRecord::Migrator.migrations_paths).pending_migrations

      if pending_migrations.any?
        puts "You have #{pending_migrations.size} pending #{pending_migrations.size > 1 ? 'migrations:' : 'migration:'}"
        pending_migrations.each do |pending_migration|
          puts '  %4d %s' % [pending_migration.version, pending_migration.name]
        end
        abort %{Run `rake db:migrate` to update your database then try again.}
      end
    end
  end

  namespace :drop do
    task :all => dependencies do
      as("superuser") do
        ActiveRecord::Tasks::DatabaseTasks.drop_all
      end
    end
  end

  desc "Drops the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:drop:all to drop all databases in the config). Without RAILS_ENV, it defaults to dropping the development and test databases."
  task :drop => dependencies do
    as("superuser", in: ENV['RAILS_ENV'] || [Rails.env, "test"]) do
      ActiveRecord::Tasks::DatabaseTasks.drop_current
    end
  end

  desc 'Creates the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:create:all to create all databases in the config). Without RAILS_ENV, it defaults to creating the development and test databases.'
  task :create => dependencies do
    environments = nil
    if ENV['RAILS_ENV']
      environments = Array(ENV['RAILS_ENV'])
    else
      environments = [Rails.env, "test"]
    end
    as("superuser", in: environments) do
      ActiveRecord::Tasks::DatabaseTasks.create_current
      ActiveRecord::Base.configurations.each do |env, config|
        if environments.include?(env) && config["migration_user"] && config['database']
          set_psql_env config
          `psql --no-psqlrc --command "ALTER DATABASE #{config['database']} OWNER TO #{config['migration_user']}" #{Shellwords.escape(config['database'])}`
        end
      end
    end
  end

  namespace :create do
    task :all => dependencies do
      as("superuser") do
        ActiveRecord::Tasks::DatabaseTasks.create_all
        ActiveRecord::Base.configurations.each do |env, config|
          if config["migration_user"] && config['database']
            set_psql_env config
            `psql --no-psqlrc --command "ALTER DATABASE #{config['database']} OWNER TO #{config['migration_user']}" #{Shellwords.escape(config['database'])}`
          end
        end
      end
    end
  end

  desc "Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)."
  task :migrate => [:environment].concat(dependencies) do
    as("migration_user", in: ENV['RAILS_ENV'] || Rails.env) do
      ActiveRecord::Base.establish_connection((ENV['RAILS_ENV'] || Rails.env).intern)
      ActiveRecord::Tasks::DatabaseTasks.migrate
    end
  end

  namespace :structure do
    desc "Load db/structure.sql into the current environment's database"
    task :load => dependencies do
      config = ActiveRecord::Base.configurations[ENV['RAILS_ENV'] || Rails.env]
      config["username"] = config["superuser"] if config["superuser"] && File.exist?('db/permissions.sql')
      set_psql_env config
      puts "Loading db/structure.sql into database '#{config['database']}'"
      `psql --no-psqlrc -f db/structure.sql #{Shellwords.escape(config['database'])}`
      raise 'Error loading db/structure.sql' if $?.exitstatus != 0
    end
  end

  desc "Load initial seeds from db/seeds.sql"
  task :seed => dependencies do
    if File.exist?('db/seeds.sql')
      config = ActiveRecord::Base.configurations[ENV['RAILS_ENV'] || Rails.env]
      config["username"] = config["superuser"] if config["superuser"] && File.exist?('db/permissions.sql')
      set_psql_env config
      puts "Loading db/seeds.sql into database '#{config['database']}'"
      `psql --no-psqlrc -f db/seeds.sql #{Shellwords.escape(config['database'])}`
      raise 'Error loading db/seeds.sql' if $?.exitstatus != 0
    else
      puts 'db/seeds.sql not found: no seeds to load.'
    end
  end

  desc "Load quality_checks (indexes, triggers, foreign keys) from db/quality_checks.sql"
  task :quality_check => dependencies do
    if File.exist?('db/quality_checks.sql')
      config = ActiveRecord::Base.configurations[ENV['RAILS_ENV'] || Rails.env]
      config["username"] = config["superuser"] if config["superuser"] && File.exist?('db/permissions.sql')
      set_psql_env config
      puts "Loading db/quality_checks.sql into database '#{config['database']}'"
      `psql --no-psqlrc -f db/quality_checks.sql #{Shellwords.escape(config['database'])}`
      raise 'Error loading db/quality_checks.sql' if $?.exitstatus != 0
    else
      puts 'db/quality_checks.sql not found: no quality_checks to load.'
    end
  end

  desc "Load permissions (DB object level access control, group role memberships) from db/permissions.sql"
  task :permission => dependencies do
    if File.exist?('db/permissions.sql')
      config = ActiveRecord::Base.configurations[ENV['RAILS_ENV'] || Rails.env]
      config["username"] = config["superuser"] if config["superuser"]
      set_psql_env config
      puts "Loading db/permissions.sql into database '#{config['database']}'"
      disconnect
      ActiveRecord::Base.establish_connection((ENV['RAILS_ENV'] || Rails.env).intern)
      is_super = ActiveRecord::Base.connection.execute(<<-SQL).first['is_super']
        select 1 as is_super from pg_roles where rolname = '#{config['username']}' and rolsuper
      SQL
      unless is_super
        puts "Restoring permissions as config/database.yml non-superuser: #{config['username']}, expect errors, or rerun after granting superuser"
      end
      `psql --no-psqlrc -f db/permissions.sql #{Shellwords.escape(config['database'])}`

      raise 'Error loading db/permissions.sql' if $?.exitstatus != 0
    else
      puts 'db/permissions.sql not found: no permissions to load.'
    end
  end

  desc "Load database settings"
  task :settings => dependencies do
    config = ActiveRecord::Base.configurations[ENV['RAILS_ENV'] || Rails.env]
    config["username"] = config["superuser"] if config["superuser"] && File.exist?('db/permissions.sql')
    set_psql_env config
    puts "Loading db/settings.sql into database '#{config['database']}'"
    disconnect
    ActiveRecord::Base.establish_connection((ENV['RAILS_ENV'] || Rails.env).intern)
    is_super = ActiveRecord::Base.connection.execute(<<-SQL).first['is_super']
      select 1 as is_super from pg_roles where rolname = '#{config['username']}' and rolsuper
    SQL
    unless is_super
      puts "Restoring settings as config/database.yml non-superuser: #{config['username']}, expect errors, or rerun after granting superuser"
    end
    `psql --no-psqlrc -f db/settings.sql #{Shellwords.escape(config['database'])}`

    raise 'Error loading db/settings.sql' if $?.exitstatus != 0
  end

  # Empty this, we don't want db:migrate writing structure.sql any more.
  task :_dump do
  end

  # Ugh. cucumber.rake, installed by the cucumber generator, always uses a task dependency
  # on db:test:prepare. rspec.rake, contained within rspec-rails, uses either db:test:prepare
  # or db:test:clone_structure, depending on what schema_format you declare.
  #
  # Gut and redefine both.
  namespace :test do
    task :prepare do
      begin
        orig_env_var, orig_rails_var = ENV['RAILS_ENV'], Rails.env
        Rails.env = ENV['RAILS_ENV'] = 'test'
        Rake::Task['db:reset'].invoke
        Rake::Task['db:migrate'].invoke
      ensure
        ENV['RAILS_ENV'], Rails.env = orig_env_var, orig_rails_var
      end
    end

    # What rspec calls as a prereq to :spec
    task :clone_structure => :prepare
  end

  # Exposed as a global method in Rails 3.x, but moved to a private method in Rails 4.
  # We should instead be registering our own `seed_loader`, which would obviate a lot
  # of this hackery to support Rails 4.
  if !defined?(set_psql_env)
    def set_psql_env(config)
      ENV['PGHOST']     = config['host']          if config['host']
      ENV['PGPORT']     = config['port'].to_s     if config['port']
      ENV['PGPASSWORD'] = config['password'].to_s if config['password']
      ENV['PGUSER']     = config['username'].to_s if config['username']
    end
  end

  #adding to the Rails hackery
  if !defined?(ActiveRecord::Tasks::DatabaseTasks.migrate)
    module ActiveRecord::Tasks::DatabaseTasks
      def migrate
        verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
        version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
        scope   = ENV['SCOPE']
        verbose_was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, verbose
        ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths, version) do |migration|
          scope.blank? || scope == migration.scope
        end
      ensure
        ActiveRecord::Migration.verbose = verbose_was
      end
    end
  end

  if !defined?(ActiveRecord::Tasks::DatabaseTasks.purge_all)
    module ActiveRecord::Tasks::DatabaseTasks
      def purge_all
        each_local_configuration { |configuration|
          purge configuration
        }
      end
    end
  end

  if !defined?(ActiveRecord::Tasks::DatabaseTasks.purge_current)
    module ActiveRecord::Tasks::DatabaseTasks
      def purge_current(environment = env)
        each_current_configuration(environment) { |configuration|
          purge configuration
        }
        ActiveRecord::Base.establish_connection(environment.to_sym)
      end
    end
  end

  def as(user, opts = {}, &block)
    if File.exist?('db/permissions.sql')
      config, config_was = ActiveRecord::Base.configurations.deep_dup, ActiveRecord::Base.configurations.deep_dup
      in_env = Array(opts[:in]) || config.keys
      if config.all? { |env, config_hash| in_env.include?(env) ? config_hash[user] : true }
        disconnect
        config.each { |env, config_hash| config_hash["username"] = config_hash[user] if in_env.include?(env) }
        ActiveRecord::Base.configurations = config
      end
    else
      puts "No permissions file (db/permissions.sql) found, running everything in context of user"
    end
    yield
  ensure
    ActiveRecord::Base.configurations = config_was if config_was
    in_env.each { |env| ActiveRecord::Base.establish_connection(env.intern) } if in_env
  end

  def disconnect
    if ActiveRecord::Base.connection_pool && ActiveRecord::Base.connection_pool.connections.size > 0
      ActiveRecord::Base.connection_pool.disconnect!
    end
  rescue ActiveRecord::ConnectionNotEstablished
  end

end

namespace :test do
  task :prepare => [ 'db:test:prepare' ]
end

# Yes, I really want migrations to run against the test DB.
Rake::Task['db:migrate'].actions.unshift(proc {
  ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[ENV['RAILS_ENV'] || Rails.env])
})

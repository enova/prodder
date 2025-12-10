
# Prodder

[![Ruby](https://img.shields.io/badge/ruby-2.7%2B-ruby.svg)](https://www.ruby-lang.org)
[![PostgreSQL](https://img.shields.io/badge/postgresql-15%2B-blue.svg)](https://www.postgresql.org)

A tool to maintain and load your Rails application's database structure, seed
table contents, permissions and database settings based on its migration history
and the current state in production databases.

**In short:** Synchronize your development database with production structure without re-running all migrations.

## Why Prodder?

Traditional Rails development requires running all migrations from scratch, which:

- ❌ Becomes slow as your migration history grows
- ❌ Can fail if old migrations are incompatible with current code
- ❌ Doesn't reflect actual production database state

Prodder solves this by:

- ✅ Loading production database structure directly
- ✅ Running only new migrations not yet deployed to production
- ✅ Maintaining permissions and quality checks from production
- ✅ Automatically syncing structure files from production databases

## Requirements

- **Ruby 2.7+** - This gem requires Ruby 2.7.0 or later
- **Bundler 2.0+** - For dependency management
- **PostgreSQL 15+** - Requires PostgreSQL 15.0 or later

**Note:** Support for Ruby 2.6 and PostgreSQL versions older than 15 has been removed as of the latest version. If you need to use older versions, please use a previous version of this gem.

## Overview

Prodder follows a simple workflow:

1. **Maintain structure files**: Your project keeps `db/structure.sql`, `db/seeds.sql`, and optionally `db/quality_checks.sql` and `db/permissions.sql` in version control.

2. **Include migrations table**: Ensure `db/seeds.sql` includes the `schema_migrations` table from production.

3. **Run new migrations only**: Only migrations not yet in production's `schema_migrations` table will run locally.

4. **Update structure files**: After deploying a migration to production, update your structure files by running `prodder dump` against production.

5. **Delete old migrations**: Once a migration is deployed and the structure files are updated, the migration file can be safely removed.

6. **Track permissions**: Application permission changes are captured in `db/permissions.sql` for consistent development environments.

### The Prodder Workflow

```
Production DB → prodder dump → db/*.sql files → Git → Development
                                                        ↓
                                              db:reset + new migrations
```

## Replacing `rake db:*` Tasks

Prodder can be included as a Railtie in your Rails application to automatically
replace many of Rails' `db:*` tasks with versions that work with production-sourced
structure files.

### Prerequisites

- `db/structure.sql` - Base database structure
- `db/seeds.sql` - Seed data including `schema_migrations` table
- `db/quality_checks.sql` (optional) - Foreign keys and constraints
- `db/permissions.sql` (optional) - Database permissions for role-based access

### Installation

Add to your Gemfile:

```ruby
gem 'prodder', require: 'prodder/railtie'
```

Configure Rails to use SQL schema format:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.active_record.schema_format = :sql
  end
end
```

### Basic Usage

Once installed, use these commands:

```bash
# Recreate database from structure and seed files
bundle exec rake db:reset

# Run only new migrations (those not in production's schema_migrations)
bundle exec rake db:migrate

# The typical development workflow
bundle exec rake db:reset db:migrate
```

If you want to work with permissions setup like production:

```ruby
# config/database.yml

username: user_who_will_run_your_app (# for example identity__web)
migration_user: migration_overlay_user_who_is_usually_db_owner (# for example identity__owner)
superuser: godmode (# for example postgres)
```

Note that the `migration_user` and `superuser` must be created before you run `db:reset db:migrate`, just as you would have to when you have to
create the `username: user` even with the standard setup. Note that this is only ever recommended for development environments. Do NOT
mess with production overlays to have 3 different users in production, that's the reason for having overlays in the first place.You can also
easily control this by making the gem a `group :development` only dependency:

```
#!/usr/bin/env bash

set -eu

createuser --superuser --createrole --createdb godmode || true
createuser --createrole migration_overlay_user_who_is_usually_db_owner || true

bundle install
bundle exec rake db:reset db:migrate
```

### Usage

Things that really matter:

1. `rake db:reset` recreates your database, loading `db/structure.sql`, `db/seeds.sql`,
   `db/quality_checks.sql` and `permissions.sql`.
2. `rake db:migrate` runs migrations, as before, but runs *after* the initial seeds were
   created. Those initial seeds should have included your production app's `schema_migrations`
   table contents. This means only those migrations that have not yet run in production
   will need to be run locally.
3. If you configured to have 3 users in your `#config/database.yml` file and have a `permissions.sql` file present,
   all your `db:*` commands will be run in the context of the user it makes the most sense to run as, mimicking
   our production environment. For instance(s), to reset the database (god forbid we do this in production), it will
   run as `superuser`, to run a migration, as the `migration_user` and your application will connect to the database
   as `username`. Thus it achieves the overlays of a DBA, migration and production application.
4. Having 3 users configured and to achieve the effects of step 3, you must have a `permissions.sql`. However, you do
   not need to have 3 users configured to restore permissions (load the `permissions.sql` file). This being said, it
   does not make sense to restore permissions in your environment if you're just going to run everything as a single,
   most likely superuser.

### Details

This will remove the `db:*` tasks:

- `db:_dump`: an internal task used by rails to dump the schema after migrations. Obsolete.
- `db:drop:*`
- `db:create:*`
- `db:migrate`
- `db:migrate:reset`
- `db:migrate:up`
- `db:migrate:down`
- `db:fixtures:.*`
- `db:abort_if_pending_migrations`
- `db:purge:*`
- `db:charset`
- `db:collation`
- `db:rollback`
- `db:version`
- `db:forward`
- `db:reset`
- `db:schema:*`
- `db:seed`
- `db:setup`
- `db:structure:*`
- `db:test:*`
- `test:prepare`: Rails 4.1 added this task to auto-maintain the test DB schema.

And reimplement only the following:

- `db:structure:load`: Load the contents of `db/structure.sql` into the database of your current environment.
- `db:seed`: Load `db/seeds.sql` into the database of your current environment.
- `db:quality_check`: Load `db/quality_checks.sql` into the database of your current environment, if present.
- `db:reset`: db:drop db:setup
- `db:settings`: Load the contents of `db/settings.sql` into the database of your current environment.
- `db:setup`: db:create db:structure:load db:seed db:quality_check db:settings
- `db:test:prepare`: RAILS_ENV=test db:reset db:migrate
- `db:test:clone_structure`: RAILS_ENV=test db:reset db:migrate
- `test:prepare`: db:test:prepare
- `db:drop`: Drop database as superuser
- `db:create`:  Create database as `superuser` and transfer ownership to `migration_user`
- `db:migrate:*`, `db:rollback` Run migrations up/down as `migration_user`
- `db:purge:*, db:charset, db:collation, db:version, db:forward, db:rollback, db:abort_if_pending_migrations` as
  appropriate users.

See [lib/prodder/prodder.rake](lib/prodder/prodder.rake)
for more info.

This is likely to cause issues across Rails versions. No other choice really. It
has been used in anger on Rails 3.2.x and Rails 4.1.x.

## Development and Testing

### Ruby Version

This project requires Ruby 2.7+ for gem usage, though development is done on Ruby 3.3+. The development Ruby version is specified in `.ruby-version` and minimum required version in the gemspec file.

### Testing Frameworks

This project uses the following testing frameworks:

- **RSpec 3.13+** for unit tests
- **Cucumber 10.x** for feature tests (upgraded from 2.x)
- **Aruba 2.x** for CLI testing (upgraded from 0.5.x)

### Running Tests

```bash
# Run RSpec tests
bundle exec rspec

# Run Cucumber features
bundle exec cucumber

# Run all tests
bundle exec rspec && bundle exec cucumber
```

### Supported PostgreSQL Versions

This gem requires PostgreSQL 15.0 or later. Tested and confirmed working on:

- PostgreSQL 15.x
- PostgreSQL 16.x
- PostgreSQL 17.x

## Using prodder to maintain `db/*` files

### Example configuration

`prodder` is configured using a simplistic YAML file. There is no logic performed
to locate that file; the path to it *must* be provided each time `prodder` is
invoked.

```yaml
# Each top-level key is the name of the Rails project for which we are updating
# the structure and seed data. Let's pretend we're maintaining a online store.

store:
  structure_file: db/structure.sql
  seed_file: db/seeds.sql
  quality_check_file: db/quality_checks.sql
  permissions:
    file: db/permissions.sql
    included_users: service__owner, service__web, prodder__read_only
  git:
    origin: git@github.com:pd/store.git
    author: prodder auto-commit <pd+prodder@krh.me>
  db:
    name: store_production_db
    host: store-db.krh.me
    user: prodder_readonly
    password: super-secret
    tables:
      - schema_migrations
      - coupons
      - products
      - vendors
    exclude_tables:
      - production_only_table
    exclude_schemas:
      - production_only_replication_schema
```

If you would prefer to maintain the list of seed tables within your application
itself, the `db.tables` key can be given the path to a YAML file from which to
load the list instead:

```yaml
# prodder-config.yml
store:
  # [snip]
  db:
    tables: config/seeds.yml

# store/config/seeds.yml:
- schema_migrations
- coupons
- products
- vendors
```

### Quality Checks

In some cases, such as foreign key dependencies and triggers, you may wish to defer
loading constraints on your tables until *after* your seed data has been loaded.
`prodder` treats the presence of a `quality_check_file` key in the configuration
as an indication that it should split `structure_file` into those statements which
create the base structure, and put the constraints into the `quality_check_file`.

### Permissions

We have had multiple cases in the past with deployments failing because some role
cannot access something on prod. To fail early and catch these in development, it
would be easier to just have these permissions loaded in development environments.
However, note that to actually take advantage of these restored permissions, you
must configure the 3 users as mentioned before in `#config/database.yml`.

```yaml
store:
  structure_file: db/structure.sql       # CREATE TABLE ...
  quality_check_file: db/quality_checks.sql # ALTER TABLE ... ADD FOREIGN KEY ...
```

### Example usage

The `-c` option to specify the configuration file is always required. All
options should be passed at the end of the command line.

```
# Clone all the repositories in prodder.yml, update the remotes for
# any that already existed but have new origins specified, and
# check out the branch specified in the config. The branch must be
# the name of an available remote branch, as the local branch will
# be forcibly reset to its current SHA with `git reset --hard`.
$ prodder init -c prodder.yml

# Dump the remote databases' structures and seed tables into the
# files specified by structure_file and seed_file.
$ prodder dump -c prodder.yml

# Lots of projects? Dump just one or two:
$ prodder dump store chordgen -c prodder.yml

# Commit the changes to each project's repository. Only repositories
# with actual changes will be committed.
$ prodder commit -c prodder.yml

# Push.
$ prodder push -c prodder.yml
```

## TODO

- Log activity as it is performed.
- Support tracking a particular branch instead of master.
- Support specifying the options to pass to each pg_dump form.
- Select dumping only a subset of a seed table. (pg_dump won't do this ...)

## Previous Contributors

- [Kyle Hargraves](https://github.com/pd)
- [Sri Rangarajan](https://github.com/Slania)
- [Emmanuel Sambo](https://github.com/esambo)
- [Cindy Wise](https://github.com/cyyyz)
- [Robert Nubel](https://github.com/rnubel)
- [Josh Cheek](https://github.com/JoshCheek)
- [Alexandre Castro](https://github.com/acastro2)

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

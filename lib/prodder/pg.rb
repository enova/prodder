require 'open3'
require 'pg'
require 'set'

module Prodder
  class PG
    PGDumpError = Class.new(StandardError)

    attr_reader :credentials

    def initialize(credentials = {})
      @credentials = credentials
    end

    def create_role(role, opts = [])
      arguments = [
        'createuser',
        '--no-password',
        '--no-superuser',
        '--no-createrole',
        '--no-createdb'
      ]

      arguments.push *opts, role
      run arguments
    end

    def drop_role(role)
      run ['dropuser', role]
    end

    def create_db(db_name, sql = nil)
      run ['createdb', db_name]
      psql db_name, sql if sql
    end

    def drop_db(db_name)
      run ['dropdb', db_name]
    end

    def psql(db_name, sql)
      run ['psql', db_name], sql
    end

    def dump_settings(db_name, filename)
      db_settings = pg_conn(db_name) { |conn| conn.exec(<<-SQL).map { |setting| setting['config'] } }
        select unnest(setconfig) as config
        from pg_catalog.pg_db_role_setting
        join pg_database on pg_database.oid = setdatabase
        -- 0 = default, for all users
        where setrole = 0
        and datname = '#{db_name}'
      SQL

      File.open(filename, 'w') do |f|
        db_settings.each do |setting|
          # wipe out all spaces
          setting.gsub!(/\s+/, '')

          # if the setting is empty, ignore it
          unless setting.empty?
            # else, drop carriage returns/new lines
            setting.chomp!
            # and append an empty string if the setting was being assigned a value of nothing
            setting += "''" if setting.match(/=$/)
            # using the magic of psql variables through :DBNAME
            f.puts "ALTER DATABASE :DBNAME SET #{setting};"
          end
        end
      end
    end

    def dump_structure(db_name, filename, options = {})
      arguments = [
        '--schema-only',
        '--no-privileges',
        '--no-owner',
        '--host', credentials['host'],
        '--username', credentials['user']
      ]

      if options[:exclude_schemas].respond_to? :map
        arguments.concat options[:exclude_schemas].map { |schema| ['--exclude-schema', schema] }.flatten
      end

      if options[:exclude_tables].respond_to? :map
        arguments.concat options[:exclude_tables].map { |table| ['--exclude-table', table] }.flatten
      end

      pg_dump filename, arguments.push(db_name)
    end

    def dump_tables(db_name, tables, filename)
      pg_dump filename, [
        '--data-only',
        '--no-privileges',
        '--no-owner',
        '--disable-triggers',
        '--host',     credentials['host'],
        '--username', credentials['user'],
        *tables.map { |table| ['--table', table] }.flatten,
        db_name
      ]
    end

    def dump_permissions(db_name, filename, options = {})
      perm_out_sql = ""
      user_list = []

      perm_out_sql << dump_db_access_control(db_name, user_list, options)
      perm_out_sql.prepend pg_dumpall db_name, user_list, options

      perm_out_sql.prepend(alter_role_function)
      perm_out_sql.prepend(create_role_function)
      perm_out_sql.prepend(granted_by_function)
      perm_out_sql.prepend("SET client_min_messages TO WARNING;\n")
      perm_out_sql << drop_role_create_function
      perm_out_sql << drop_role_alter_function
      perm_out_sql << drop_granted_by_function

      File.open(filename, 'w') { |f| f.write perm_out_sql }
    end

    #From pg_dump
    ACL_GRANT = /^GRANT /
    ACL_REVOKE = /^REVOKE /
    DEFAULT_PRIVILEGES = /^ALTER DEFAULT PRIVILEGES /
    SET_OBJECT_OWNERSHIP = /.* OWNER TO /

    def dump_db_access_control(db_name, user_list, options)
      perm_out_sql = ""
      arguments = [
        '--schema-only',
        '--host', credentials['host'],
        '--username', credentials['user']
      ]

      if options[:exclude_schemas].respond_to? :map
        arguments.concat options[:exclude_schemas].map { |schema| ['--exclude-schema', schema] }.flatten
      end

      if options[:exclude_tables].respond_to? :map
        arguments.concat options[:exclude_tables].map { |table| ['--exclude-table', table] }.flatten
      end

      arguments.push db_name

      white_list = options[:included_users] || []
      irrelevant_login_roles = irrelevant_login_roles(db_name, white_list).map { |user| user['rolname'] }

      run ['pg_dump', *arguments] do |out, err, success|
        out.each_line do |line|
          if line.match(ACL_GRANT)           ||
             line.match(ACL_REVOKE)          ||
             line.match(DEFAULT_PRIVILEGES)  ||
             line.match(SET_OBJECT_OWNERSHIP)

            unless irrelevant_login_roles.include?(line.match(/ (\S*);$/)[1])
              perm_out_sql << line
              user_list << (line.match(/ (\S*);$/)[1]).gsub(/"/, '')
            end
          end
        end
        raise PGDumpError.new(err) if !success
      end

      user_list.uniq!
      perm_out_sql
    end

    private

    def pg_conn(db_name)
      conn = ::PG.connect(
        dbname: db_name,
        host: credentials['host'],
        user: credentials['user'],
        password: credentials['password']
      )

      res = yield(conn)
      conn.close
      res
    end

    def irrelevant_login_roles(db_name, white_list)
      white_list ||= []
      login_role_list = pg_conn(db_name) do |conn|
        conn.exec('SELECT oid, rolname FROM pg_roles WHERE rolcanlogin AND NOT rolsuper').map do |role|
          {'oid' => role['oid'], 'rolname' => role['rolname'] }
        end
      end

      login_role_list.reject! { |user| white_list.include?(user['rolname']) }
      login_role_list
    end

    def run(cmd, stdin_data = nil, &block)
      # TODO use a tmp .pgpass file instead of $PGPASSWORD
      env = { 'PGPASSWORD' => credentials['password'] }
      Open3.popen3(env, *cmd) do |stdin, out, err, thr|
        if stdin_data
          stdin.write stdin_data
          stdin.close
        end

        out, err = out.read, err.read
        puts err if err
        block.call(out, err, thr.value.success?) if block
        out
      end
    end

    def pg_dump(filename, cmd)
      run ['pg_dump', *cmd] do |out, err, success|
        raise PGDumpError.new(err) if !success
        File.open(filename, 'w') { |f| f.write out }
      end
    end

    def pg_dumpall(db_name, user_list, options)
      white_list = options[:included_users] || []
      irrelevant_login_roles = irrelevant_login_roles(db_name, white_list).map { |user| user['oid'] }

      roles_and_memberships = pg_conn(db_name) { |conn| conn.exec smart_pgdumpall(user_list, irrelevant_login_roles) }

      rolcreate_sql, rolalter_sql, rolgrant_sql = "", "", ""
      created_roles = Set.new

      roles_and_memberships.each do |role|
        unless created_roles.member? role['rolname']
          created_roles << role['rolname']
          tmp_sql = ""
          rolcreate_sql << "SELECT * FROM create_role_if_not_exists('#{role['rolname']}');\n"
          tmp_sql << "ALTER ROLE \"#{role['rolname']}\" WITH"

          [
            ['rolsuper', 'SUPERUSER'],
            ['rolinherit', 'INHERIT'],
            ['rolcreaterole', 'CREATEROLE'],
            ['rolcreatedb', 'CREATEDB'],
            ['rolcanlogin', 'LOGIN'],
            ['rolreplication', 'REPLICATION']
          ].each do |key, modifier|
            tmp_sql << if role[key].eql? 't'
              " #{modifier}"
            else
              modifier.prepend ' NO'
            end
          end

          tmp_sql << " CONNECTION LIMIT #{role['rolconnlimit']}" unless role['rolconnlimit'].eql?("-1")
          tmp_sql << " VALID UNTIL '#{role['rolvaliduntil']}'" unless role['rolvaliduntil'].nil?
          tmp_sql << ";\n"
          tmp_sql << "COMMENT ON ROLE \"#{role['rolname']}\" IS '#{role['rolcomment']}';\n" unless role['rolcomment'].nil?
          rolalter_sql << "SELECT * FROM alter_role('#{role['rolname']}', $$#{tmp_sql}$$);\n"
        end

        unless role['member'].nil?
          tmp_sql = ""
          rolgrant_sql << "GRANT \"#{role['roleid']}\" TO \"#{role['member']}\""
          rolgrant_sql << " WITH ADMIN OPTION" if role['admin_option'].eql?('t')
          rolgrant_sql << ";\n"
          tmp_sql << "GRANT \"#{role['roleid']}\" TO \"#{role['member']}\""
          tmp_sql << " WITH ADMIN OPTION" if role['admin_option'].eql?('t')
          tmp_sql << " GRANTED BY #{role['grantor']}" if role['grantor'].eql?('t')
          tmp_sql << ";"
          rolgrant_sql << "SELECT * FROM granted_by('#{role['grantor']}', $$#{tmp_sql}$$);\n"
        end
      end

      rolcreate_sql << rolalter_sql << rolgrant_sql
    end

    def smart_pgdumpall(user_list, irrelevant_login_roles)
      irrelevant_login_roles << -1 if irrelevant_login_roles.respond_to?(:empty?) && irrelevant_login_roles.empty?
      replace_bind_variables(<<-SQL, [user_list, irrelevant_login_roles])
        WITH RECURSIVE memberships(roleid, member, admin_option, grantor) AS (
          SELECT ur.oid AS roleid,
                 NULL::oid AS member,
                 NULL::boolean AS admin_option,
                 NULL::oid AS grantor
          FROM pg_roles ur
          WHERE ur.rolname IN (?)
          UNION
          SELECT COALESCE(a.roleid, r.oid) AS roleid,
                 a.member AS member,
                 a.admin_option AS admin_option,
                 a.grantor AS grantor
          FROM pg_auth_members a
          FULL OUTER JOIN pg_roles r ON FALSE
          JOIN memberships
            ON (memberships.roleid = a.member)
            OR (memberships.roleid = r.oid OR memberships.member = r.oid)
            OR (memberships.roleid = a.roleid AND COALESCE(memberships.member, 0::oid) <> a.member AND a.member NOT IN(?))
        )
        SELECT DISTINCT ON(ur.rolname, um.rolname)
               ur.rolname AS roleid,
               um.rolname AS member,
               memberships.admin_option,
               ug.rolname AS grantor,
               ur.rolname, ur.rolsuper, ur.rolinherit,
               ur.rolcreaterole, ur.rolcreatedb,
               ur.rolcanlogin, ur.rolconnlimit,
               ur.rolvaliduntil, ur.rolreplication,
               pg_catalog.shobj_description(memberships.roleid, 'pg_authid') as rolcomment
        FROM memberships
        LEFT JOIN pg_roles ur on ur.oid = memberships.roleid
        LEFT JOIN pg_roles um on um.oid = memberships.member
        LEFT JOIN pg_roles ug on ug.oid = memberships.grantor
        ORDER BY 1,2 NULLS LAST;
      SQL
    end

    def replace_bind_variable(value)
      if value.respond_to?(:map)
        if value.respond_to?(:empty?) && value.empty?
          quote(nil)
        else
          value.map { |v| quote(v) }.join(',')
        end
      else
        quote(value)
      end
    end

    def quote_string(s)
      s.gsub(/\\/, '\&\&').gsub(/'/, "''")
    end

    def quote(value)
      "'#{quote_string(value.to_s)}'"
    end

    def replace_bind_variables(statement, values)
      values.each do |value|
        statement.sub!(/\?/) do
          replace_bind_variable(value)
        end
      end
      statement
    end

    def alter_role_function
      <<-SQL
        CREATE OR REPLACE FUNCTION public.alter_role(rolename VARCHAR, sql TEXT)
         RETURNS TEXT
         AS
         $alter_role$
         DECLARE
           r RECORD;
           compensating_sql TEXT := '**!!**ALTER ROLE ';
         BEGIN
           EXECUTE 'SELECT rolsuper, rolinherit,
                           rolcreaterole, rolcreatedb,
                           rolcanlogin, rolconnlimit,
                           rolvaliduntil, rolreplication,
                           pg_catalog.shobj_description(oid, $1) as rolcomment
                    FROM pg_roles
                    WHERE rolname = $2'
           INTO r
           USING 'pg_authid', rolename;
           compensating_sql := compensating_sql || '"' || rolename || '" WITH';
           IF r.rolsuper THEN
             compensating_sql := compensating_sql || ' SUPERUSER';
           ELSE
             compensating_sql := compensating_sql || ' NOSUPERUSER';
           END IF;
           IF r.rolinherit THEN
             compensating_sql := compensating_sql || ' INHERIT';
           ELSE
             compensating_sql := compensating_sql || ' NOINHERIT';
           END IF;
           IF r.rolcreaterole THEN
             compensating_sql := compensating_sql || ' CREATEROLE';
           ELSE
             compensating_sql := compensating_sql || ' NOCREATEROLE';
           END IF;
           IF r.rolcreatedb THEN
             compensating_sql := compensating_sql || ' CREATEDB';
           ELSE
             compensating_sql := compensating_sql || ' NOCREATEDB';
           END IF;
           IF r.rolcanlogin THEN
             compensating_sql := compensating_sql || ' LOGIN';
           ELSE
             compensating_sql := compensating_sql || ' NOLOGIN';
           END IF;
           IF r.rolreplication THEN
             compensating_sql := compensating_sql || ' REPLICATION';
           ELSE
             compensating_sql := compensating_sql || ' NOREPLICATION';
           END IF;
           IF r.rolconnlimit <> -1 THEN
             compensating_sql := compensating_sql || ' CONNECTION LIMIT ' || r.rolconnlimit;
           END IF;
           IF r.rolvaliduntil IS NOT NULL THEN
             compensating_sql := compensating_sql || ' VALID UNTIL ' || r.rolvaliduntil;
           END IF;
           compensating_sql := compensating_sql || ';\n';
           IF r.rolcomment IS NOT NULL THEN
             compensating_sql := compensating_sql || 'COMMENT ON ROLE "' || rolename || '" IS ' || r.rolcomment || ';\n';
           END IF;
           compensating_sql := compensating_sql || '**!!**';
           EXECUTE sql;
           RETURN compensating_sql;
         END;
         $alter_role$
         LANGUAGE PLPGSQL;
      SQL
    end

    def drop_role_alter_function
      <<-SQL
        \n
        DROP FUNCTION public.alter_role(VARCHAR, TEXT);
        \n
      SQL
    end

    def granted_by_function
      <<-SQL
        \n
        CREATE OR REPLACE FUNCTION public.granted_by(rolename VARCHAR, sql TEXT)
        RETURNS BOOLEAN
        AS
        $role_exists$
        DECLARE
        BEGIN
          IF EXISTS (
              SELECT *
              FROM   pg_catalog.pg_roles
              WHERE  rolname = rolename) THEN
            EXECUTE sql;
            RETURN TRUE;
          ELSE
            RAISE NOTICE 'Rolename % does not exist, cannot set granted by', rolename;
            RETURN FALSE;
          END IF;
        END;
        $role_exists$
        LANGUAGE PLPGSQL;
        \n
      SQL
    end

    def drop_granted_by_function
      <<-SQL
        \n
        DROP FUNCTION public.granted_by(VARCHAR, TEXT);
        \n
      SQL
    end

    def create_role_function
      <<-SQL
        \n
        CREATE OR REPLACE FUNCTION public.create_role_if_not_exists(rolename VARCHAR)
        RETURNS TEXT
        AS
        $create_role_if_not_exists$
        DECLARE
        BEGIN
          IF NOT EXISTS (
              SELECT *
              FROM   pg_catalog.pg_roles
              WHERE  rolname = rolename) THEN
            EXECUTE 'CREATE ROLE ' || quote_ident(rolename) || ' ;';
            RETURN '**!!**DROP ROLE ''' || rolename || ''';**!!**';
          ELSE
            RETURN FALSE;
          END IF;
        END;
        $create_role_if_not_exists$
        LANGUAGE PLPGSQL;
        \n
      SQL
    end

    def drop_role_create_function
      <<-SQL
        \n
        DROP FUNCTION public.create_role_if_not_exists(VARCHAR);
        \n
      SQL
    end
  end
end

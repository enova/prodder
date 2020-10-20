ALTER DATABASE prodder__blog_prod SET custom.parameter = 1;
ALTER DATABASE prodder__blog_prod SET search_path TO foo, bar, public;

CREATE TABLE authors (
  author_id serial primary key,
  name text
);

CREATE TABLE posts (
  post_id serial primary key,
  author_id integer,
  body text
);

CREATE TABLE comments (
  comment_id serial primary key,
  post_id integer,
  author_id integer,
  body text
);

INSERT INTO authors (name) VALUES ('Kyle');
INSERT INTO authors (name) VALUES ('Josh');

INSERT INTO posts (author_id, body) VALUES (1, 'Thoughts');
INSERT INTO posts (author_id, body) VALUES (2, 'Other thoughts');

INSERT INTO comments (post_id, author_id, body) VALUES (1, 2, 'I agree');

CREATE FUNCTION test () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
BEGIN
NEW.body='test function trigger collusion';
RETURN NEW;
END;
$$
;

CREATE TRIGGER test_comments BEFORE UPDATE OR INSERT ON comments FOR EACH ROW EXECUTE PROCEDURE test();

CREATE OR REPLACE FUNCTION create_role_if_not_exists(rolename VARCHAR)
RETURNS VOID
AS
$create_role_if_not_exists$
DECLARE
BEGIN
  IF NOT EXISTS (
      SELECT *
      FROM   pg_catalog.pg_roles
      WHERE  rolname = rolename) THEN
    EXECUTE 'CREATE ROLE ' || quote_ident(rolename) || ' ;';
  END IF;
END;
$create_role_if_not_exists$
LANGUAGE PLPGSQL;

SELECT create_role_if_not_exists('_90enva');
SELECT create_role_if_not_exists('_91se');
SELECT create_role_if_not_exists('_91qa');
SELECT create_role_if_not_exists('_91b');
SELECT create_role_if_not_exists('_92se');
SELECT create_role_if_not_exists('_92qa');
SELECT create_role_if_not_exists('_92b');
SELECT create_role_if_not_exists('_93se');
SELECT create_role_if_not_exists('_93qa');
SELECT create_role_if_not_exists('_93b');
SELECT create_role_if_not_exists('_94se');
SELECT create_role_if_not_exists('_94qa');
SELECT create_role_if_not_exists('_94b');
SELECT create_role_if_not_exists('include_this');
SELECT create_role_if_not_exists('exclude_this');
SELECT create_role_if_not_exists('prodder__blog_prod:permissions_test:read_write');
SELECT create_role_if_not_exists('prodder__blog_prod:permissions_test:read_only');
SELECT create_role_if_not_exists('prodder__blog_prod:read_write');
SELECT create_role_if_not_exists('prodder__blog_prod:read_only');

GRANT "_90enva" TO "_91se";
GRANT "_90enva" TO "_91qa";
GRANT "_90enva" TO "_91b";

GRANT "_91se" TO "_92se";
GRANT "_91qa" TO "_92se";
GRANT "_91qa" TO "_92qa";
GRANT "_91b" TO "_92qa";
GRANT "_91qa" TO "_94se";

GRANT "_92se" TO "_93se";
GRANT "_93se" TO "_94se";

GRANT "_92b" TO "_93b";

GRANT "prodder__blog_prod:permissions_test:read_write" TO "_92se";

GRANT "prodder__blog_prod:permissions_test:read_write" TO include_this;
GRANT "prodder__blog_prod:permissions_test:read_only" TO exclude_this;

GRANT "prodder__blog_prod:permissions_test:read_only" TO "prodder__blog_prod:read_only";
GRANT "prodder__blog_prod:permissions_test:read_write" TO "prodder__blog_prod:read_write";
ALTER ROLE "include_this" VALID UNTIL '2222-08-11 00:00:00-05';

GRANT "prodder__blog_prod:read_only" TO prodder;

CREATE SCHEMA permissions_test;
GRANT USAGE ON SCHEMA permissions_test TO include_this;
GRANT USAGE ON SCHEMA permissions_test TO exclude_this;
GRANT USAGE ON SCHEMA permissions_test TO "prodder__blog_prod:permissions_test:read_only";
GRANT USAGE ON SCHEMA permissions_test TO "prodder__blog_prod:permissions_test:read_write";

GRANT SELECT, USAGE, UPDATE ON ALL SEQUENCES IN SCHEMA permissions_test TO include_this;
GRANT SELECT, USAGE, UPDATE ON ALL SEQUENCES IN SCHEMA permissions_test TO exclude_this;
GRANT SELECT, USAGE, UPDATE ON ALL SEQUENCES IN SCHEMA permissions_test TO "prodder__blog_prod:permissions_test:read_only";
GRANT SELECT, USAGE, UPDATE ON ALL SEQUENCES IN SCHEMA permissions_test TO "prodder__blog_prod:permissions_test:read_write";

CREATE TABLE permissions_test.standard_acl (
  standard_acl_id serial primary key,
  value text
);

REVOKE ALL ON permissions_test.standard_acl FROM PUBLIC;
REVOKE ALL ON permissions_test.standard_acl FROM include_this;
REVOKE ALL ON permissions_test.standard_acl FROM exclude_this;
REVOKE ALL ON permissions_test.standard_acl FROM "prodder__blog_prod:permissions_test:read_only";
REVOKE ALL ON permissions_test.standard_acl FROM "prodder__blog_prod:permissions_test:read_write";
GRANT SELECT ON permissions_test.standard_acl TO "prodder__blog_prod:permissions_test:read_only";
GRANT SELECT, INSERT, UPDATE, DELETE ON permissions_test.standard_acl TO "prodder__blog_prod:permissions_test:read_write";

CREATE TABLE permissions_test.column_acl (
  column_acl_id serial primary key,
  non_acl_column integer,
  acl_column integer
);

REVOKE ALL ON permissions_test.column_acl FROM PUBLIC;
REVOKE ALL ON permissions_test.column_acl FROM include_this;
REVOKE ALL ON permissions_test.column_acl FROM exclude_this;
REVOKE ALL ON permissions_test.column_acl FROM "prodder__blog_prod:permissions_test:read_only";
REVOKE ALL ON permissions_test.column_acl FROM "prodder__blog_prod:permissions_test:read_write";
GRANT SELECT (acl_column) ON permissions_test.column_acl TO "prodder__blog_prod:permissions_test:read_only";
GRANT SELECT,INSERT, UPDATE (acl_column) ON permissions_test.column_acl TO "prodder__blog_prod:permissions_test:read_write";

CREATE OR REPLACE FUNCTION permissions_test.does_absolutely_nothing()
RETURNS VOID
AS
$$
BEGIN
  PERFORM 'SELECT 1';
END;
$$
SECURITY DEFINER
LANGUAGE PLPGSQL;

ALTER DEFAULT PRIVILEGES FOR ROLE prodder IN SCHEMA permissions_test GRANT SELECT ON TABLES TO "prodder__blog_prod:permissions_test:read_only";
ALTER DEFAULT PRIVILEGES FOR ROLE prodder IN SCHEMA permissions_test GRANT SELECT, USAGE ON SEQUENCES  TO "prodder__blog_prod:permissions_test:read_only";
ALTER DEFAULT PRIVILEGES FOR ROLE prodder IN SCHEMA permissions_test GRANT SELECT, UPDATE, INSERT, DELETE  ON TABLES TO "prodder__blog_prod:permissions_test:read_write";
ALTER DEFAULT PRIVILEGES FOR ROLE prodder IN SCHEMA permissions_test GRANT SELECT, UPDATE, USAGE ON SEQUENCES TO "prodder__blog_prod:permissions_test:read_write";

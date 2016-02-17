Feature: Configuration lint
  In order to simplify later error handling and hopefully provide
  rapid feedback on configuration issues, the config file is always
  run through a linting process to ensure sanity before any other
  operations are performed.

  See spec/config_spec for a more detailed test of linting. This
  test only ensures that the CLI reports lint failures reasonably.

  Background:
    Given a prodder config in "prodder.yml" with project: store
    And no-op versions of these bins are available on my PATH: pg_dump, git

  Scenario: One of the required project config keys is missing
    But the "store/db/name" key is missing from "prodder.yml"
    When I run `prodder ls -c prodder.yml`
    Then the exit status should be 1
    And the output should contain:
      """
      Missing required configuration key: store/db/name

      Example configuration:
      """
    And the output should contain the example config contents

  Scenario: pg_dump is not available
    Given "pg_dump" is not available on my PATH
    When I run `prodder ls -c prodder.yml`
    Then the exit status should be 1
    And the output should contain:
      """
      `pg_dump` could not be found on your $PATH.

      Current PATH:
      """

  Scenario: git is not available
    Given "git" is not available on my PATH
    When I run `prodder ls -c prodder.yml`
    Then the exit status should be 1
    And the output should contain:
      """
      `git` could not be found on your $PATH.

      Current PATH:
      """

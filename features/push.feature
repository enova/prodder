Feature: prodder push

  Background:
    Given a prodder config in "prodder.yml" with project: blog
    And a "blog" git repository
    And I successfully run `prodder init -c prodder.yml`
    And I successfully run `prodder dump -c prodder.yml`
    And I successfully run `prodder commit -c prodder.yml`

  Scenario: Changes are pushed upstream
    When I successfully run `prodder push -c prodder.yml`
    Then the exit status should be 0
    Then the new commit should be in the remote repository

  Scenario: Push fails due to permissions
    Given the "blog" git repository does not allow pushing to it
    When I run `prodder push -c prodder.yml`
    Then the exit status should be 1
    And the output should contain "remote rejected"

  Scenario: Push fails due to non-fast-forward
    Given a new commit is already in the "blog" git repository
    When I run `prodder push -c prodder.yml`
    Then the exit status should be 1
    And the output should contain "Refusing to push to remote"

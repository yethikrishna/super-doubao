```markdown
# super-doubao Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches you the core development patterns and conventions used in the `super-doubao` Python repository. You'll learn how to structure files, write imports and exports, and follow the project's commit and testing styles. While no specific workflows were detected, this guide provides best practices and commands to streamline your development process.

## Coding Conventions

### File Naming
- Use **snake_case** for all filenames.
  - Example: `data_loader.py`, `user_profile_manager.py`

### Import Style
- Use **relative imports** within the package.
  - Example:
    ```python
    from .utils import calculate_score
    from .models.user import User
    ```

### Export Style
- Use **named exports** (explicitly define what is exported from a module).
  - Example:
    ```python
    __all__ = ['User', 'calculate_score']
    ```

### Commit Messages
- Freeform style, no strict prefixes.
- Average commit message length: ~68 characters.
  - Example:  
    ```
    Fix bug in score calculation for edge cases with empty input
    ```

## Workflows

### Adding a New Module
**Trigger:** When you need to add new functionality.
**Command:** `/add-module`

1. Create a new Python file using snake_case naming.
2. Implement your module logic.
3. Use relative imports to access shared utilities or models.
4. Define `__all__` in your module for named exports.
5. Write corresponding tests in a `*.test.*` file.

### Refactoring Imports
**Trigger:** When reorganizing code or moving modules.
**Command:** `/refactor-imports`

1. Update import statements to use relative paths.
2. Ensure all references within the package use the new import paths.
3. Run tests to verify nothing is broken.

### Writing a Test
**Trigger:** When adding or modifying functionality.
**Command:** `/write-test`

1. Create a test file matching the pattern `*.test.*` (e.g., `user_manager.test.py`).
2. Write test functions for your new or updated code.
3. Use the project's preferred (currently unknown) testing framework.
4. Run all tests to ensure correctness.

## Testing Patterns

- Test files follow the `*.test.*` naming pattern (e.g., `module.test.py`).
- The specific testing framework is not detected; check existing tests for clues.
- Place tests alongside the code or in a dedicated tests directory.
- Example test file:
  ```python
  # user_manager.test.py

  def test_user_creation():
      user = User(name="Alice")
      assert user.name == "Alice"
  ```

## Commands
| Command         | Purpose                                      |
|-----------------|----------------------------------------------|
| /add-module     | Scaffold and add a new module                |
| /refactor-imports | Refactor import statements to be relative   |
| /write-test     | Create a new test file for your code         |
```

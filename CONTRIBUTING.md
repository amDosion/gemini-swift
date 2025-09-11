# Contributing to Gemini Swift

Thank you for your interest in contributing to Gemini Swift! This document provides guidelines and instructions for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before participating.

## Getting Started

### Prerequisites

- Swift 6.1+
- Xcode 14.0+ (optional, for Xcode project)
- Git

### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/gemini-swift.git
   cd gemini-swift
   ```
3. Add the original repository as upstream:
   ```bash
   git remote add upstream https://github.com/huifer/gemini-swift.git
   ```
4. Create a new branch for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

1. **Sync with upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Make your changes**:
   - Follow the coding standards
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**:
   ```bash
   swift build
   swift test
   ```

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Your commit message"
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

## Pull Request Process

1. Ensure your code builds and all tests pass
2. Update documentation if needed
3. Create a pull request with a clear title and description
4. Link any relevant issues
5. Wait for review and address any feedback

### Pull Request Template

```markdown
## Changes
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Description
Describe your changes here.

## Testing
Describe how you tested your changes.

## Checklist
- [ ] Code follows project standards
- [ ] All tests pass
- [ ] Documentation updated
- [ ] No breaking changes (or breaking changes documented)
```

## Coding Standards

### Swift Style Guide

- Use 4 spaces for indentation
- Use `camelCase` for variables and functions
- Use `PascalCase` for types and protocols
- Use `lowerCamelCase` for enum cases
- Prefer `let` over `var`
- Use meaningful names

### Documentation

- Add documentation comments for all public APIs
- Use the following format:
  ```swift
  /// Brief description.
  ///
  /// More detailed description if needed.
  /// - Parameters:
  ///   - parameter1: Description of parameter1
  ///   - parameter2: Description of parameter2
  /// - Returns: Description of return value
  /// - Throws: Description of errors thrown
  ```

### Error Handling

- Use `throw` for errors
- Create custom error types when appropriate
- Handle errors gracefully

### Concurrency

- Use `async/await` for asynchronous operations
- Mark actors and `@MainActor` appropriately
- Avoid data races

## Testing

### Unit Tests

- Write tests for all new functionality
- Use XCTest framework
- Follow the Arrange-Act-Assert pattern
- Mock external dependencies

### Integration Tests

- Use the provided test runner for API integration tests
- Set `GEMINI_API_KEY` environment variable
- Add test resources to appropriate directories

### Test Coverage

- Aim for high test coverage
- Write tests for edge cases
- Include both positive and negative test cases

## Documentation

### Public API Documentation

- Document all public APIs
- Include examples where helpful
- Keep documentation up to date

### README

- Update README for new features
- Include clear examples
- Keep installation instructions current

### CHANGELOG

- Add entries to CHANGELOG.md for significant changes
- Follow semantic versioning
- Include breaking changes in upgrade notes

## Getting Help

- Create an issue for questions or problems
- Join discussions in existing issues and PRs
- Check the documentation first

Thank you for contributing to Gemini Swift!
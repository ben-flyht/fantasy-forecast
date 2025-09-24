# Testing Guide

This Rails application includes both unit tests and system tests (browser-based tests).

## Running Tests

### Unit Tests Only (default)
```bash
bin/rails test
```
This runs all tests except system tests (100 tests).

### System Tests Only
```bash
bin/rails test:system
```
This runs browser-based integration tests (20 tests).

### All Tests (recommended for CI)
```bash
bin/rails test:all
```
This runs both unit tests and system tests (120 total tests).

### Test Database Setup
Before running tests, ensure your test database is set up:
```bash
RAILS_ENV=test bin/rails db:test:prepare
```

## Test Types

### Unit Tests
- **Models**: `test/models/`
- **Controllers**: `test/controllers/`
- **Services**: `test/services/`

### System Tests
- **Browser-based**: `test/system/`
- Uses Selenium with headless Chrome
- Tests full user workflows including authentication

## GitHub Actions
The CI pipeline runs:
```bash
bin/rails db:test:prepare test test:system
```

## Security Testing
Run Brakeman security analysis:
```bash
bundle exec brakeman
```
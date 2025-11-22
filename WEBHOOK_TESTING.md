# Directus Webhook Testing Guide

This guide explains how to test the Directus webhook cache invalidation and warming system in development.

## Overview

Since Directus can't connect directly to your local Rails development environment, we've created simulation tools to test the webhook functionality.

## Testing Methods

### 1. Web Endpoint Simulation

**URL**: `GET /webhooks/directus/simulate`

**Parameters**:
- `collection` (optional): Collection name (default: `articles`)
- `locales` (optional): Comma-separated language codes (default: `en-GB,fr-FR`)

**Examples**:

```bash
# Simulate updating an article with English and French translations
curl "http://localhost:3000/webhooks/directus/simulate?collection=articles&locales=en-GB,fr-FR"

# Simulate with German and Spanish translations
curl "http://localhost:3000/webhooks/directus/simulate?collection=articles&locales=de-DE,es-ES"

# Test with all default parameters
curl "http://localhost:3000/webhooks/directus/simulate"
```

**Response**: JSON with simulation details including:
- Generated webhook payload
- Processing results (cache invalidation, job execution)
- Affected locales detected

### 2. Rake Task Simulation

**Command**: `bundle exec rake webhook:simulate[collection,locales]`

**Examples**:

```bash
# Basic simulation
bundle exec rake webhook:simulate

# Specific collection with locales
bundle exec rake webhook:simulate[articles,en-GB,de-DE]

# Multiple locales
bundle exec rake webhook:simulate[articles,en-GB,fr-FR,es-ES]
```

**Output**: Console output showing the simulation process and results.

### 3. Rails Console Testing

You can also test directly in Rails console:

```ruby
# Build a payload
payload = {
  'event' => 'items.update',
  'collection' => 'articles',
  'key' => SecureRandom.uuid,
  'payload' => {
    'id' => SecureRandom.uuid,
    'translations' => [
      { 'languages_code' => 'en-GB', 'title' => 'Test Article' },
      { 'languages_code' => 'fr-FR', 'title' => 'Article Test' }
    ]
  }
}

# Test the webhook processing
webhooks_controller = WebhooksController.new
result = webhooks_controller.send(:simulate_webhook_processing, payload)
puts result.inspect
```

## What Gets Tested

Each simulation tests the complete webhook flow:

1. **Payload Validation**: Checks if collection is in cached collections list
2. **Locale Extraction**: Extracts affected locales from `payload.translations`
3. **Cache Invalidation**: Calls `DirectusService.invalidate_collection!()`
4. **Job Execution**: Runs `DirectusCollectionWarmerJob.perform_now()` with affected locales
5. **Logging**: All steps are logged for debugging

## Expected Behavior

### Successful Simulation
- Cache is invalidated for the collection
- Warmer job runs and refreshes cache for affected locales only
- JSON response shows `processing_result.cache_invalidated: true` and `job_enqueued: true`

### Unsuccessful Simulation
- Uncached collections are skipped with appropriate message
- Errors in cache invalidation or job execution are logged and reported

## Testing Different Scenarios

### Single Locale Update
```bash
curl "http://localhost:3000/webhooks/directus/simulate?locales=en-GB"
```
Should only warm English content.

### Multi-locale Update
```bash
curl "http://localhost:3000/webhooks/directus/simulate?locales=en-GB,fr-FR,de-DE,es-ES"
```
Should warm all specified locales.

### Uncached Collection
```bash
curl "http://localhost:3000/webhooks/directus/simulate?collection=users"
```
Should be skipped (only `articles` is cached).

### Different Actions
```bash
curl "http://localhost:3000/webhooks/directus/simulate?action=create"
curl "http://localhost:3000/webhooks/directus/simulate?action=delete"
```
All actions should work the same (they all trigger cache invalidation and warming).

## Debugging Tips

1. **Check Logs**: All webhook processing is logged to `log/development.log`
2. **Monitor Cache**: Use Rails console to check cache state:
   ```ruby
   Rails.cache.read('directus:articles:some-key')
   ```
3. **Test Directus Connection**: Ensure your Directus service is working:
   ```ruby
   DirectusService.test_connection
   ```

## Security Note

The simulation endpoint (`/webhooks/directus/simulate`) is only available in development environment and will return 404 in production.

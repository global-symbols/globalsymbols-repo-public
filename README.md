# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

Set development environment variables
```
CONTENTFUL_ACCESS_TOKEN  =
CONTENTFUL_PREVIEW_TOKEN =
CONTENTFUL_SPACE_ID      =
```

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Dependencies
Ensure the following packages are installed on the server.

1. RMagick or MiniMagick library.
   https://github.com/rmagick/rmagick

2. Core web-safe fonts.

   Test BoardBuilder PDF output with a variety of fonts first - this may not be required!

   Debian/Ubuntu: `sudo apt-get install msttcorefonts`

   Redhat: See http://mscorefonts2.sourceforge.net/

3. ImageMagick with RSVG delegate

   ImageMagick contains a bug that causes an infinite loop when converting SVGs to PNG.
   https://github.com/ImageMagick/ImageMagick6/issues/96

   This is fixed in ImageMagick >= 6.9.11-29 and >= 7.0.10-29

## CORS
Ensure the webserver adds CORS headers to requests to the public directory. These requests do not touch Rails, so must be handled in the webserver.


## Testing Notes
### Adding a new stubbed HTTP response
Record the HTTP response using curl:  
`curl -is http://api.conceptnet.io/c/en/success > spec/fixtures/conceptnet.success.txt`

## Deployment
### Set up Logrotate
Ensure production logs are rotated, to prevent the server disk from being filled.
See https://gorails.com/guides/rotating-rails-production-logs-with-logrotate

## Scheduled Jobs
Set in schedule.rb.

The whenever gem is supposed to configure crontab automatically with `bundle exec whenever --user deploy --update-crontab`.

However, RHEL won't allow the Rails application user (`deploy`) to run crontab. To work around this:
1. `sudo su - deploy`.
2. `bundle exec whenever` and copy the output crontab config.
3. Switch to the `sudo` account.
4. `crontab -u deploy -e`.
5. Paste in copied crontab config output from step 2.


## Fonts
This repo includes some TTF fonts that are used by the PrawnPDF engine in Board Builder. For the Noto family, TTF files on Google Fonts are usually smaller than the ones on the Noto website itself.

## Handling RTL i18n
Sometimes, string interpolations will have their % signs changed, e.g. from `%{var}` to `{var}٪`.
* If the interpolation is inside a string (i.e. the % is not at the end), just replace `٪` with `%`.
* If the interpolation is on the end of the string (e.g. `[arabic] {var}٪`)
   1. Place caret between `}` and `٪`.
   2. Add `%`, press right arrow and use backspace to delete `٪`.
   3. Press right arrow again so caret changes from LTR to RTL mode (the flag on top should point right).
   4. Press shift and click at "start" of string, press `'` to wrap string in single quotes.
   5. `[arabic] {var}٪` should now read `'[arabic] {var}%'`, and the site should not complain about YML problems.

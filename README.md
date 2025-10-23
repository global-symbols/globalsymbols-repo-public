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

# Install
Most installation hints are for Kubuntu 23, some from my previous (failed) attempt to install everything on Windows 10.

* [install Ruby on Rails](https://guides.rubyonrails.org/v5.1/getting_started.html), ruby version `2.5.1`, rails version `6.1.3.2`
  * if there are problems installing rails (e.g. `(Gem::FilePermissionError)`) or you want to use different versions of rails, you can also try to use rails with a version manager like `asdf`, see tutorial: https://gorails.com/setup/ubuntu/23.10
  * install asdf, see https://asdf-vm.com/guide/getting-started.html
     * `git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0`
     * `echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc`
     * `echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc`
     * `source ~/.bashrc`
  * install ruby with asdf:
     * `asdf add ruby`
     * `asdf install ruby 3.0.4`
     * `asdf global ruby 3.0.4`
     * `gem update --system`
* be happy if `ruby -v` is working!
* install MySQL
  * on Linux run `sudo apt install mysql-server mysql-client libmysqlclient-dev`
  * on Windows install [MySQLConnector/C++ 8.3.0](https://dev.mysql.com/downloads/connector/cpp/) and run `gem install mysql2 --platform=ruby -- --with-mysql-lib="C:\MySQL\MySQL Connector C++ 8.3\lib64"`, see [issue on GitHub](https://github.com/brianmario/mysql2/issues/1210#issuecomment-2047407392).
  * run `sudo mysql` and do `CREATE USER 'gs-repo-dev' IDENTIFIED BY 'gs-repo-dev';` and `grant all privileges on gsrepodev.* TO 'gs-repo-dev';` in order to create a database user for dev (see `config/database.yml` for used database users). Do the same with `gs-repo-test` and database `gsrepotest`.
* install NodeJS `sudo apt-get install nodejs`
* clone this repository `git clone https://github.com/global-symbols/globalsymbols-repo.git`
* go to the cloned folder `cd globalsymbols-repo`
* run `bundle install` to install dependencies. If command `bundle` is not existing make sure Ruby on Rails is properly installed.
  * if some dependencies fail to install, like `Installing nokogiri 1.11.7 with native extensions` hangs, try to delete `Gemfile.lock` and try again.
  * on errors like `Errno::EACCES: Permission denied` try to run with `sudo` or in an admin shell on Windows
* run `rails db:migrate:reset` in order to set up databases
* run `rails db:seed` in order to seed database content
* be very happy if `rails server` works and navigating to `http://localhost:3000/` shows something!

## Test accounts
While installing test accounts are automatically generated, which can be used to log in:
* normal users: `user1@test.com`, `password`, more with other numbers
* admin users: `admin1@test.com`, `password`, more with other numbers

## Use media upload locally
In production AWS is used for storing uploaded media (user symbols or images). For development you can use file storage.
See e.g. [media_uploader.rb](https://github.com/global-symbols/globalsymbols-repo/blob/master/app/uploaders/boardbuilder/media_uploader.rb#L11) and use `storage :file` there.

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

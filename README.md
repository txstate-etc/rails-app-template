# Rails App Template

This script creates a Rails application that already includes all of the stuff we
commonly use:

* CAS authentication
* Capistrano deployment
* DelayedJob for background tasks
* Whenever for cron jobs
* ExceptionNotification for exception notifications.
* And much, much more!

## How to use it

1. Clone this repo.
2. Make sure you have recent versions of rvm and ruby installed.
3. Make sure you have mysql installed and running. Root user with no password is assumed, so don't run this in a production environment.
4. Run `./rails-new.sh <app-name>`
5. Profit!

The script will abort if the app directory or database already exists, so it should be safe to run, but I make no guarantees that it won't destroy the known universe.

## User Model

The template creates a User model that is used for CAS authentication. The first time the script is run,
you will be prompted to enter your name and NetID, which will be used to seed the database. You can enter as many users as you want. The seed file is stored in `files/db/seeds.rb` and will be reused on subsequent runs of the script. Feel free to modify the seeds file as you see fit.

#!/bin/bash
#
# Create Rails app with template file and rvm gemset. 
# App will be created in subdir of current directory using the provided name.
# 
# Usage: ./rails-new.sh <appname> [other `rails new` options]

source "$HOME/.rvm/scripts/rvm"

srcdir="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
tmpl="$srcdir/rails-app-template.rb"

#FIXME: install latest ruby?
rbver="$(ruby -e 'print RUBY_VERSION')"

appname="$1"
shift

# FIXME: add --force option to delete existing app/db
# rm -rf $appname
# mysql -u root -e "drop database ${appname}_development;drop database ${appname}_test;"

if mysql -u root "${appname}_development" >/dev/null 2>&1 </dev/null; then
  echo "${appname}_development database already exists. aborting"
  exit 1
fi

if [ -d "$appname" ]; then
  echo "$appname path already exists. aborting"
  exit 1
fi

mkdir $appname
echo "$appname" > $appname/.ruby-gemset
cd $appname
rvm --create use "ruby-$rbver"@"$appname"

gem which rails &> /dev/null || gem install rails

rails new . $@ -m "$tmpl" --skip-turbolinks --skip-bundle --database=mysql

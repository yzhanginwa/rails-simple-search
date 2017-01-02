#!/bin/sh

if [ ! -d build ]; then
  echo "Please run the build.sh in the top directory of the project"
  exit
fi

gem uninstall rails-simple-search
gem build rails-simple-search.gemspec 
rm build/*.gem
mv rails-simple-search-*.gem build/
gem install build/rails-simple-search-*.gem

##############################################################
# after the new gem is ready, do the following to publish it #
#                                                            #
# gem push rails-simple-search-x.x.x.gem                     #
#                                                            #
##############################################################

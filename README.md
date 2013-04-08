# flog

[home](http://ruby.sadi.st/) | [repo](https://github.com/seattlerb/flog) | [rdoc](http://seattlerb.rubyforge.org/flog)

## DESCRIPTION:

Flog reports the most tortured code in an easy to read pain
report. The higher the score, the more pain the code is in.

## FEATURES/PROBLEMS:

* Easy to read reporting of complexity/pain.

## SYNOPSIS:

* Command line

~~~
% ./bin/flog -g lib
Total Flog = 1097.2 (17.4 flog / method)

   323.8: Flog total
    85.3: Flog#output_details
    61.9: Flog#process_iter
    53.7: Flog#parse_options
...
~~~

* Ruby code

~~~ruby
scanner = Flog.new
scanner.flog 'path_to_your_ruby_file_or_folder'
scanner.calculate

scanner.scores
# {"User" => 19.624353739718167}

scanner.methods
# { "User" => [
#   ["User#encrypt_password", 10.989540481749003], 
#   ["User#remember_me", 8.634813257969164]
# ]}
~~~

## REQUIREMENTS:

* ruby2ruby (only for -v)
* ruby_parser

## INSTALL:

* sudo gem install flog

## LICENSE:

(The MIT License)

Copyright (c) Ryan Davis, seattle.rb

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

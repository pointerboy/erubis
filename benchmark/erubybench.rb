##
## $Rev$
## $Release$
## $Copyright$
##

require 'eruby'
require 'erb'
require 'erubis'
require 'erubis/engine/enhanced'
require 'erubis/engine/optimized'


## default values
filename = 'erubybench.rhtml'
datafile = 'erubybench.yaml'
n = 1000


## usage
def usage(n, filename, datafile)
  s =  "Usage: ruby #{$0} [-h] [-n N] [-f file] [-d file] [testname ...]\n"
  s << "  -h      :  help\n"
  s << "  -n N    :  number of times to loop (default #{n})\n"
  s << "  -f file :  eruby filename (default '#{filename}')\n"
  s << "  -d file :  data filename (default '#{datafile}')\n"
  return s
end


## parse command-line options
flag_help = false
flag_all = false
targets = nil
compiler_name = 'ErubisOptimized'
while !ARGV.empty? && ARGV[0][0] == ?-
  opt = ARGV.shift
  case opt
  when '-n'  ;  n = ARGV.shift.to_i
  when '-f'  ;  filename = ARGV.shift
  when '-d'  ;  datafile = ARGV.shift
  when '-h', '--help'  ;  flag_help = true
  when '-A'  ;  test_all = true
  when '-C'  ;  compiler_name = ARGV.shift
  else       ;  raise "#{opt}: invalid option."
  end
end
puts "** n=#{n.inspect}, filename=#{filename.inspect}, datafile=#{datafile.inspect}"


## help
if flag_help
  puts usage(n, filename, datafile)
  exit()
end


## load data file
require 'yaml'
ydoc = YAML.load_file(datafile)
data = []
ydoc['data'].each do |hash|
  data << hash.inject({}) { |h, t| h[t[0].intern] = t[1]; h }
  #h = {}; hash.each { |k, v| h[k.intern] = v } ; data << h
end
data = data.sort_by { |h| h[:code] }
#require 'pp'; pp data


## open /dev/null
$devnull = File.open("/dev/null", 'w')


## define ErubisEruby2 class
module Erubis
  class Eruby2 < Eruby
    def finalize_src(src)
      #src << "\nprint _out.join; nil\n"
      src << "\n_out.join; ''\n"
    end
  end
end


## test definitions
testdefs_str = <<END
- name:   ERuby
  class:  ERuby
  code: |
    ERuby.import(filename)
  compile: |
    ERuby::Compiler.new.compile_string(str)
  return: null

- name:   ERB
  class:  ERB
  code: |
    print ERB.new(File.read(filename)).result(binding())
#    eruby = ERB.new(File.read(filename))
#    print eruby.result(binding())
  compile: |
    ERB.new(str).src
  return: str

- name:   ErubisEruby
  class:  Erubis::Eruby
  code: |
    print Erubis::Eruby.new(File.read(filename)).result(binding())
#    eruby = Erubis::Eruby.new(File.read(filename))
#    print eruby.result(binding())
  compile: |
    Erubis::Eruby.new(str).src
  return: str

- name:   ErubisEruby2
  desc:   print _out    #, no binding()
  class:  Erubis::Eruby2
  code: |
    #Erubis::Eruby2.new(File.read(filename)).result()
    Erubis::Eruby2.new(File.read(filename)).result(binding())
  compile: |
    Erubis::Eruby2.new(str).src
  return: null
  skip:   yes

- name:   ErubisOptimized
  class:  Erubis::OptimizedEruby
  code: |
    print Erubis::OptimizedEruby.new(File.read(filename)).result(binding())
  compile: |
    Erubis::OptimizedEruby.new(str).src
  return: str
  skip:   yes

#- name:   ErubisArrayBuffer
#  class:  Erubis::ArrayBufferEruby
#  code: |
#    Erubis::ArrayBufferEruby.new(File.read(filename)).result(binding())
#  compile: |
#    Erubis::ArrayBufferEruby.new(str).src
#  return: str
#  skip:   no

- name:   ErubisStringBuffer
  class:  Erubis::StringBufferEruby
  code: |
    Erubis::StringBufferEruby.new(File.read(filename)).result(binding())
  compile: |
    Erubis::StringBufferEruby.new(str).src
  return: str
  skip:   no

- name:   ErubisSimplified
  class:  Erubis::SimplifiedEruby
  code: |
    Erubis::SimplifiedEruby.new(File.read(filename)).result(binding())
  compile: |
    Erubis::SimplifiedEruby.new(str).src
  return: str
  skip:   no

- name:   ErubisStdout
  class:  Erubis::StdoutEruby
  code: |
    Erubis::StdoutEruby.new(File.read(filename)).result(binding())
  compile: |
    Erubis::StdoutEruby.new(str).src
  return: null
  skip:   no

- name:   ErubisStdoutSimplified
  class:  Erubis::StdoutSimplifiedEruby
  code: |
    Erubis::StdoutSimplifiedEruby.new(File.read(filename)).result(binding())
  compile: |
    Erubis::StdoutSimplifiedEruby.new(str).src
  return: str
  skip:   no

#- name:    load
#  class:   load
#  code: |
#    load($load_filename)
#  compile: null
#  return: null
#  skip:    yes

END
testdefs = YAML.load(testdefs_str)


### create file for load
#if testdefs.find { |h| h['name'] == 'load' }
#  $load_filename = filename + ".tmp"   # for load
#  $data = data
#  str = File.read(filename)
#  str.gsub!(/\bdata\b/, '$data')
#  hash = testdefs.find { |h| h['name'] == compiler_name }
#  code = eval hash['compile']
#  code.sub!(/_out\s*\z/, 'print \&')
#  File.open($load_filename, 'w') { |f| f.write(code) }
#  at_exit do
#    File.unlink $load_filename if test(?f, $load_filename)
#  end
#end


## select test target
if test_all
  #testdefs.each { |h| h['skip'] = false }
elsif !ARGV.empty?
  #testdefs.each { |h| h['skip'] = ARGV.include?(h['name']) }
  testdefs.delete_if { |h| !ARGV.include?(h['name']) }
else
  testdefs.delete_if { |h| h['skip'] }
end
#require 'pp'
#pp testdefs


## define test functions for each classes
testdefs.each do |h|
  s = ''
  s << "def test_#{h['name']}(filename, data)\n"
  s << "  $stdout = $devnull\n"
  n.times do
    s << '  ' << h['code']  #<< "\n"
  end
  s << "  $stdout = STDOUT\n"
  s << "end\n"
  #puts s
  eval s
end


## define view functions for each classes
str = File.read(filename)
testdefs.each do |h|
  next unless h['compile']
  code = eval h['compile']
  s = <<-END
    def view_#{h['name']}(data)
      #{code}
    end
  END
  #puts s
  eval s
end


## define tests for view functions
testdefs.each do |h|
  pr = h['return'] ? 'print ' : ''
  s = ''
  s << "def test_view_#{h['name']}(data)\n"
  s << "  $stdout = $devnull\n"
  n.times do
    s << "  #{pr}view_#{h['name']}(data)\n"
  end
  s << "  $stdout = STDOUT\n"
  s << "end\n"
  #puts s
  eval s
end


## define tests for read-and-eval
str = File.read(filename)
testdefs.each do |h|
  next unless h['compile']
  # create file to read
  code = eval h['compile']
  fname = "#{filename}.#{h['name']}"
  File.open(fname, 'w') { |f| f.write(code) }
  #at_exit do File.unlink fname if test(?f, fname) end
  # define function
  pr = h['return'] ? 'print ' : ''
  s = ''
  s << "def test_eval_#{h['name']}(filename, data)\n"
  s << "  $stdout = $devnull\n"
  n.times do
    s << "  #{pr}eval(File.read(\"\#{filename}.#{h['name']}\"))\n"
  end
  s << "  $stdout = STDOUT\n"
  s << "end\n"
  #puts s
  eval s
end


## rehearsal
$stdout = $devnull
testdefs.each do |h|
  ## execute test code
  eval h['code']
  ## execute view function
  next unless h['compile']
  v = __send__("view_#{h['name']}", data)
  print v if h['return']
  ## execute read-and-eval action
  v = eval(File.read("#{filename}.#{h['name']}"))
  print v if h['return']
end
$stdout = STDOUT


## do benchmark
require 'benchmark'
begin
  Benchmark.bmbm(25) do |job|
    ## basic test
    testdefs.each do |h|
      title = h['class']
      func = 'test_' + h['name']
      GC.start
      job.report(title) do
        __send__(func, filename, data)
      end
    end

    ## read-and-eval function
    testdefs.each do |h|
      next unless h['compile']
      title = 'eval_' + h['name']
      func = 'test_eval_' + h['name']
      GC.start
      job.report(title) do
        __send__(func, filename, data)
      end
    end

    ## view-function test
    testdefs.each do |h|
      next unless h['compile']
      title = 'func_' + h['name']
      func = 'test_view_' + h['name']
      GC.start
      job.report(title) do
        __send__(func, data)
      end
    end

  end
ensure
  $devnull.close()
end
